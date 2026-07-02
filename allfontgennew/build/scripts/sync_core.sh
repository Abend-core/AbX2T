#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copies an unmodified subset of ONLYOFFICE/core source (Copyright (C) Ascensio System SIA,
# AGPLv3) into allfontgennew/src/. See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)
dest_root="$bundle_root/src"
components=(Common DesktopEditor OdfFile UnicodeConverter)

usage() {
  cat <<'EOF'
Usage: zsh allfontgennew/build/scripts/sync_core.sh [--dry-run] [source_dir]

Copies the upstream subset into allfontgennew/src/.
Only replaces: Common, DesktopEditor, OdfFile, UnicodeConverter.

- source_dir: defaults to core-master/, then core/, then corps/ at the workspace root.
- --dry-run: shows what would be done without writing anything.
EOF
}

dry_run=0
source_root=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$source_root" ]] || { echo "Only one source directory accepted." >&2; usage >&2; exit 1; }
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
  echo "core directory not found. Place core-master/ at the workspace root." >&2; exit 1
}

missing=()
for c in "${components[@]}"; do [[ -d "$source_root/$c" ]] || missing+=("$c"); done
(( ${#missing[@]} == 0 )) || {
  echo "Missing components in core: ${missing[*]}" >&2; exit 1
}

echo "Source : $source_root"
echo "Target : $dest_root"
echo "Dirs   : ${components[*]}"

if (( dry_run )); then
  for c in "${components[@]}"; do echo "[dry-run] copy $source_root/$c -> $dest_root/$c"; done
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

echo "Sync complete."
