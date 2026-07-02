#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Packages unmodified ONLYOFFICE binaries/JS (Copyright (C) Ascensio System SIA, AGPLv3) into
# assets.zip, unchanged. See /THIRD-PARTY-NOTICES.md.
#
# macOS equivalent of package_windows.ps1. Assembles convert/convert/assets.zip (resource
# embedded in Abx2t), gathering x2t + its .framework bundles + the full x2t/sdkjs/ tree
# (from x2t/bin/macos-arm64/ and x2t/sdkjs/, populated by x2t/build/scripts/sync_from_release.sh)
# and allfontsgen (from allfontsgen/build/bin/macos-arm64/, compiled by
# allfontsgen/build/scripts/build_macos.sh if missing).
#
# Uses ditto (not zip/Compress-Archive) to build the archive: .framework bundles rely on
# symlinks (Versions/Current -> A, etc.) and on their code signature's extended attributes --
# ditto is the macOS-native tool that preserves both through a zip round-trip; a plain
# zip/unzip or .NET's ZipArchive would flatten the symlinks and break dyld's framework lookup.
# Program.cs extracts this archive on macOS via `ditto -x -k`, matching what built it.
#
# Usage: zsh convert/build/package_macos.sh
#
# Prerequisite: run x2t/build/scripts/sync_from_release.sh at least once.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

convert_root=$(cd -- "${0:A:h}/.." && pwd)
repo=$(cd -- "$convert_root/.." && pwd)

x2t_bin="$repo/x2t/bin/macos-arm64"
sdkjs_src="$repo/x2t/sdkjs"
allfontsgen="$repo/allfontsgen/build/bin/macos-arm64/allfontsgen"
assets_zip="$convert_root/convert/assets.zip"

[[ -f "$x2t_bin/x2t" ]] || { echo "x2t not found in $x2t_bin -- run x2t/build/scripts/sync_from_release.sh first" >&2; exit 1; }
[[ -d "$sdkjs_src" ]] || { echo "sdkjs not found in $sdkjs_src -- run x2t/build/scripts/sync_from_release.sh first" >&2; exit 1; }

if [[ ! -f "$allfontsgen" ]]; then
  echo "allfontsgen not found -- compiling..."
  zsh "$repo/allfontsgen/build/scripts/build_macos.sh"
  [[ -f "$allfontsgen" ]] || { echo "Failed to compile allfontsgen" >&2; exit 1; }
fi

stage=$(/usr/bin/mktemp -d "$convert_root/.package_macos.XXXXXX")
trap 'rm -rf "$stage"' EXIT

cp "$x2t_bin/x2t" "$stage/"
chmod +x "$stage/x2t"
for fw in "$x2t_bin"/*.framework(N); do
  cp -R "$fw" "$stage/"
done
cp "$allfontsgen" "$stage/"
chmod +x "$stage/allfontsgen"

cp -R "$sdkjs_src" "$stage/sdkjs"

# License texts: keep the single-exe distribution self-contained legally -- extracted to
# resources/ on first run alongside the components they cover.
cp "$repo/LICENSE" "$stage/"
cp "$repo/THIRD-PARTY-NOTICES.md" "$stage/"

cat > "$stage/DoctRenderer.config" <<'CONF'
<Settings>
<file>./sdkjs/common/Native/native.js</file>
<file>./sdkjs/common/Native/jquery_native.js</file>
<allfonts>./sdkjs/common/AllFonts.js</allfonts>
<file>./sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>./sdkjs</sdkjs>
</Settings>
CONF

rm -f "$assets_zip"
( cd "$stage" && ditto -c -k . "$assets_zip.tmp" && mv "$assets_zip.tmp" "$assets_zip" )

echo ""
echo "OK: $assets_zip"
echo "Next step: dotnet publish convert/convert/convert.csproj -c Release -r osx-arm64"
