#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

repo=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$repo/.." && pwd)
sdkjs_source="${1:-}"
dictionaries_source="${2:-}"
vendor_source="${3:-}"
fonts_source="${4:-$workspace_root/allfontgennew/output/macos-arm64/fonts}"
output_dir="${5:-$workspace_root/output/macos-arm64/runtime}"

pick_first_existing_dir() {
  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -d "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

if [[ -z "$sdkjs_source" ]]; then
  sdkjs_source=$(pick_first_existing_dir "$repo/sdkjs" "$workspace_root/sdkjs" "$workspace_root/sdkjs-master" || true)
fi
if [[ -z "$dictionaries_source" ]]; then
  dictionaries_source=$(pick_first_existing_dir "$repo/dictionaries" "$workspace_root/dictionaries" "$workspace_root/dictionaries-master" || true)
fi
if [[ -z "$vendor_source" ]]; then
  vendor_source=$(pick_first_existing_dir "$repo/sdkjs/vendor" "$workspace_root/sdkjs/vendor" "$workspace_root/sdkjs-master/vendor" || true)
fi

if [[ "$sdkjs_source" != /* ]]; then
  sdkjs_source="$workspace_root/$sdkjs_source"
fi
if [[ "$dictionaries_source" != /* ]]; then
  dictionaries_source="$workspace_root/$dictionaries_source"
fi
if [[ "$vendor_source" != /* ]]; then
  vendor_source="$workspace_root/$vendor_source"
fi
if [[ "$fonts_source" != /* ]]; then
  fonts_source="$workspace_root/$fonts_source"
fi
if [[ "$output_dir" != /* ]]; then
  output_dir="$workspace_root/$output_dir"
fi

[[ -d "$sdkjs_source" ]] || { echo "sdkjs introuvable: $sdkjs_source" >&2; exit 1; }
[[ -d "$dictionaries_source" ]] || { echo "dictionaries introuvable: $dictionaries_source" >&2; exit 1; }
[[ -d "$vendor_source" ]] || { echo "vendor introuvable: $vendor_source" >&2; exit 1; }
[[ -f "$sdkjs_source/pdf/src/engine/cmap.bin" ]] || { echo "cmap.bin introuvable: $sdkjs_source/pdf/src/engine/cmap.bin" >&2; exit 1; }
[[ -d "$fonts_source" ]] || { echo "bundle de polices introuvable: $fonts_source" >&2; exit 1; }
[[ -f "$fonts_source/AllFonts.js" ]] || { echo "AllFonts.js introuvable dans: $fonts_source" >&2; exit 1; }

rm -rf "$output_dir"
mkdir -p "$output_dir"

cp -R "$sdkjs_source" "$output_dir/sdkjs"
cp -R "$dictionaries_source" "$output_dir/dictionaries"
cp "$sdkjs_source/pdf/src/engine/cmap.bin" "$output_dir/cmap.bin"
cp -R "$fonts_source" "$output_dir/fonts"

mkdir -p "$output_dir/sdkjs/vendor"
mkdir -p "$output_dir/sdkjs/vendor/jquery" "$output_dir/sdkjs/vendor/xregexp"
cp "$vendor_source/jquery.min.js" "$output_dir/sdkjs/vendor/jquery/jquery.min.js"
cp "$vendor_source/xregexp-all-min.js" "$output_dir/sdkjs/vendor/xregexp/xregexp-all-min.js"
cp "$output_dir/fonts/AllFonts.js" "$output_dir/sdkjs/common/AllFonts.js"

cat > "$output_dir/DoctRenderer.config" <<'EOF'
<Settings>
<file>./sdkjs/common/Native/native.js</file>
<file>./sdkjs/common/Native/jquery_native.js</file>
<allfonts>./sdkjs/common/AllFonts.js</allfonts>
<file>./sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>./sdkjs</sdkjs>
<dictionaries>./dictionaries</dictionaries>
</Settings>
EOF

echo "$output_dir"