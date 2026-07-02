#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Invokes ONLYOFFICE x2t (Copyright (C) Ascensio System SIA, AGPLv3) as an unmodified
# subprocess. See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

bundle_root=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$bundle_root/.." && pwd)

usage() {
  cat <<'EOF'
Usage: zsh x2t/build/scripts/convert.sh <source_file> <output_file> [fontdir]

Converts a document via x2t/bin/x2t, managing the working temp directory
ourselves (mktemp + guaranteed cleanup via trap) instead of letting x2t
create one next to the output file.

On macOS/Linux, x2t (DesktopEditor/common/Directory.cpp) tries to clean up its
own temp directory via rmdir(), but its recursive listing function ignores
hidden subdirectories (names starting with '.'). If such a subdirectory
survives, rmdir() fails silently (the return code isn't checked) and an
orphaned "ascXXXXXX" directory is left behind next to the converted file.
This can't be fixed without recompiling x2t (here we use an official
pre-compiled binary).

By providing an explicit m_sTempDir, x2t delegates cleanup to the caller:
this script guarantees the temp directory is removed, on success or failure.

fontdir: fonts directory (default: allfontsgen/output/macos-arm64/fonts)
EOF
}

if [[ $# -lt 2 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  [[ $# -lt 2 ]] && exit 1
  exit 0
fi

file_from=$1
file_to=$2
font_dir=${3:-"$workspace_root/allfontsgen/output/macos-arm64/fonts"}

x2t_bin="$bundle_root/bin/x2t"
all_fonts="$bundle_root/sdkjs/common/AllFonts.js"

[[ -x "$x2t_bin" ]] || { echo "Binary not found: $x2t_bin (run sync_from_release.sh)" >&2; exit 1; }
[[ -f "$all_fonts" ]] || { echo "AllFonts.js not found: $all_fonts" >&2; exit 1; }
[[ -d "$font_dir" ]] || { echo "Fonts directory not found: $font_dir" >&2; exit 1; }
[[ -f "$file_from" ]] || { echo "Source file not found: $file_from" >&2; exit 1; }

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
