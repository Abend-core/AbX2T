#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Runs allfontsgen (built from ONLYOFFICE/core source, AGPLv3). See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

repo=$(cd -- "${0:A:h}/../.." && pwd)
binary="$repo/build/bin/macos-arm64/allfontsgen"
output_dir="${1:-output/macos-arm64/fonts}"

if [[ "$output_dir" != /* ]]; then
  output_dir="$repo/$output_dir"
fi

if [[ ! -x "$binary" ]]; then
  zsh "$repo/build/scripts/build_macos.sh" >/dev/null
fi

mkdir -p "$output_dir"

"$binary" \
  --use-system=true \
  --use-system-user-fonts=true \
  --selection="$output_dir/font_selection.bin" \
  --allfonts="$output_dir/AllFonts.js" \
  --allfonts-web="$output_dir/AllFonts2.js" \
  --output-web="$output_dir"

echo "Generated in: $output_dir"
