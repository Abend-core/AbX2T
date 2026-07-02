#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copies unmodified binaries/JS from an official ONLYOFFICE release (Copyright (C)
# Ascensio System SIA, AGPLv3) into this bundle. See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/sync_from_release.sh [--dry-run] <release_dir>

Synchronizes the x2t bundle from an official ONLYOFFICE release.
Populates x2t/bin/ (binary + frameworks) and x2t/sdkjs/ (minimal JS needed for conversion).

release_dir: the release's Resources directory (e.g. /Applications/OnlyOffice.app/Contents/Resources)
             Must contain converter/ and editors/.

--dry-run: shows what would be done without writing anything.
EOF
}

dry_run=0
release_dir=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$release_dir" ]] || { echo "Only one release directory accepted." >&2; usage >&2; exit 1; }
      release_dir="$1"
      ;;
  esac
  shift
done

[[ -n "$release_dir" ]] || { echo "Missing argument: release_dir" >&2; usage >&2; exit 1; }
[[ -d "$release_dir" ]] || { echo "Directory not found: $release_dir" >&2; exit 1; }

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

bin_dest="$bundle_root/bin/macos-arm64"
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

if (( dry_run )); then
  echo ""
  echo "[dry-run] --- bin/macos-arm64/ ---"
  echo "[dry-run] copy x2t"
  for fw in "$converter_dir"/*.framework; do [[ -d "$fw" ]] && echo "[dry-run] copy ${fw:t}"; done
  echo "[dry-run] write DoctRenderer.config"
  echo ""
  echo "[dry-run] --- sdkjs/ ---"
  for f in "${sdkjs_files[@]}"; do echo "[dry-run] copy $f"; done
  echo "[dry-run] copy vendor/xregexp/xregexp-all-min.js"
  exit 0
fi

# --- Sync bin/ ---
stage_bin=$(/usr/bin/mktemp -d "$bundle_root/.sync_bin.XXXXXX")
trap "rm -rf '$stage_bin'" EXIT

cp "$converter_dir/x2t" "$stage_bin/"
chmod +x "$stage_bin/x2t"

for fw in "$converter_dir"/*.framework; do
  [[ -d "$fw" ]] && cp -R "$fw" "$stage_bin/"
done

cat > "$stage_bin/DoctRenderer.config" <<'CONF'
<Settings>
<file>../../sdkjs/common/Native/native.js</file>
<file>../../sdkjs/common/Native/jquery_native.js</file>
<allfonts>../../sdkjs/common/AllFonts.js</allfonts>
<file>../../sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>../../sdkjs</sdkjs>
</Settings>
CONF

# bin_dest is our own os-arch subfolder (bin/macos-arm64/, mirroring bin/windows-x86_64/) --
# safe to wipe wholesale, sibling platform folders under bin/ are untouched.
rm -rf "$bin_dest"
mkdir -p "${bin_dest:h}"
mv "$stage_bin" "$bin_dest"
trap - EXIT

# --- Sync sdkjs/ ---
stage_sdkjs=$(/usr/bin/mktemp -d "$bundle_root/.sync_sdkjs.XXXXXX")
trap "rm -rf '$stage_sdkjs'" EXIT

for f in "${sdkjs_files[@]}"; do
  target="$stage_sdkjs/$f"
  mkdir -p "${target:h}"
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
trap - EXIT

echo ""
echo "bin/macos-arm64/ : $(du -sh "$bin_dest" | cut -f1)"
echo "sdkjs/           : $(du -sh "$sdkjs_dest" | cut -f1)"
echo ""
echo "Next step -- copy AllFonts.js if not already done:"
echo "  cp allfontsgen/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js"
