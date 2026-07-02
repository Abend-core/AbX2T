#Requires -Version 5.1
<#
.SYNOPSIS
Synchronise le bundle x2t depuis une installation ONLYOFFICE Desktop Editors locale (Windows).

.DESCRIPTION
Equivalent Windows de build/scripts/sync_from_release.sh (macOS) : peuple x2t/bin/windows-x86_64/
(binaire x2t.exe + DLLs + DoctRenderer.config) et x2t/sdkjs/ (JS minimal necessaire a la
conversion) depuis une installation ONLYOFFICE Desktop Editors deja presente sur le poste.

.PARAMETER InstallDir
Dossier d'installation ONLYOFFICE Desktop Editors. Doit contenir converter/ et editors/.
Defaut : C:\Program Files\ONLYOFFICE\DesktopEditors

.PARAMETER DryRun
Affiche ce qui serait fait sans rien ecrire.

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
    Write-Error "x2t.exe introuvable dans $converterDir -- verifie -InstallDir ou installe ONLYOFFICE Desktop Editors"
}
if (-not (Test-Path $editorsDir)) {
    Write-Error "Dossier editors introuvable : $editorsDir"
}

$sdkjsSrc   = Join-Path $editorsDir 'sdkjs'
$vendorSrc  = Join-Path $editorsDir 'web-apps\vendor'

if (-not (Test-Path $sdkjsSrc))  { Write-Error "editors\sdkjs introuvable : $sdkjsSrc" }
if (-not (Test-Path $vendorSrc)) { Write-Error "editors\web-apps\vendor introuvable : $vendorSrc" }

$binDest   = Join-Path $bundleRoot 'bin\windows-x86_64'
$sdkjsDest = Join-Path $bundleRoot 'sdkjs'

Write-Host "Converter   : $converterDir"
Write-Host "Editors     : $editorsDir"
Write-Host "Destination bin   : $binDest"
Write-Host "Destination sdkjs : $sdkjsDest"

# Fichiers JS necessaires pour la conversion (memes que sync_from_release.sh sur macOS)
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
    Write-Error "Fichiers manquants dans l'installation :`n$($missing -join "`n")"
}

$dlls = @(Get-ChildItem $converterDir -Filter '*.dll' -ErrorAction SilentlyContinue)

if ($DryRun) {
    Write-Host ""
    Write-Host "[dry-run] --- bin\windows-x86_64\ ---"
    Write-Host "[dry-run] copier x2t.exe"
    foreach ($dll in $dlls) { Write-Host "[dry-run] copier $($dll.Name)" }
    Write-Host "[dry-run] ecrire DoctRenderer.config"
    Write-Host ""
    Write-Host "[dry-run] --- sdkjs\ ---"
    foreach ($f in $sdkjsFiles) { Write-Host "[dry-run] copier $f" }
    Write-Host "[dry-run] copier vendor\xregexp\xregexp-all-min.js"
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
<dictionaries>..\..\dictionaries</dictionaries>
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

    # Preserve AllFonts.js si deja present
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
Write-Host "Prochaine etape -- copier AllFonts.js si pas encore fait :"
Write-Host "  Copy-Item allfontgennew\output\windows-x86_64\fonts\AllFonts.js x2t\sdkjs\common\AllFonts.js"
