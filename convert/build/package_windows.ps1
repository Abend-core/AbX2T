#Requires -Version 5.1
<#
.SYNOPSIS
Assemble convert/convert/assets.zip (ressource embarquee dans Abx2t.exe).

.DESCRIPTION
Rassemble x2t.exe + toutes les DLL (x2t.exe les importe statiquement au demarrage, impossible
d'en retirer une seule sans recompiler) + x2t/sdkjs/ complet (common, word, cell, slide, visio,
pdf, vendor) + x2t/dictionaries/ (depuis x2t/bin/windows-x86_64/ et x2t/sdkjs/, peuples par
x2t/build/scripts/sync_from_install_windows.ps1) et allfontsgen.exe (depuis
allfontgennew/build/bin/windows-x86_64/, compile par allfontgennew/build/scripts/build_windows.ps1
si absent) dans convert/convert/assets.zip. Ce zip est extrait automatiquement par Abx2t.exe dans
un dossier resources/ au premier lancement (voir convert/convert/Program.cs).

Prerequis : avoir lance x2t/build/scripts/sync_from_install_windows.ps1 au moins une fois.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File convert\build\package_windows.ps1
#>
param()

$ErrorActionPreference = 'Stop'

$convertRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo        = (Resolve-Path (Join-Path $convertRoot '..')).Path

$x2tBin       = Join-Path $repo 'x2t\bin\windows-x86_64'
$sdkjsSrc     = Join-Path $repo 'x2t\sdkjs'
$dictSrc      = Join-Path $repo 'x2t\dictionaries'
$allfontsgen  = Join-Path $repo 'allfontgennew\build\bin\windows-x86_64\allfontsgen.exe'
$assetsZip    = Join-Path $convertRoot 'convert\assets.zip'

if (-not (Test-Path (Join-Path $x2tBin 'x2t.exe'))) {
    Write-Error "x2t.exe introuvable dans $x2tBin -- lance d'abord x2t\build\scripts\sync_from_install_windows.ps1"
}
if (-not (Test-Path $sdkjsSrc)) {
    Write-Error "sdkjs introuvable dans $sdkjsSrc -- lance d'abord x2t\build\scripts\sync_from_install_windows.ps1"
}
if (-not (Test-Path $dictSrc)) {
    Write-Error "dictionaries introuvable dans $dictSrc"
}

if (-not (Test-Path $allfontsgen)) {
    Write-Host "allfontsgen.exe introuvable -- compilation..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $repo 'allfontgennew\build\scripts\build_windows.ps1')
    if (-not (Test-Path $allfontsgen)) {
        Write-Error "Echec compilation allfontsgen.exe"
    }
}

$stage = Join-Path $convertRoot ".package_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $stage | Out-Null

try {
    Copy-Item (Join-Path $x2tBin 'x2t.exe') $stage -Force
    Get-ChildItem $x2tBin -Filter '*.dll' | ForEach-Object { Copy-Item $_.FullName $stage -Force }
    Copy-Item $allfontsgen $stage -Force

    Copy-Item $sdkjsSrc (Join-Path $stage 'sdkjs') -Recurse -Force
    Copy-Item $dictSrc (Join-Path $stage 'dictionaries') -Recurse -Force

    @'
<Settings>
<file>./sdkjs/common/Native/native.js</file>
<file>./sdkjs/common/Native/jquery_native.js</file>
<allfonts>./sdkjs/common/AllFonts.js</allfonts>
<file>./sdkjs/vendor/xregexp/xregexp-all-min.js</file>
<sdkjs>./sdkjs</sdkjs>
<dictionaries>./dictionaries</dictionaries>
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
Write-Host "Prochaine etape : dotnet publish convert\convert\convert.csproj -c Release"
