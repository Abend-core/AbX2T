# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Packages unmodified ONLYOFFICE binaries/JS (Copyright (C) Ascensio System SIA, AGPLv3) into
# assets.zip, unchanged. See /THIRD-PARTY-NOTICES.md.
#Requires -Version 5.1
<#
.SYNOPSIS
Assembles src/assets.zip (resource embedded in Abx2t.exe).

.DESCRIPTION
Gathers x2t.exe + all DLLs (x2t.exe statically imports them at startup, none can be
removed without recompiling) + the full x2t/sdkjs/ tree (common, word, cell, slide, visio,
pdf, vendor) (from x2t/bin/windows-x86_64/ and x2t/sdkjs/, populated by
x2t/build/scripts/sync_from_install_windows.ps1) and allfontsgen.exe (from
allfontsgen/build/bin/windows-x86_64/, compiled by allfontsgen/build/scripts/build_windows.ps1
if missing) into src/assets.zip. This zip is automatically extracted by Abx2t.exe
into a resources/ folder on first run (see src/Program.cs).

Prerequisite: run x2t/build/scripts/sync_from_install_windows.ps1 at least once.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File build\package_windows.ps1
#>
param()

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$x2tBin       = Join-Path $repo 'x2t\bin\windows-x86_64'
$sdkjsSrc     = Join-Path $repo 'x2t\sdkjs'
$allfontsgen  = Join-Path $repo 'allfontsgen\build\bin\windows-x86_64\allfontsgen.exe'
$assetsZip    = Join-Path $repo 'src\assets.zip'

if (-not (Test-Path (Join-Path $x2tBin 'x2t.exe'))) {
    Write-Error "x2t.exe not found in $x2tBin -- run x2t\build\scripts\sync_from_install_windows.ps1 first"
}
if (-not (Test-Path $sdkjsSrc)) {
    Write-Error "sdkjs not found in $sdkjsSrc -- run x2t\build\scripts\sync_from_install_windows.ps1 first"
}

if (-not (Test-Path $allfontsgen)) {
    Write-Host "allfontsgen.exe not found -- compiling..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $repo 'allfontsgen\build\scripts\build_windows.ps1')
    if (-not (Test-Path $allfontsgen)) {
        Write-Error "Failed to compile allfontsgen.exe"
    }
}

$stage = Join-Path $env:TEMP "abx2t_package_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $stage | Out-Null

try {
    Copy-Item (Join-Path $x2tBin 'x2t.exe') $stage -Force
    Get-ChildItem $x2tBin -Filter '*.dll' | ForEach-Object { Copy-Item $_.FullName $stage -Force }
    Copy-Item $allfontsgen $stage -Force

    Copy-Item $sdkjsSrc (Join-Path $stage 'sdkjs') -Recurse -Force

    # License texts: keep the single-exe distribution self-contained legally --
    # extracted to resources\ on first run alongside the components they cover.
    Copy-Item (Join-Path $repo 'LICENSE') $stage -Force
    Copy-Item (Join-Path $repo 'THIRD-PARTY-NOTICES.md') $stage -Force

    @'
<Settings>
<file>./sdkjs/common/Native/native.js</file>
<file>./sdkjs/common/Native/jquery_native.js</file>
<allfonts>./sdkjs/common/AllFonts.js</allfonts>
<file>./sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>./sdkjs</sdkjs>
</Settings>
'@ | Set-Content -Path (Join-Path $stage 'DoctRenderer.config') -Encoding UTF8

    if (Test-Path $assetsZip) { Remove-Item $assetsZip -Force }
    Compress-Archive -Path "$stage\*" -DestinationPath $assetsZip -Force
}
finally {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}

Write-Host ""
Write-Host "OK: $assetsZip"
Write-Host "Next step: dotnet publish src\Abx2t.csproj -c Release"
