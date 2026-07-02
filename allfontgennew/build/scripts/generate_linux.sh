#!/usr/bin/env bash

set -euo pipefail

repo=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
binary="$repo/build/bin/linux-x86_64/allfontsgen"
output_dir="${1:-output/linux-x86_64/fonts}"

if [[ "$output_dir" != /* ]]; then
  output_dir="$repo/$output_dir"
fi

if [[ ! -x "$binary" ]]; then
  bash "$repo/build/scripts/build_linux.sh" >/dev/null
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
