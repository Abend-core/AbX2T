# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Downloads an official ONLYOFFICE Desktop Editors release (Copyright (C) Ascensio
# System SIA, AGPLv3) and syncs its unmodified binaries/JS into this bundle.
# See /THIRD-PARTY-NOTICES.md.
#Requires -Version 5.1
<#
.SYNOPSIS
Downloads the official ONLYOFFICE release and syncs x2t/bin + x2t/sdkjs from it.

.DESCRIPTION
Downloads DesktopEditors_x64.zip (portable build, no installation required) from the
GitHub release pinned in /VERSIONS (or the latest release with -Latest), verifies its
SHA-256 against VERSIONS when pinned, extracts it to a temp directory, then chains
into x2t/build/scripts/sync_from_install_windows.ps1 -- which remains usable on its
own as the manual fallback (point -InstallDir at a local ONLYOFFICE installation)
if these download URLs ever break.

Downloads are cached in build/cache/ (gitignored); delete a file there to force
a re-download.

.PARAMETER Latest
Fetch the latest ONLYOFFICE release instead of the version pinned in VERSIONS
(skips the SHA-256 check: no pinned hash for a moving target).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File build\fetch_onlyoffice_windows.ps1
powershell -ExecutionPolicy Bypass -File build\fetch_onlyoffice_windows.ps1 -Latest
#>
param(
    [switch]$Latest
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Get-VersionsValue([string]$Key) {
    $line = Get-Content (Join-Path $repo 'VERSIONS') | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
    if ($null -eq $line) { return '' }
    return ($line -split '=', 2)[1].Trim()
}

if ($Latest) {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ONLYOFFICE/DesktopEditors/releases/latest'
    $version = $release.tag_name.TrimStart('v')
    $shaExpected = ''   # no pinned hash for a moving target
    Write-Host "Latest ONLYOFFICE release: $version"
} else {
    $version = Get-VersionsValue 'ONLYOFFICE_VERSION'
    $shaExpected = Get-VersionsValue 'SHA256_WINDOWS_ZIP'
    if (-not $version) { Write-Error 'ONLYOFFICE_VERSION missing from VERSIONS' }
    Write-Host "Pinned ONLYOFFICE release: $version (VERSIONS)"
}

$asset = 'DesktopEditors_x64.zip'
$url   = "https://github.com/ONLYOFFICE/DesktopEditors/releases/download/v$version/$asset"
$cache = Join-Path $repo 'build\cache'
$zip   = Join-Path $cache "DesktopEditors_x64-$version.zip"
New-Item -ItemType Directory -Force -Path $cache | Out-Null

if (Test-Path $zip) {
    Write-Host "Using cached $zip"
} else {
    Write-Host "Downloading $url"
    # curl.exe (bundled with Windows 10+) streams large files much faster than
    # Invoke-WebRequest; fall back to IWR if unavailable.
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -fL --progress-bar -o "$zip.part" $url
        if ($LASTEXITCODE -ne 0) { Write-Error "Download failed: $url" }
    } else {
        Invoke-WebRequest -Uri $url -OutFile "$zip.part" -UseBasicParsing
    }
    Move-Item "$zip.part" $zip
}

$sha = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($shaExpected) {
    if ($sha -ne $shaExpected.ToLowerInvariant()) {
        Write-Error "SHA-256 mismatch for ${asset}:`n  expected (VERSIONS) : $shaExpected`n  downloaded          : $sha"
    }
    Write-Host 'SHA-256 OK'
} else {
    Write-Host 'SHA-256 of the download (record it as SHA256_WINDOWS_ZIP in VERSIONS to pin it):'
    Write-Host "  $sha"
}

$stage = Join-Path $env:TEMP "abx2t_fetch_$([guid]::NewGuid().ToString('N'))"
try {
    Write-Host "Extracting $zip..."
    Expand-Archive -Path $zip -DestinationPath $stage -Force

    # Locate the install layout inside the archive (a directory holding converter\x2t.exe),
    # so this survives layout changes between ONLYOFFICE versions.
    $x2t = Get-ChildItem $stage -Recurse -Filter 'x2t.exe' |
        Where-Object { $_.Directory.Name -eq 'converter' } | Select-Object -First 1
    if ($null -eq $x2t) { Write-Error "converter\x2t.exe not found inside $asset" }
    $installDir = $x2t.Directory.Parent.FullName

    & powershell -ExecutionPolicy Bypass -File (Join-Path $repo 'x2t\build\scripts\sync_from_install_windows.ps1') -InstallDir $installDir
    if ($LASTEXITCODE -ne 0) { Write-Error 'sync_from_install_windows.ps1 failed' }
}
finally {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}
