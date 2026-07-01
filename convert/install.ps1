#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$here = (Resolve-Path $PSScriptRoot).Path
$repo = (Resolve-Path (Join-Path $here '..')).Path

Write-Host "=== Installation convert ==="
Write-Host "Dossier : $here"

if (-not (Test-Path (Join-Path $here 'convert.exe'))) {
    Write-Error "convert.exe introuvable dans $here"
}

$allfontsgen = Join-Path $repo 'allfontgennew\build\bin\windows-x86_64\allfontsgen.exe'

if (-not (Test-Path $allfontsgen)) {
    Write-Host ""
    Write-Host ">>> Compilation allfontsgen.exe (necessite Visual Studio)..."
    $build_script = Join-Path $repo 'allfontgennew\build\scripts\build_windows.ps1'
    if (-not (Test-Path $build_script)) {
        Write-Error "Script de build introuvable : $build_script"
    }
    & powershell -ExecutionPolicy Bypass -File $build_script
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $allfontsgen)) {
        Write-Error "Echec compilation allfontsgen.exe"
    }
    Write-Host ">>> allfontsgen.exe OK"
}

Write-Host ""
Write-Host ">>> Generation des polices systeme..."
$fonts_tmp = Join-Path $here '_fonts_tmp'
New-Item -ItemType Directory -Force -Path $fonts_tmp | Out-Null

& $allfontsgen `
    --use-system=true `
    --use-system-user-fonts=true `
    "--selection=$fonts_tmp\font_selection.bin" `
    "--allfonts=$fonts_tmp\AllFonts.js" `
    "--allfonts-web=$fonts_tmp\AllFonts2.js" `
    "--output-web=$fonts_tmp"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec generation polices (code $LASTEXITCODE)"
}

Copy-Item "$fonts_tmp\AllFonts.js"        (Join-Path $here 'AllFonts.js')        -Force
Copy-Item "$fonts_tmp\font_selection.bin" (Join-Path $here 'font_selection.bin') -Force
Copy-Item "$fonts_tmp\AllFonts.js"        (Join-Path $here 'sdkjs\common\AllFonts.js') -Force
Remove-Item $fonts_tmp -Recurse -Force

Write-Host ""
Write-Host "=== Installation terminee ==="
Write-Host "Usage : .\convert.exe fichier.docx sortie.pdf"