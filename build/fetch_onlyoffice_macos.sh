#!/usr/bin/env zsh
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
# Downloads an official ONLYOFFICE Desktop Editors release (Copyright (C) Ascensio
# System SIA, AGPLv3) and syncs its unmodified binaries/JS into this bundle.
# See /THIRD-PARTY-NOTICES.md.
#
# Downloads ONLYOFFICE-arm.dmg from the GitHub release pinned in /VERSIONS (or the
# latest release with --latest), verifies its SHA-256 against VERSIONS when pinned,
# mounts it, then chains into x2t/build/scripts/sync_from_release_macos.sh -- which remains
# usable on its own as the manual fallback (point it at any Resources/ directory)
# if these download URLs ever break.
#
# Usage: zsh build/fetch_onlyoffice_macos.sh [--latest]
#
# Downloads are cached in build/cache/ (gitignored); delete a file there to force
# a re-download.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

repo=$(cd -- "${0:A:h}/.." && pwd)

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
  sha_expected=$(grep '^SHA256_MACOS_DMG=' "$repo/VERSIONS" | cut -d= -f2)
  [[ -n "$version" ]] || { echo "ONLYOFFICE_VERSION missing from $repo/VERSIONS" >&2; exit 1; }
  echo "Pinned ONLYOFFICE release: $version (VERSIONS)"
fi

asset="ONLYOFFICE-arm.dmg"
url="https://github.com/ONLYOFFICE/DesktopEditors/releases/download/v${version}/${asset}"
cache="$repo/build/cache"
dmg="$cache/ONLYOFFICE-arm-${version}.dmg"
mkdir -p "$cache"

if [[ -f "$dmg" ]]; then
  echo "Using cached $dmg"
else
  echo "Downloading $url"
  curl -fL --progress-bar -o "$dmg.part" "$url"
  mv "$dmg.part" "$dmg"
fi

sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
if [[ -n "$sha_expected" ]]; then
  [[ "$sha" == "$sha_expected" ]] || {
    echo "SHA-256 mismatch for $asset:" >&2
    echo "  expected (VERSIONS) : $sha_expected" >&2
    echo "  downloaded          : $sha" >&2
    exit 1
  }
  echo "SHA-256 OK"
else
  echo "SHA-256 of the download (record it as SHA256_MACOS_DMG in VERSIONS to pin it):"
  echo "  $sha"
fi

echo "Mounting $dmg..."
mount_point=$(hdiutil attach -nobrowse -readonly "$dmg" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)
[[ -n "$mount_point" && -d "$mount_point" ]] || { echo "Failed to mount the dmg" >&2; exit 1; }
trap "hdiutil detach '$mount_point' -quiet || true" EXIT

app=("$mount_point"/*.app(N))
(( ${#app[@]} > 0 )) || { echo "No .app found in $mount_point" >&2; exit 1; }
resources="${app[1]}/Contents/Resources"
[[ -f "$resources/converter/x2t" ]] || { echo "converter/x2t not found in $resources" >&2; exit 1; }

zsh "$repo/x2t/build/scripts/sync_from_release_macos.sh" "$resources"
