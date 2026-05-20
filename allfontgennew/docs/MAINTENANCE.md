# Maintenance And Upstream Refresh

## Why This Bundle Exists

The goal is to rebuild the smallest practical standalone AllFonts generator from upstream ONLYOFFICE sources while keeping local changes out of `src/`.

The old experimental bundle is no longer the reference. The maintained reference is `allfontgennew`.

## What Was Done

### 1. Upstream Sources Were Copied Into `src/`

The source subtree in `allfontgennew/src` is a copied upstream subset from `core-master`.

### 2. Build Logic Was Moved Outside `src/`

The build is driven by manifests and scripts under `build/`:

- `build/config/`
- `build/scripts/`
- `build/shims/`

### 3. Thumbnail Dependencies Were Disabled Outside `src/`

Upstream `ApplicationFontsWorker.cpp` pulls raster/graphics thumbnail dependencies that are too heavy for the minimal standalone bundle.

To keep `src/` untouched, `build/scripts/prepare_generated_sources.sh` copies:

- `src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp`

into:

- `build/generated/src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp`

and rewrites only the thumbnail-related include and function guards.

This is the key local adaptation.

### 4. POSIX And FreeType Tweaks Were Externalized

Instead of editing upstream sources directly:

- `build/shims/posix_compat.h` injects required POSIX headers at compile time.
- `build/shims/freetype_ftoption.h` disables zlib through `FT_CONFIG_OPTIONS_H`.

## Current Validated Platform State

- macOS arm64: validated
- Linux x86_64: manifests prepared, not yet validated here
- Windows x86_64: manifests prepared, not yet validated here

## Rebuilding After An Upstream Update

Use this checklist.

1. Refresh the copied source subset under `src/` from `core-master`.
2. Do not edit `src/` manually to fix platform issues.
3. If upstream changed `ApplicationFontsWorker.cpp`, inspect whether the thumbnail disable rewrite in `build/scripts/prepare_generated_sources.sh` still matches.
4. Re-run the macOS build.
5. Re-run AllFonts generation.
6. Re-run the x2t conversion test.
7. Update the docs if any path, command, or invariant changed.

## Files To Check First After An Upstream Refresh

- `src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp`
- `src/DesktopEditor/AllFontsGen/main.cpp`
- `build/config/common_sources.txt`
- `build/config/common_include_dirs.txt`
- `build/config/common_defines.txt`
- `build/config/macos_arm64_sources.txt`
- `build/config/macos_arm64_defines.txt`
- `build/config/macos_arm64_frameworks.txt`
- `build/scripts/build_macos.sh`
- `build/scripts/prepare_generated_sources.sh`
- `test/config_mac.xml`

## AI-Friendly Handoff Notes

If an agent or another maintainer resumes work later, these are the critical facts:

- authoritative upstream source root: `../core-master`
- maintained standalone bundle root: `.`
- never patch `src/` for local standalone fixes unless the rule is intentionally changed
- preferred place for local fixes: `build/shims/`, `build/scripts/`, generated overlay under `build/generated/`
- current validated binary path: `build/bin/macos-arm64/allfontsgen`
- current validated generated fonts path: `output/macos-arm64/fonts`
- current validated x2t config: `test/config_mac.xml`
- current validated x2t command: `cd /Users/hlm/Downloads/Resources/converter && ./x2t "/Users/hlm/Desktop/AbX2T/allfontgennew/test/config_mac.xml"`

## Regression Symptoms To Watch

- build fails in `ApplicationFontsWorker.cpp`: upstream thumbnail rewrite no longer matches
- build fails on POSIX symbols: shim/include coverage drifted
- generated fonts exist but x2t crashes: `m_sAllFontsPath` and `m_sFontDir` no longer point to the same generated bundle
- output files missing: generation step was skipped or wrote to a different directory