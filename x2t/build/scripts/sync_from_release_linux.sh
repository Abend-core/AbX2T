#!/usr/bin/env bash
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copies unmodified binaries/JS from an official ONLYOFFICE release (Copyright (C)
# Ascensio System SIA, AGPLv3) into this bundle. See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

bundle_root=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

usage() {
  cat <<'EOF'
Usage: bash x2t/build/scripts/sync_from_release_linux.sh [--dry-run] <release>

Synchronizes the x2t bundle from an official ONLYOFFICE Desktop Editors Linux release.
Populates x2t/bin/linux-x86_64/ (x2t + .so libraries + ICU data) and x2t/sdkjs/
(minimal JS needed for conversion).

release: either the official .deb package
           (e.g. onlyoffice-desktopeditors_9.4.0_amd64.deb, from
            https://download.onlyoffice.com/repo/debian/pool/main/o/onlyoffice-desktopeditors/)
         or an installed/extracted directory containing converter/ and editors/
           (e.g. /opt/onlyoffice/desktopeditors)

--dry-run: shows what would be done without writing anything.
EOF
}

dry_run=0
release=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$release" ]] || { echo "Only one release accepted." >&2; usage >&2; exit 1; }
      release="$1"
      ;;
  esac
  shift
done

[[ -n "$release" ]] || { echo "Missing argument: release" >&2; usage >&2; exit 1; }
[[ -e "$release" ]] || { echo "Not found: $release" >&2; exit 1; }

cleanup_dirs=()
cleanup() { for d in "${cleanup_dirs[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# If given the .deb, extract it to a temp dir first.
release_dir="$release"
if [[ -f "$release" ]]; then
  command -v dpkg-deb >/dev/null || { echo "dpkg-deb required to extract a .deb" >&2; exit 1; }
  deb_stage=$(mktemp -d)
  cleanup_dirs+=("$deb_stage")
  echo "Extracting $release..."
  dpkg-deb -x "$release" "$deb_stage"
  release_dir="$deb_stage/opt/onlyoffice/desktopeditors"
  [[ -d "$release_dir" ]] || { echo "opt/onlyoffice/desktopeditors not found in the .deb" >&2; exit 1; }
fi

# Locate converter/ and editors/
if [[ -f "$release_dir/converter/x2t" ]]; then
  converter_dir="$release_dir/converter"
  editors_dir="$release_dir/editors"
elif [[ -f "$release_dir/x2t" ]]; then
  converter_dir="$release_dir"
  editors_dir="$release_dir/../editors"
else
  echo "x2t binary not found in $release_dir" >&2; exit 1
fi

editors_dir=$(cd -- "$editors_dir" 2>/dev/null && pwd || echo "")
[[ -n "$editors_dir" && -d "$editors_dir" ]] || { echo "editors/ directory not found." >&2; exit 1; }

sdkjs_src="$editors_dir/sdkjs"
vendor_src="$editors_dir/web-apps/vendor"

[[ -d "$sdkjs_src" ]]  || { echo "editors/sdkjs not found: $sdkjs_src" >&2; exit 1; }
[[ -d "$vendor_src" ]] || { echo "editors/web-apps/vendor not found: $vendor_src" >&2; exit 1; }

bin_dest="$bundle_root/bin/linux-x86_64"
sdkjs_dest="$bundle_root/sdkjs"

echo "Release converter : $converter_dir"
echo "Release editors   : $editors_dir"
echo "Destination bin   : $bin_dest"
echo "Destination sdkjs : $sdkjs_dest"

# JS files needed for conversion (sdk-all-min.js + sdk-all.js required together)
sdkjs_files=(
  "common/Native/native.js"
  "common/Native/jquery_native.js"
  "common/libfont/engine/fonts_native.js"
  "word/sdk-all-min.js"
  "word/sdk-all.js"
  "slide/sdk-all-min.js"
  "slide/sdk-all.js"
  "cell/sdk-all-min.js"
  "cell/sdk-all.js"
  "visio/sdk-all-min.js"
  "visio/sdk-all.js"
  "pdf/src/engine/drawingfile_native.js"
  "pdf/src/engine/cmap.bin"
)

missing=()
for f in "${sdkjs_files[@]}"; do [[ -f "$sdkjs_src/$f" ]] || missing+=("$f"); done
[[ -f "$vendor_src/xregexp/xregexp-all-min.js" ]] || missing+=("web-apps/vendor/xregexp/xregexp-all-min.js")

(( ${#missing[@]} == 0 )) || {
  echo "Missing files in the release:" >&2
  for f in "${missing[@]}"; do echo "  $f" >&2; done
  exit 1
}

# Binary payload: x2t + every .so it dlopens/links (all resolved via RPATH $ORIGIN)
# + ICU data blobs (icudtl*.dat, loaded at runtime by libdoctrenderer.so's embedded V8).
bin_files=("x2t")
while IFS= read -r so; do
  bin_files+=("$(basename "$so")")
done < <(find "$converter_dir" -maxdepth 1 -name "*.so*" | sort)
for dat in icudtl.dat icudtl_extra.dat; do
  [[ -f "$converter_dir/$dat" ]] && bin_files+=("$dat")
done

if (( dry_run )); then
  echo ""
  echo "[dry-run] --- bin/linux-x86_64/ ---"
  for f in "${bin_files[@]}"; do echo "[dry-run] copy $f"; done
  echo "[dry-run] write DoctRenderer.config"
  echo ""
  echo "[dry-run] --- sdkjs/ ---"
  for f in "${sdkjs_files[@]}"; do echo "[dry-run] copy $f"; done
  echo "[dry-run] copy vendor/xregexp/xregexp-all-min.js"
  exit 0
fi

# --- Sync bin/ ---
stage_bin=$(mktemp -d "$bundle_root/.sync_bin.XXXXXX")
cleanup_dirs+=("$stage_bin")

for f in "${bin_files[@]}"; do
  cp "$converter_dir/$f" "$stage_bin/"
done
chmod +x "$stage_bin/x2t"

cat > "$stage_bin/DoctRenderer.config" <<'CONF'
<Settings>
<file>../../sdkjs/common/Native/native.js</file>
<file>../../sdkjs/common/Native/jquery_native.js</file>
<allfonts>../../sdkjs/common/AllFonts.js</allfonts>
<file>../../sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>../../sdkjs</sdkjs>
</Settings>
CONF

# bin_dest is our own os-arch subfolder (bin/linux-x86_64/, mirroring bin/windows-x86_64/) --
# safe to wipe wholesale, sibling platform folders under bin/ are untouched.
rm -rf "$bin_dest"
mkdir -p "$(dirname "$bin_dest")"
mv "$stage_bin" "$bin_dest"

# --- Sync sdkjs/ ---
stage_sdkjs=$(mktemp -d "$bundle_root/.sync_sdkjs.XXXXXX")
cleanup_dirs+=("$stage_sdkjs")

for f in "${sdkjs_files[@]}"; do
  target="$stage_sdkjs/$f"
  mkdir -p "$(dirname "$target")"
  cp "$sdkjs_src/$f" "$target"
done

mkdir -p "$stage_sdkjs/vendor/xregexp"
cp "$vendor_src/xregexp/xregexp-all-min.js" "$stage_sdkjs/vendor/xregexp/"

# Preserve AllFonts.js if already present (generated locally by allfontsgen, not part of the release)
if [[ -f "$sdkjs_dest/common/AllFonts.js" ]]; then
  mkdir -p "$stage_sdkjs/common"
  cp "$sdkjs_dest/common/AllFonts.js" "$stage_sdkjs/common/AllFonts.js"
fi

rm -rf "$sdkjs_dest"
mv "$stage_sdkjs" "$sdkjs_dest"

echo ""
echo "bin/linux-x86_64/ : $(du -sh "$bin_dest" | cut -f1)"
echo "sdkjs/            : $(du -sh "$sdkjs_dest" | cut -f1)"
echo ""
echo "Next step -- copy AllFonts.js if not already done:"
echo "  cp allfontsgen/output/linux-x86_64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js"
