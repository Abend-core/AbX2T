#!/usr/bin/env bash

set -euo pipefail

repo=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
obj_dir="$repo/build/out/linux-x86_64/obj"
bin_dir="$repo/build/bin/linux-x86_64"
binary="$bin_dir/allfontsgen"
generated_root="$repo/build/generated"

mkdir -p "$obj_dir" "$bin_dir"
rm -f "$obj_dir"/*.o "$binary" 2>/dev/null || true

bash "$repo/build/scripts/prepare_generated_sources.sh" >/dev/null

read_manifest() {
  tr -d '\r' < "$1" | grep -v '^[[:space:]]*$'
}

mapfile -t common_sources < <(read_manifest "$repo/build/config/common_sources.txt")
mapfile -t platform_sources < <(read_manifest "$repo/build/config/linux_x86_64_sources.txt")
mapfile -t include_dirs < <(read_manifest "$repo/build/config/common_include_dirs.txt")
mapfile -t common_defines < <(read_manifest "$repo/build/config/common_defines.txt")
mapfile -t platform_defines < <(read_manifest "$repo/build/config/linux_x86_64_defines.txt")

define_args=()
for define in "${common_defines[@]}" "${platform_defines[@]}"; do
  define_args+=("-D$define")
done

include_args=()
for include_dir in "${include_dirs[@]}"; do
  include_args+=("-I$repo/$include_dir")
done

warning_args=(
  -Wno-deprecated-declarations
  -Wno-parentheses
)

objects=()
sources=("${common_sources[@]}" "${platform_sources[@]}")

for source in "${sources[@]}"; do
  abs_source="$repo/$source"
  if [[ -f "$generated_root/$source" ]]; then
    abs_source="$generated_root/$source"
  fi

  object_name="${source//\//__}"
  object_name="${object_name//./_}.o"
  object="$obj_dir/$object_name"

  case "$source" in
    *.c)
      gcc -std=c11 -O2 -fPIC -include "$repo/build/shims/posix_compat.h" \
        "${warning_args[@]}" "${define_args[@]}" "${include_args[@]}" \
        -c "$abs_source" -o "$object"
      ;;
    *)
      g++ -std=c++17 -O2 -fPIC -include "$repo/build/shims/posix_compat.h" \
        "${warning_args[@]}" "${define_args[@]}" "${include_args[@]}" \
        -c "$abs_source" -o "$object"
      ;;
  esac

  objects+=("$object")
done

g++ "${objects[@]}" -lpthread -ldl -o "$binary"

echo "$binary"
