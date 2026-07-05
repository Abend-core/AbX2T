#!/usr/bin/env bash
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Downloads an official ONLYOFFICE Desktop Editors release (Copyright (C) Ascensio
# System SIA, AGPLv3) and syncs its unmodified binaries/JS into this bundle.
# See /THIRD-PARTY-NOTICES.md.
#
# Downloads onlyoffice-desktopeditors_amd64.deb from the GitHub release pinned in
# /VERSIONS (or the latest release with --latest), verifies its SHA-256 against
# VERSIONS when pinned, then chains into x2t/build/scripts/sync_from_release_linux.sh
# -- which remains usable on its own as the manual fallback (point it at any .deb or
# extracted install directory) if these download URLs ever break.
#
# Usage: bash build/fetch_onlyoffice_linux.sh [--latest]
#
# Downloads are cached in build/cache/ (gitignored); delete a file there to force
# a re-download.

set -euo pipefail

repo=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

latest=0
while (( $# > 0 )); do
  case "$1" in
    --latest) latest=1 ;;
    -h|--help)
      sed -n '4,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if (( latest )); then
  version=$(curl -fsSL https://api.github.com/repos/ONLYOFFICE/DesktopEditors/releases/latest \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')
  sha_expected=""   # no pinned hash for a moving target
  echo "Latest ONLYOFFICE release: $version"
else
  version=$(grep '^ONLYOFFICE_VERSION=' "$repo/VERSIONS" | cut -d= -f2)
  sha_expected=$(grep '^SHA256_LINUX_DEB=' "$repo/VERSIONS" | cut -d= -f2)
  [[ -n "$version" ]] || { echo "ONLYOFFICE_VERSION missing from $repo/VERSIONS" >&2; exit 1; }
  echo "Pinned ONLYOFFICE release: $version (VERSIONS)"
fi

asset="onlyoffice-desktopeditors_amd64.deb"
url="https://github.com/ONLYOFFICE/DesktopEditors/releases/download/v${version}/${asset}"
cache="$repo/build/cache"
deb="$cache/onlyoffice-desktopeditors_${version}_amd64.deb"
mkdir -p "$cache"

if [[ -f "$deb" ]]; then
  echo "Using cached $deb"
else
  echo "Downloading $url"
  curl -fL --progress-bar -o "$deb.part" "$url"
  mv "$deb.part" "$deb"
fi

sha=$(sha256sum "$deb" | cut -d' ' -f1)
if [[ -n "$sha_expected" ]]; then
  [[ "$sha" == "$sha_expected" ]] || {
    echo "SHA-256 mismatch for $asset:" >&2
    echo "  expected (VERSIONS) : $sha_expected" >&2
    echo "  downloaded          : $sha" >&2
    exit 1
  }
  echo "SHA-256 OK"
else
  echo "SHA-256 of the download (record it as SHA256_LINUX_DEB in VERSIONS to pin it):"
  echo "  $sha"
fi

bash "$repo/x2t/build/scripts/sync_from_release_linux.sh" "$deb"
