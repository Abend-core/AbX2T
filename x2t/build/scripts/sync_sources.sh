#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)
src_root="$bundle_root/src"

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/sync_sources.sh [--dry-run] [core_source]

Synchronise les sources C++ de x2t depuis core dans x2t/src/.
Les gros arbres de dependances sont lies vers core-master, pas copies.

- core_source: dossier core a utiliser.
  Par defaut: core-master/, puis core/, puis corps/ a la racine du workspace.
- --dry-run: affiche ce qui serait copie ou lie sans rien ecrire.
EOF
}

dry_run=0
core_root=""

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$core_root" ]] || { echo "Un seul dossier core accepte." >&2; usage >&2; exit 1; }
      core_root="$1"
      ;;
  esac
  shift
done

pick_first_existing_dir() {
  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -d "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

copy_tree() {
  local source="$1" target="$2"
  mkdir -p "${target:h}"
  rm -rf "$target"
  cp -R "$source" "$target"
}

link_tree() {
  local source="$1" target="$2"
  mkdir -p "${target:h}"
  rm -rf "$target"
  ln -s "$source" "$target"
}

copy_common_overlay() {
  local source="$1" target="$2" entry base
  mkdir -p "$target"
  while IFS= read -r entry; do
    base="${entry:t}"
    [[ "$base" == "3dParty" ]] && continue
    if [[ -d "$entry" ]]; then
      case "$base" in cfcpp|Network|empty) copy_tree "$entry" "$target/$base" ;; esac
    elif [[ -f "$entry" ]]; then
      cp "$entry" "$target/$base"
    fi
  done < <(/usr/bin/find "$source" -mindepth 1 -maxdepth 1 -print)
  link_tree "../../../core-master/Common/3dParty" "$target/3dParty"
}

copy_desktopeditor_overlay() {
  local source="$1" target="$2"
  mkdir -p "$target"
  for d in common doctrenderer fontengine graphics xmlsec; do
    [[ -d "$source/$d" ]] || { echo "DesktopEditor/$d manquant" >&2; exit 1; }
    copy_tree "$source/$d" "$target/$d"
  done
  for d in AllFontsGen agg-2.4 allthemesgen cximage freetype-2.10.4 freetype-2.5.2 freetype_names pluginsmanager raster vboxtester xml; do
    [[ -e "$source/$d" ]] || { echo "DesktopEditor/$d manquant" >&2; exit 1; }
    link_tree "../../../core-master/DesktopEditor/$d" "$target/$d"
  done
}

prune_nonessential_trees() {
  local root="$1"
  for name in test tests Test examples ExampleFiles; do
    while IFS= read -r d; do rm -rf "$d"; done < <(/usr/bin/find "$root" -type d -name "$name")
  done
}

if [[ -z "$core_root" ]]; then
  core_root=$(pick_first_existing_dir \
    "$workspace_root/core-master" \
    "$workspace_root/core" \
    "$workspace_root/corps" || true)
fi

[[ -n "$core_root" && -d "$core_root" ]] || {
  echo "Dossier core introuvable. Deposer core-master/ a la racine du workspace." >&2; exit 1
}

required_components=(
  Common DesktopEditor OOXML OfficeUtils X2tConverter
  MsBinaryFile OdfFile RtfFile TxtFile UnicodeConverter
  PdfFile HtmlFile2 Fb2File EpubFile XpsFile OFDFile DjVuFile DocxRenderer Apple HwpFile
)

missing=()
for c in "${required_components[@]}"; do
  [[ -d "$core_root/$c" ]] || missing+=("$c")
done
(( ${#missing[@]} == 0 )) || {
  echo "Composants manquants dans core: ${missing[*]}" >&2; exit 1
}

echo "Core        : $core_root"
echo "Destination : $src_root"

if (( dry_run )); then
  echo "[dry-run] copier Common (sans 3dParty) + lier Common/3dParty"
  echo "[dry-run] copier DesktopEditor/{common,doctrenderer,fontengine,graphics,xmlsec}"
  echo "[dry-run] lier DesktopEditor/{AllFontsGen,freetype-2.10.4,...}"
  for c in OOXML OfficeUtils X2tConverter MsBinaryFile OdfFile RtfFile TxtFile UnicodeConverter; do
    echo "[dry-run] copier $c"
  done
  for c in PdfFile HtmlFile2 Fb2File EpubFile XpsFile OFDFile DjVuFile DocxRenderer Apple HwpFile; do
    echo "[dry-run] lier  $c"
  done
  echo "[dry-run] elaguer test/ tests/ examples/ ExampleFiles/"
  exit 0
fi

stage=$(/usr/bin/mktemp -d "$bundle_root/.sync_sources.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT

mkdir -p "$stage/src"

copy_common_overlay "$core_root/Common" "$stage/src/Common"
copy_desktopeditor_overlay "$core_root/DesktopEditor" "$stage/src/DesktopEditor"

for c in OOXML OfficeUtils X2tConverter MsBinaryFile OdfFile RtfFile TxtFile UnicodeConverter; do
  copy_tree "$core_root/$c" "$stage/src/$c"
done
for c in PdfFile HtmlFile2 Fb2File EpubFile XpsFile OFDFile DjVuFile DocxRenderer Apple HwpFile; do
  link_tree "../../../core-master/$c" "$stage/src/$c"
done

prune_nonessential_trees "$stage/src"

rm -rf "$src_root"
mv "$stage/src" "$src_root"

echo "Synchronisation sources terminee."
