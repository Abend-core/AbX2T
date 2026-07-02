# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copies unmodified binaries/JS from a local ONLYOFFICE Desktop Editors install (Copyright (C)
# Ascensio System SIA, AGPLv3) into this bundle. See /THIRD-PARTY-NOTICES.md.
#Requires -Version 5.1
<#
.SYNOPSIS
Synchronizes the x2t bundle from a local ONLYOFFICE Desktop Editors installation (Windows).

.DESCRIPTION
Windows equivalent of build/scripts/sync_from_release.sh (macOS): populates
x2t/bin/windows-x86_64/ (x2t.exe binary + DLLs + DoctRenderer.config) and x2t/sdkjs/
(minimal JS needed for conversion) from an ONLYOFFICE Desktop Editors installation
already present on the machine.

.PARAMETER InstallDir
ONLYOFFICE Desktop Editors installation directory. Must contain converter/ and editors/.
Default: C:\Program Files\ONLYOFFICE\DesktopEditors

.PARAMETER DryRun
Shows what would be done without writing anything.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File sync_from_install_windows.ps1
powershell -ExecutionPolicy Bypass -File sync_from_install_windows.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File sync_from_install_windows.ps1 -InstallDir "D:\ONLYOFFICE\DesktopEditors"
#>
param(
    [string]$InstallDir = "C:\Program Files\ONLYOFFICE\DesktopEditors",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$bundleRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$converterDir = Join-Path $InstallDir 'converter'
$editorsDir   = Join-Path $InstallDir 'editors'

if (-not (Test-Path (Join-Path $converterDir 'x2t.exe'))) {
    Write-Error "x2t.exe not found in $converterDir -- check -InstallDir or install ONLYOFFICE Desktop Editors"
}
if (-not (Test-Path $editorsDir)) {
    Write-Error "editors directory not found: $editorsDir"
}

$sdkjsSrc   = Join-Path $editorsDir 'sdkjs'
$vendorSrc  = Join-Path $editorsDir 'web-apps\vendor'

if (-not (Test-Path $sdkjsSrc))  { Write-Error "editors\sdkjs not found: $sdkjsSrc" }
if (-not (Test-Path $vendorSrc)) { Write-Error "editors\web-apps\vendor not found: $vendorSrc" }

$binDest   = Join-Path $bundleRoot 'bin\windows-x86_64'
$sdkjsDest = Join-Path $bundleRoot 'sdkjs'

Write-Host "Converter   : $converterDir"
Write-Host "Editors     : $editorsDir"
Write-Host "Destination bin   : $binDest"
Write-Host "Destination sdkjs : $sdkjsDest"

# JS files needed for conversion (same as sync_from_release.sh on macOS)
$sdkjsFiles = @(
    'common\Native\native.js',
    'common\Native\jquery_native.js',
    'common\libfont\engine\fonts_native.js',
    'word\sdk-all-min.js',
    'word\sdk-all.js',
    'slide\sdk-all-min.js',
    'slide\sdk-all.js',
    'cell\sdk-all-min.js',
    'cell\sdk-all.js',
    'visio\sdk-all-min.js',
    'visio\sdk-all.js',
    'pdf\src\engine\drawingfile_native.js',
    'pdf\src\engine\cmap.bin'
)

$missing = @()
foreach ($f in $sdkjsFiles) {
    if (-not (Test-Path (Join-Path $sdkjsSrc $f))) { $missing += $f }
}
if (-not (Test-Path (Join-Path $vendorSrc 'xregexp\xregexp-all-min.js'))) {
    $missing += 'web-apps\vendor\xregexp\xregexp-all-min.js'
}
if ($missing.Count -gt 0) {
    Write-Error "Missing files in the installation:`n$($missing -join "`n")"
}

$dlls = @(Get-ChildItem $converterDir -Filter '*.dll' -ErrorAction SilentlyContinue)

if ($DryRun) {
    Write-Host ""
    Write-Host "[dry-run] --- bin\windows-x86_64\ ---"
    Write-Host "[dry-run] copy x2t.exe"
    foreach ($dll in $dlls) { Write-Host "[dry-run] copy $($dll.Name)" }
    Write-Host "[dry-run] write DoctRenderer.config"
    Write-Host ""
    Write-Host "[dry-run] --- sdkjs\ ---"
    foreach ($f in $sdkjsFiles) { Write-Host "[dry-run] copy $f" }
    Write-Host "[dry-run] copy vendor\xregexp\xregexp-all-min.js"
    exit 0
}

# --- Sync bin\windows-x86_64\ ---
$stageBin = Join-Path $bundleRoot ".sync_bin_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $stageBin | Out-Null
try {
    Copy-Item (Join-Path $converterDir 'x2t.exe') $stageBin -Force
    foreach ($dll in $dlls) { Copy-Item $dll.FullName $stageBin -Force }

    @'
<Settings>
<file>..\..\sdkjs\common\Native\native.js</file>
<file>..\..\sdkjs\common\Native\jquery_native.js</file>
<allfonts>..\..\sdkjs\common\AllFonts.js</allfonts>
<file>..\..\sdkjs\vendor\xregexp\xregexp-all-min.js</file>
<sdkjs>..\..\sdkjs</sdkjs>
</Settings>
'@ | Set-Content -Path (Join-Path $stageBin 'DoctRenderer.config') -Encoding UTF8

    if (Test-Path $binDest) { Remove-Item $binDest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $binDest) | Out-Null
    Move-Item $stageBin $binDest
}
finally {
    if (Test-Path $stageBin) { Remove-Item $stageBin -Recurse -Force }
}

# --- Sync sdkjs\ ---
$stageSdkjs = Join-Path $bundleRoot ".sync_sdkjs_$([guid]::NewGuid().ToString('N'))"
try {
    foreach ($f in $sdkjsFiles) {
        $target = Join-Path $stageSdkjs $f
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item (Join-Path $sdkjsSrc $f) $target -Force
    }

    $vendorDest = Join-Path $stageSdkjs 'vendor\xregexp'
    New-Item -ItemType Directory -Force -Path $vendorDest | Out-Null
    Copy-Item (Join-Path $vendorSrc 'xregexp\xregexp-all-min.js') $vendorDest -Force

    # Preserve AllFonts.js if already present
    $existingAllFonts = Join-Path $sdkjsDest 'common\AllFonts.js'
    if (Test-Path $existingAllFonts) {
        $preservedDest = Join-Path $stageSdkjs 'common'
        New-Item -ItemType Directory -Force -Path $preservedDest | Out-Null
        Copy-Item $existingAllFonts (Join-Path $preservedDest 'AllFonts.js') -Force
    }

    if (Test-Path $sdkjsDest) { Remove-Item $sdkjsDest -Recurse -Force }
    Move-Item $stageSdkjs $sdkjsDest
}
finally {
    if (Test-Path $stageSdkjs) { Remove-Item $stageSdkjs -Recurse -Force }
}

Write-Host ""
Write-Host "bin\windows-x86_64\ : OK ($binDest)"
Write-Host "sdkjs\              : OK ($sdkjsDest)"
Write-Host ""
Write-Host "Next step -- copy AllFonts.js if not already done:"
Write-Host "  Copy-Item allfontsgen\output\windows-x86_64\fonts\AllFonts.js x2t\sdkjs\common\AllFonts.js"
