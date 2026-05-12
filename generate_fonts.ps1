param(
    [string]$OutputDir = $(Join-Path $PSScriptRoot 'output\fonts')
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $PSScriptRoot 'bin\Release\allfontsgen_modern.exe'
if (!(Test-Path $exe)) {
    throw "Executable not found: $exe"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$args = @(
    '--use-system=true',
    '--use-system-user-fonts=true',
    "--selection=$OutputDir\font_selection.bin",
    "--allfonts=$OutputDir\AllFonts.js",
    "--allfonts-web=$OutputDir\AllFonts2.js",
    "--output-web=$OutputDir"
)

& $exe @args

Write-Host "Generated in: $OutputDir"
