# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Runs allfontsgen (built from ONLYOFFICE/core source, AGPLv3). See /THIRD-PARTY-NOTICES.md.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo       = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$binary     = Join-Path $repo 'build\bin\windows-x86_64\allfontsgen.exe'
$output_dir = if ($args[0]) { $args[0] } else { Join-Path $repo 'output\windows-x86_64\fonts' }

if (-not (Test-Path $binary)) {
    Write-Host "Binary not found - building first..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_windows.ps1')
}

New-Item -ItemType Directory -Force -Path $output_dir | Out-Null

& $binary `
    --use-system=true `
    --use-system-user-fonts=true `
    "--selection=$output_dir\font_selection.bin" `
    "--allfonts=$output_dir\AllFonts.js" `
    "--allfonts-web=$output_dir\AllFonts2.js" `
    "--output-web=$output_dir"

if ($LASTEXITCODE -ne 0) {
    Write-Error "allfontsgen failed (exit $LASTEXITCODE)"
}

Write-Host "Generated in: $output_dir"
