#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/convert.sh <fichier_source> <fichier_sortie> [fontdir]

Convertit un document via x2t/bin/x2t en gerant nous-memes le dossier temporaire
de travail (mktemp + nettoyage garanti par trap), plutot que de laisser x2t
en creer un a cote du fichier de sortie.

Sur macOS/Linux, x2t (DesktopEditor/common/Directory.cpp) essaie de nettoyer son
dossier temporaire automatique via rmdir(), mais sa fonction de listage recursif
ignore les sous-dossiers caches (noms commencant par '.'). Si un tel sous-dossier
survit, rmdir() echoue silencieusement (le code retour n'est pas verifie) et un
dossier "ascXXXXXX" reste orphelin a cote du fichier converti. Impossible a
corriger sans recompiler x2t (ici on utilise un binaire pre-compile officiel).

En fournissant un m_sTempDir explicite, x2t delegue le nettoyage a l'appelant :
ce script garantit la suppression du dossier temporaire, succes ou echec.

fontdir: dossier des polices (defaut: allfontgennew/output/macos-arm64/fonts)
EOF
}

if [[ $# -lt 2 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  [[ $# -lt 2 ]] && exit 1
  exit 0
fi

file_from=$1
file_to=$2
font_dir=${3:-"$workspace_root/allfontgennew/output/macos-arm64/fonts"}

x2t_bin="$bundle_root/bin/x2t"
all_fonts="$bundle_root/sdkjs/common/AllFonts.js"

[[ -x "$x2t_bin" ]] || { echo "Binaire introuvable: $x2t_bin (lancer sync_from_release.sh)" >&2; exit 1; }
[[ -f "$all_fonts" ]] || { echo "AllFonts.js introuvable: $all_fonts" >&2; exit 1; }
[[ -d "$font_dir" ]] || { echo "Dossier de polices introuvable: $font_dir" >&2; exit 1; }
[[ -f "$file_from" ]] || { echo "Fichier source introuvable: $file_from" >&2; exit 1; }

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/x2t-convert.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$work_dir/temp"
config="$work_dir/config.xml"

cat > "$config" <<CONF
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>$file_from</m_sFileFrom>
    <m_sFileTo>$file_to</m_sFileTo>
    <m_sAllFontsPath>$all_fonts</m_sAllFontsPath>
    <m_sFontDir>$font_dir</m_sFontDir>
    <m_sTempDir>$work_dir/temp</m_sTempDir>
</TaskQueueDataConvert>
CONF

cd "$bundle_root/bin"
./x2t "$config"
