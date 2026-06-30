#!/usr/bin/env zsh

set -euo pipefail

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)
dest_root="$bundle_root/src"
components=(Common DesktopEditor OdfFile UnicodeConverter)

usage() {
  cat <<'EOF'
Usage: zsh allfontgennew/build/scripts/sync_core.sh [--dry-run] [source_dir]

Copie le sous-ensemble upstream dans allfontgennew/src/.
Remplace uniquement: Common, DesktopEditor, OdfFile, UnicodeConverter.

- source_dir: par defaut core-master/, puis core/, puis corps/ a la racine.
- --dry-run: affiche ce qui serait fait sans ecrire.
EOF
}

dry_run=0
source_root=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$source_root" ]] || { echo "Un seul dossier source accepte." >&2; usage >&2; exit 1; }
      source_root="$1"
      ;;
  esac
  shift
done

if [[ -z "$source_root" ]]; then
  for candidate in "$workspace_root/core-master" "$workspace_root/core" "$workspace_root/corps"; do
    [[ -d "$candidate" ]] && { source_root="$candidate"; break; }
  done
fi

[[ -n "$source_root" && -d "$source_root" ]] || {
  echo "Dossier core introuvable. Deposer core-master/ a la racine du workspace." >&2; exit 1
}

missing=()
for c in "${components[@]}"; do [[ -d "$source_root/$c" ]] || missing+=("$c"); done
(( ${#missing[@]} == 0 )) || {
  echo "Composants manquants dans core: ${missing[*]}" >&2; exit 1
}

echo "Source  : $source_root"
echo "Cible   : $dest_root"
echo "Dossiers: ${components[*]}"

if (( dry_run )); then
  for c in "${components[@]}"; do echo "[dry-run] copier $source_root/$c -> $dest_root/$c"; done
  exit 0
fi

stage=$(mktemp -d "$bundle_root/.sync_core.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT

for c in "${components[@]}"; do cp -R "$source_root/$c" "$stage/$c"; done
for c in "${components[@]}"; do
  rm -rf "$dest_root/$c"
  mv "$stage/$c" "$dest_root/$c"
  echo "OK: $c"
done

echo "Synchronisation terminee."
