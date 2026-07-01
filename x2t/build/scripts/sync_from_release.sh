#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/sync_from_release.sh [--dry-run] <release_dir>

Synchronise le bundle x2t depuis une release officielle ONLYOFFICE.
Peuple x2t/bin/ (binaire + frameworks) et x2t/sdkjs/ (JS minimal pour la conversion).

release_dir: dossier Resources de la release (ex: /Applications/OnlyOffice.app/Contents/Resources)
             Doit contenir converter/ et editors/.

--dry-run: affiche ce qui serait fait sans ecrire.
EOF
}

dry_run=0
release_dir=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$release_dir" ]] || { echo "Un seul dossier release accepte." >&2; usage >&2; exit 1; }
      release_dir="$1"
      ;;
  esac
  shift
done

[[ -n "$release_dir" ]] || { echo "Argument manquant: release_dir" >&2; usage >&2; exit 1; }
[[ -d "$release_dir" ]] || { echo "Dossier introuvable: $release_dir" >&2; exit 1; }

# Localiser converter/ et editors/
if [[ -f "$release_dir/converter/x2t" ]]; then
  converter_dir="$release_dir/converter"
  editors_dir="$release_dir/editors"
elif [[ -f "$release_dir/x2t" ]]; then
  converter_dir="$release_dir"
  editors_dir="$release_dir/../editors"
else
  echo "Binaire x2t introuvable dans $release_dir" >&2; exit 1
fi

editors_dir=$(cd -- "$editors_dir" 2>/dev/null && pwd || echo "")
[[ -n "$editors_dir" && -d "$editors_dir" ]] || { echo "Dossier editors/ introuvable." >&2; exit 1; }

sdkjs_src="$editors_dir/sdkjs"
vendor_src="$editors_dir/web-apps/vendor"

[[ -d "$sdkjs_src" ]]  || { echo "editors/sdkjs introuvable: $sdkjs_src" >&2; exit 1; }
[[ -d "$vendor_src" ]] || { echo "editors/web-apps/vendor introuvable: $vendor_src" >&2; exit 1; }

bin_dest="$bundle_root/bin"
sdkjs_dest="$bundle_root/sdkjs"

echo "Release converter : $converter_dir"
echo "Release editors   : $editors_dir"
echo "Destination bin   : $bin_dest"
echo "Destination sdkjs : $sdkjs_dest"

# Fichiers JS necessaires pour la conversion (sdk-all-min.js + sdk-all.js obligatoires ensemble)
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
  "pdf/src/engine/drawingfile_native.js"
  "pdf/src/engine/cmap.bin"
)

missing=()
for f in "${sdkjs_files[@]}"; do [[ -f "$sdkjs_src/$f" ]] || missing+=("$f"); done
[[ -f "$vendor_src/xregexp/xregexp-all-min.js" ]] || missing+=("web-apps/vendor/xregexp/xregexp-all-min.js")

(( ${#missing[@]} == 0 )) || {
  echo "Fichiers manquants dans la release:" >&2
  for f in "${missing[@]}"; do echo "  $f" >&2; done
  exit 1
}

if (( dry_run )); then
  echo ""
  echo "[dry-run] --- bin/ ---"
  echo "[dry-run] copier x2t"
  for fw in "$converter_dir"/*.framework; do [[ -d "$fw" ]] && echo "[dry-run] copier ${fw:t}"; done
  echo "[dry-run] ecrire DoctRenderer.config"
  echo ""
  echo "[dry-run] --- sdkjs/ ---"
  for f in "${sdkjs_files[@]}"; do echo "[dry-run] copier $f"; done
  echo "[dry-run] copier vendor/xregexp/xregexp-all-min.js"
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
<file>../sdkjs/common/Native/native.js</file>
<file>../sdkjs/common/Native/jquery_native.js</file>
<allfonts>../sdkjs/common/AllFonts.js</allfonts>
<file>../sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>../sdkjs</sdkjs>
<dictionaries>../dictionaries</dictionaries>
</Settings>
CONF

rm -rf "$bin_dest"
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

# Preserve AllFonts.js si deja present
if [[ -f "$sdkjs_dest/common/AllFonts.js" ]]; then
  mkdir -p "$stage_sdkjs/common"
  cp "$sdkjs_dest/common/AllFonts.js" "$stage_sdkjs/common/AllFonts.js"
fi

rm -rf "$sdkjs_dest"
mv "$stage_sdkjs" "$sdkjs_dest"
trap - EXIT

echo ""
echo "bin/    : $(du -sh "$bin_dest" | cut -f1)"
echo "sdkjs/  : $(du -sh "$sdkjs_dest" | cut -f1)"
echo ""
echo "Prochaine etape — copier AllFonts.js si pas encore fait:"
echo "  cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js"
