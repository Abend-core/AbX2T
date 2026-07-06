# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
#Requires -Version 5.1
<#
.SYNOPSIS
Smoke test: converts build/testdata/sample.docx to PDF and TXT and checks the outputs.

.DESCRIPTION
Windows equivalent of build/smoke_test.sh: real Abx2t run (extraction + font
generation + x2t), end-to-end gate for CI and for validating a machine or a
bundle bump.

.PARAMETER ExePath
Path to a built Abx2t.exe. Without it, runs the project through `dotnet run`
(JIT, no publish needed). With it, the exe is copied to a fresh temp directory,
exercising the first-run extraction as end users see it.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File build\smoke_test.ps1
powershell -ExecutionPolicy Bypass -File build\smoke_test.ps1 -ExePath src\bin\x64\Release\net10.0\win-x64\publish\Abx2t.exe
#>
param(
    [string]$ExePath = ''
)

$ErrorActionPreference = 'Stop'

$repo   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sample = Join-Path $repo 'build\testdata\sample.docx'
$out    = Join-Path $env:TEMP "abx2t_smoke_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Fail([string]$msg) {
    Write-Host "SMOKE TEST FAILED: $msg" -ForegroundColor Red
    Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

if ($ExePath) {
    if (-not (Test-Path $ExePath)) { Fail "executable not found: $ExePath" }
    Copy-Item $ExePath (Join-Path $out 'Abx2t.exe')
    $runner = Join-Path $out 'Abx2t.exe'
    # Out-Host keeps the program output visible without polluting the function's
    # return stream: Run must return ONLY the exit code (a bare `& $runner` would
    # make the function return an array of output lines + code, breaking -ne 0).
    function Run { & $runner @args | Out-Host; return $LASTEXITCODE }
} else {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Fail 'dotnet not found (pass -ExePath instead)' }
    function Run { & dotnet run --project (Join-Path $repo 'src') -c Release -- @args | Out-Host; return $LASTEXITCODE }
}

Write-Host '== --version'
if ((Run --version) -ne 0) { Fail '--version failed' }

Write-Host '== docx -> pdf'
$pdf = Join-Path $out 'sample.pdf'
if ((Run --timeout 10 $sample $pdf) -ne 0) { Fail 'docx->pdf conversion failed' }
if (-not (Test-Path $pdf)) { Fail 'sample.pdf missing' }
$head = [System.Text.Encoding]::ASCII.GetString((Get-Content $pdf -AsByteStream -TotalCount 4))
if ($head -ne '%PDF') { Fail 'sample.pdf does not start with %PDF' }
if ((Get-Item $pdf).Length -le 1000) { Fail 'sample.pdf suspiciously small' }

Write-Host '== docx -> txt'
$txt = Join-Path $out 'sample.txt'
if ((Run --timeout 10 $sample $txt) -ne 0) { Fail 'docx->txt conversion failed' }
if (-not (Select-String -Path $txt -Pattern 'quick brown fox' -Quiet)) { Fail 'converted text does not contain the sample sentence' }

Write-Host '== batch mode'
$batchIn  = Join-Path $out 'batch_in'
$batchOut = Join-Path $out 'batch_out'
New-Item -ItemType Directory -Force -Path $batchIn, $batchOut | Out-Null
Copy-Item $sample (Join-Path $batchIn 'a.docx')
Copy-Item $sample (Join-Path $batchIn 'b.docx')
if ((Run --to pdf --jobs 2 (Join-Path $batchIn 'a.docx') (Join-Path $batchIn 'b.docx') $batchOut) -ne 0) { Fail 'batch conversion failed' }
if (-not ((Test-Path (Join-Path $batchOut 'a.pdf')) -and (Test-Path (Join-Path $batchOut 'b.pdf')))) { Fail 'batch outputs missing' }

Write-Host '== error paths' 
if ((Run $sample $sample 2>$null) -ne 1) { Fail 'source==output should exit 1' }
if ((Run (Join-Path $out 'missing.docx') (Join-Path $out 'x.pdf') 2>$null) -ne 1) { Fail 'missing source should exit 1' }

Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host 'SMOKE TEST OK' -ForegroundColor Green
