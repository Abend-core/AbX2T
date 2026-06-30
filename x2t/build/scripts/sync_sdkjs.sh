#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)
dest="$bundle_root/sdkjs"

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/sync_sdkjs.sh [--dry-run] [source]

Copie le sous-ensemble runtime de sdkjs dans x2t/sdkjs/.
Exclut les fichiers navigateur (drawingfile_ie.js, drawingfile.wasm, viewer.js)
et les outils de build (build/, tools/, Makefile, scripts Python).

- source: dossier sdkjs a utiliser.
  Par defaut: sdkjs-master/ puis sdkjs/ a la racine du workspace.
- --dry-run: affiche ce qui serait fait sans ecrire.
EOF
}

dry_run=0
source=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$source" ]] || { echo "Un seul dossier source accepte." >&2; usage >&2; exit 1; }
      source="$1"
      ;;
  esac
  shift
done

if [[ -z "$source" ]]; then
  for candidate in "$workspace_root/sdkjs-master" "$workspace_root/sdkjs"; do
    [[ -d "$candidate" ]] && { source="$candidate"; break; }
  done
fi

[[ -n "$source" && -d "$source" ]] || {
  echo "Dossier sdkjs introuvable. Deposer sdkjs-master/ a la racine du workspace." >&2; exit 1
}

echo "Source : $source"
echo "Cible  : $dest"

if (( dry_run )); then
  echo "[dry-run] copier word/ slide/ cell/ visio/ common/ vendor/ pdf/ configs/"
  echo "[dry-run] supprimer navigateur: drawingfile_ie.js drawingfile.wasm viewer.js drawingfile.js"
  echo "[dry-run] supprimer build: build/ tools/ pdf/build/ pdf/test/ Makefile *.py"
  exit 0
fi

stage=$(/usr/bin/mktemp -d "$bundle_root/.sync_sdkjs.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT

cp -R "$source" "$stage/sdkjs"

rm -f \
  "$stage/sdkjs/pdf/src/engine/drawingfile_ie.js" \
  "$stage/sdkjs/pdf/src/engine/drawingfile.wasm" \
  "$stage/sdkjs/pdf/src/engine/viewer.js" \
  "$stage/sdkjs/pdf/src/engine/drawingfile.js"

rm -rf \
  "$stage/sdkjs/build" \
  "$stage/sdkjs/tools" \
  "$stage/sdkjs/pdf/build" \
  "$stage/sdkjs/pdf/test"

rm -f \
  "$stage/sdkjs/Makefile" \
  "$stage/sdkjs/.codeclimate.yml" \
  "$stage/sdkjs/.eslintrc.yaml" \
  "$stage/sdkjs/.gitignore" \
  "$stage/sdkjs/jshintignore" \
  "$stage/sdkjs/sonar-project.properties" \
  "$stage/sdkjs/um"

find "$stage/sdkjs" -name "*.py" -delete

rm -rf "$dest"
mv "$stage/sdkjs" "$dest"

echo "Synchronisation sdkjs terminee."
du -sh "$dest"
