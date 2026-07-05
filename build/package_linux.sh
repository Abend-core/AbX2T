#!/usr/bin/env bash
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Packages unmodified ONLYOFFICE binaries/JS (Copyright (C) Ascensio System SIA, AGPLv3) into
# assets.zip, unchanged. See /THIRD-PARTY-NOTICES.md.
#
# Linux equivalent of package_windows.ps1 / package_macos.sh. Assembles
# src/assets.zip (resource embedded in Abx2t), gathering x2t + its .so
# libraries + ICU data + the full x2t/sdkjs/ tree (from x2t/bin/linux-x86_64/ and
# x2t/sdkjs/, populated by x2t/build/scripts/sync_from_release_linux.sh) and allfontsgen
# (from allfontsgen/build/bin/linux-x86_64/, compiled by
# allfontsgen/build/scripts/build_linux.sh if missing).
#
# The zip is built with python3's zipfile, storing each entry's Unix mode in the
# external attributes: .NET's ZipArchive restores those permissions on extraction
# (and Program.cs re-chmods x2t/allfontsgen as a belt-and-braces measure), so the
# executables come out runnable without any manual step.
#
# Usage: bash build/package_linux.sh
#
# Prerequisite: run x2t/build/scripts/sync_from_release_linux.sh at least once.

set -euo pipefail

repo=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

x2t_bin="$repo/x2t/bin/linux-x86_64"
sdkjs_src="$repo/x2t/sdkjs"
allfontsgen="$repo/allfontsgen/build/bin/linux-x86_64/allfontsgen"
assets_zip="$repo/src/assets.zip"

[[ -f "$x2t_bin/x2t" ]] || { echo "x2t not found in $x2t_bin -- run x2t/build/scripts/sync_from_release_linux.sh first" >&2; exit 1; }
[[ -d "$sdkjs_src" ]] || { echo "sdkjs not found in $sdkjs_src -- run x2t/build/scripts/sync_from_release_linux.sh first" >&2; exit 1; }

if [[ ! -f "$allfontsgen" ]]; then
  echo "allfontsgen not found -- compiling..."
  bash "$repo/allfontsgen/build/scripts/build_linux.sh"
  [[ -f "$allfontsgen" ]] || { echo "Failed to compile allfontsgen" >&2; exit 1; }
fi

stage=$(mktemp -d "${TMPDIR:-/tmp}/abx2t_package_linux.XXXXXX")
trap 'rm -rf "$stage"' EXIT

cp "$x2t_bin/x2t" "$stage/"
chmod +x "$stage/x2t"
cp "$x2t_bin"/*.so* "$stage/"
for dat in icudtl.dat icudtl_extra.dat; do
  [[ -f "$x2t_bin/$dat" ]] && cp "$x2t_bin/$dat" "$stage/"
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
python3 - "$stage" "$assets_zip" <<'PY'
import os, stat, sys, zipfile

stage, dest = sys.argv[1], sys.argv[2]
tmp = dest + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for root, dirs, files in os.walk(stage):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(root, name)
            arcname = os.path.relpath(path, stage)
            st = os.stat(path)
            zi = zipfile.ZipInfo.from_file(path, arcname)
            zi.external_attr = (stat.S_IMODE(st.st_mode) | stat.S_IFREG) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(path, "rb") as f:
                zf.writestr(zi, f.read(), compresslevel=9)
os.replace(tmp, dest)
PY

echo ""
echo "OK: $assets_zip ($(du -h "$assets_zip" | cut -f1))"
echo "Next step: dotnet publish src/Abx2t.csproj -c Release -r linux-x64"
