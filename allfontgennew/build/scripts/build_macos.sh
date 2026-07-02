#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Compiles allfontsgen from a vendored subset of ONLYOFFICE/core source (Copyright (C)
# Ascensio System SIA, AGPLv3, see allfontgennew/src/). Calls prepare_generated_sources.sh,
# which applies a build-time patch to one source file. See /THIRD-PARTY-NOTICES.md.

set -euo pipefail

repo=$(cd -- "${0:A:h}/../.." && pwd)
sdk=$(xcrun --show-sdk-path)
obj_dir="$repo/build/out/macos-arm64/obj"
bin_dir="$repo/build/bin/macos-arm64"
binary="$bin_dir/allfontsgen"
generated_root="$repo/build/generated"

mkdir -p "$obj_dir" "$bin_dir"
rm -f "$obj_dir"/*.o(N) "$binary"

bash "$repo/build/scripts/prepare_generated_sources.sh" >/dev/null

common_sources=("${(@f)$(<"$repo/build/config/common_sources.txt")}")
platform_sources=("${(@f)$(<"$repo/build/config/macos_arm64_sources.txt")}")
include_dirs=("${(@f)$(<"$repo/build/config/common_include_dirs.txt")}")
common_defines=("${(@f)$(<"$repo/build/config/common_defines.txt")}")
platform_defines=("${(@f)$(<"$repo/build/config/macos_arm64_defines.txt")}")
frameworks=("${(@f)$(<"$repo/build/config/macos_arm64_frameworks.txt")}")

define_args=()
for define in "${common_defines[@]}" "${platform_defines[@]}"; do
  [[ -n "$define" ]] && define_args+=("-D$define")
done

include_args=()
for include_dir in "${include_dirs[@]}"; do
  [[ -n "$include_dir" ]] && include_args+=("-I$repo/$include_dir")
done

warning_args=(
  -Wno-deprecated-declarations
  -Wno-parentheses
  -Wno-writable-strings
)

objects=()
sources=("${common_sources[@]}" "${platform_sources[@]}")

for source in "${sources[@]}"; do
  [[ -z "$source" ]] && continue

  abs_source="$repo/$source"
  if [[ -f "$generated_root/$source" ]]; then
    abs_source="$generated_root/$source"
  fi

  object_name="${source//\//__}"
  object_name="${object_name//./_}.o"
  object="$obj_dir/$object_name"

  case "$source" in
    *.mm)
      clang++ -std=c++17 -O2 -isysroot "$sdk" -include "$repo/build/shims/posix_compat.h" \
        "${warning_args[@]}" "${define_args[@]}" "${include_args[@]}" \
        -c "$abs_source" -o "$object"
      ;;
    *.c)
      clang -std=c11 -O2 -isysroot "$sdk" -include "$repo/build/shims/posix_compat.h" \
        "${warning_args[@]}" "${define_args[@]}" "${include_args[@]}" \
        -c "$abs_source" -o "$object"
      ;;
    *)
      clang++ -std=c++17 -O2 -isysroot "$sdk" -include "$repo/build/shims/posix_compat.h" \
        "${warning_args[@]}" "${define_args[@]}" "${include_args[@]}" \
        -c "$abs_source" -o "$object"
      ;;
  esac

  objects+=("$object")
done

framework_args=()
for framework in "${frameworks[@]}"; do
  [[ -n "$framework" ]] && framework_args+=(-framework "$framework")
done

clang++ -isysroot "$sdk" "${objects[@]}" "${framework_args[@]}" -o "$binary"

echo "$binary"

