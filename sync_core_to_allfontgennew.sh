#!/usr/bin/env zsh

set -euo pipefail

workspace_root=$(cd -- "${0:A:h}" && pwd)
bundle_root="$workspace_root/allfontgennew"
dest_root="$bundle_root/src"
components=(
  Common
  DesktopEditor
  OdfFile
  UnicodeConverter
)

usage() {
  cat <<'EOF'
Usage: zsh ./sync_core_to_allfontgennew.sh [--dry-run] [source_dir]

Ce script copie le sous-ensemble upstream attendu dans allfontgennew/src.

- Sans argument, il cherche d'abord ./core, puis ./core-master, puis ./corps.
- Il ne remplace que: Common, DesktopEditor, OdfFile, UnicodeConverter.
- --dry-run affiche ce qui serait fait sans rien ecrire.
EOF
}

dry_run=0
source_root=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$source_root" ]]; then
        echo "Un seul dossier source est accepte." >&2
        usage >&2
        exit 1
      fi
      source_root="$1"
      ;;
  esac
  shift
done

if [[ -z "$source_root" ]]; then
  for candidate in "$workspace_root/core" "$workspace_root/core-master" "$workspace_root/corps"; do
    if [[ -d "$candidate" ]]; then
      source_root="$candidate"
      break
    fi
  done
fi

if [[ -z "$source_root" ]]; then
  echo "Aucun dossier source trouve. Depose un dossier core a la racine, ou passe le chemin en argument." >&2
  exit 1
fi

if [[ "$source_root" != /* ]]; then
  source_root="$workspace_root/$source_root"
fi

if [[ ! -d "$source_root" ]]; then
  echo "Dossier source introuvable: $source_root" >&2
  exit 1
fi

if [[ ! -d "$bundle_root" ]]; then
  echo "Bundle introuvable: $bundle_root" >&2
  exit 1
fi

mkdir -p "$dest_root"

missing_components=()
for component in "${components[@]}"; do
  if [[ ! -d "$source_root/$component" ]]; then
    missing_components+=("$component")
  fi
done

if (( ${#missing_components[@]} > 0 )); then
  echo "Le dossier source ne contient pas tous les sous-dossiers attendus." >&2
  echo "Manquants: ${missing_components[*]}" >&2
  exit 1
fi

echo "Source  : $source_root"
echo "Cible   : $dest_root"
echo "Dossiers: ${components[*]}"

if (( dry_run )); then
  for component in "${components[@]}"; do
    echo "[dry-run] copier $source_root/$component -> $dest_root/$component"
  done
  exit 0
fi

stage_root=$(mktemp -d "$bundle_root/.sync_core.XXXXXX")
cleanup() {
  rm -rf "$stage_root"
}
trap cleanup EXIT

for component in "${components[@]}"; do
  cp -R "$source_root/$component" "$stage_root/$component"
done

for component in "${components[@]}"; do
  rm -rf "$dest_root/$component"
  mv "$stage_root/$component" "$dest_root/$component"
  echo "OK: $component"
done

echo "Synchronisation terminee."