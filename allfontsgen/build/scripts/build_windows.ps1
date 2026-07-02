# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Compiles allfontsgen from a vendored subset of ONLYOFFICE/core source (Copyright (C)
# Ascensio System SIA, AGPLv3, see allfontsgen/src/). This script applies a build-time patch
# to one source file (ApplicationFontsWorker.cpp, disables thumbnail generation) before
# compiling; the vendored copy under allfontsgen/src/ is left untouched. See
# /THIRD-PARTY-NOTICES.md.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$repo           = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$obj_dir        = Join-Path $repo 'build\out\windows-x86_64\obj'
$bin_dir        = Join-Path $repo 'build\bin\windows-x86_64'
$binary         = Join-Path $bin_dir 'allfontsgen.exe'
$generated_root = Join-Path $repo 'build\generated'

# --- locate MSVC via vswhere ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere not found -- install Visual Studio with C++ workload"
}
$vs_path = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs_path) {
    Write-Error "No Visual Studio installation with C++ tools found"
}
$vcvars = Join-Path $vs_path 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) {
    Write-Error "vcvars64.bat not found at: $vcvars"
}

# import MSVC environment into current process
$env_dump = cmd /c "`"$vcvars`" && set"
foreach ($line in $env_dump) {
    if ($line -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

# --- patch ApplicationFontsWorker.cpp (disable thumbnail deps) ---
$src_worker = Join-Path $repo 'src\DesktopEditor\fontengine\ApplicationFontsWorker.cpp'
$gen_worker = Join-Path $generated_root 'src\DesktopEditor\fontengine\ApplicationFontsWorker.cpp'
New-Item -ItemType Directory -Force -Path (Split-Path $gen_worker) | Out-Null

$content = [System.IO.File]::ReadAllText($src_worker, [System.Text.Encoding]::UTF8)
$T  = [char]9
$NL = "`r`n"

$old_inc = '#include "../graphics/pro/Fonts.h"' + $NL +
           '#include "../raster/BgraFrame.h"' + $NL +
           '#include "../graphics/pro/Graphics.h"'
$new_inc = '#include "../graphics/pro/Fonts.h"' + $NL +
           '#ifndef ALLFONTSGEN_DISABLE_THUMBNAILS' + $NL +
           '#include "../raster/BgraFrame.h"' + $NL +
           '#include "../graphics/pro/Graphics.h"' + $NL +
           '#endif'
$content = $content.Replace($old_inc, $new_inc)

$old_entry = $T + 'void SaveThumbnails(NSFonts::IApplicationFonts* applicationFonts)' + $NL +
             $T + '{' + $NL +
             $T + $T + 'std::vector<std::wstring> arrFiles;'
$new_entry = $T + 'void SaveThumbnails(NSFonts::IApplicationFonts* applicationFonts)' + $NL +
             $T + '{' + $NL +
             '#ifdef ALLFONTSGEN_DISABLE_THUMBNAILS' + $NL +
             $T + $T + '(void)applicationFonts;' + $NL +
             $T + $T + 'return;' + $NL +
             '#else' + $NL +
             $T + $T + 'std::vector<std::wstring> arrFiles;'
$content = $content.Replace($old_entry, $new_entry)

$old_exit = $T + $T + 'if (applicationFonts == NULL)' + $NL +
            $T + $T + $T + 'RELEASEOBJECT(applicationFontsGood);' + $NL +
            $T + '}' + $NL + '};'
$new_exit = $T + $T + 'if (applicationFonts == NULL)' + $NL +
            $T + $T + $T + 'RELEASEOBJECT(applicationFontsGood);' + $NL +
            '#endif' + $NL +
            $T + '}' + $NL + '};'
$content = $content.Replace($old_exit, $new_exit)

[System.IO.File]::WriteAllText($gen_worker, $content, [System.Text.Encoding]::UTF8)

# --- read manifests ---
function Read-Lines([string]$path) {
    Get-Content $path | Where-Object { $_ -match '\S' }
}

$common_sources   = @(Read-Lines (Join-Path $repo 'build\config\common_sources.txt'))
$platform_sources = @(Read-Lines (Join-Path $repo 'build\config\windows_x86_64_sources.txt'))
$include_dirs     = @(Read-Lines (Join-Path $repo 'build\config\common_include_dirs.txt'))
$common_defines   = @(Read-Lines (Join-Path $repo 'build\config\common_defines.txt'))
$platform_defines = @(Read-Lines (Join-Path $repo 'build\config\windows_x86_64_defines.txt'))
$libraries        = @(Read-Lines (Join-Path $repo 'build\config\windows_x86_64_libraries.txt'))

# --- build arg arrays ---
$define_args  = @($common_defines + $platform_defines | ForEach-Object { "/D$_" })
$include_args = @($include_dirs | ForEach-Object { "/I$repo\$($_ -replace '/','\')" })
$include_args += "/I$repo\build\shims"

$cl_common = @(
    '/nologo', '/c', '/std:c++17', '/O2', '/EHsc', '/W0',
    "/FI$repo\build\shims\posix_compat.h"
) + $define_args + $include_args

# --- prepare output dirs ---
New-Item -ItemType Directory -Force -Path $obj_dir | Out-Null
New-Item -ItemType Directory -Force -Path $bin_dir | Out-Null
Remove-Item (Join-Path $obj_dir '*.obj') -Force -ErrorAction SilentlyContinue
Remove-Item $binary -Force -ErrorAction SilentlyContinue

# --- compile ---
$all_sources = $common_sources + $platform_sources
$obj_paths   = [System.Collections.ArrayList]::new()
$n_failed    = 0

foreach ($source in $all_sources) {
    $abs = Join-Path $repo ($source -replace '/', '\')
    $gen = Join-Path $generated_root ($source -replace '/', '\')
    if (Test-Path $gen) { $abs = $gen }

    $obj_name = (($source -replace '[/\\]', '__') -replace '\.', '_') + '.obj'
    $obj_path = Join-Path $obj_dir $obj_name

    Write-Host "  CC  $source"
    $lang = if (([System.IO.Path]::GetExtension($source).ToLower()) -eq '.c') { '/TC' } else { '/TP' }

    & cl.exe @cl_common $lang "/Fo$obj_path" $abs 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "FAILED: $source"
        $n_failed++
    } else {
        [void]$obj_paths.Add($obj_path)
    }
}

if ($n_failed -gt 0) {
    Write-Error "$n_failed source(s) failed -- aborting link"
}

# --- link ---
Write-Host "  LINK $binary"
$obj_arr = @(Get-ChildItem $obj_dir -Filter '*.obj' | Select-Object -ExpandProperty FullName)
& link.exe /nologo "/OUT:$binary" /SUBSYSTEM:CONSOLE @obj_arr @libraries
if ($LASTEXITCODE -ne 0) {
    Write-Error "Link failed"
}

Write-Host "`nOK: $binary"
