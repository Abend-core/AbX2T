# allfontgennew Documentation Index

## Goal

`allfontgennew` is a standalone AllFonts generator bundle built from copied upstream ONLYOFFICE sources stored in `core-master`.

The target outcome is reproducible generation of:

- `AllFonts.js`
- `AllFonts2.js`
- `font_selection.bin`
- `fonts.log`

and successful use of those outputs from `x2t`.

## Invariants

- `src/` must stay upstream-only.
- All local adaptations must live under `build/`, `test/`, or documentation files.
- Validated platforms: macOS arm64, Windows x86_64.
- macOS output directory: `output/macos-arm64/fonts`.
- Windows output directory: `output/windows-x86_64/fonts`.

## Directory Map

- `src/`: copied upstream source subset.
- `build/config/`: source lists, include dirs, defines, frameworks, and future platform manifests.
- `build/scripts/`: build and generation entrypoints.
- `build/shims/`: forced include and compile-time overrides used without modifying `src/`.
- `build/generated/`: generated overlay sources used during build only.
- `build/bin/`: produced binaries.
- `build/out/`: object files.
- `build/legacy/`: legacy trial script and outputs kept only for archive/debugging purposes.
- `output/`: generated AllFonts bundles.
- `test/`: x2t conversion test assets and example configs.

## Important Files

- `README.md`: top-level entrypoint.
- `build/scripts/build_macos.sh`: validated macOS arm64 build.
- `build/scripts/generate_macos.sh`: validated AllFonts generation (macOS).
- `build/scripts/build_windows.ps1`: validated Windows x86_64 build (MSVC).
- `build/scripts/generate_windows.ps1`: validated AllFonts generation (Windows).
- `build/scripts/prepare_generated_sources.sh`: overlay step that disables thumbnail deps.
- `build/shims/posix_compat.h`: POSIX shim force-included on all platforms.
- `build/shims/freetype_ftoption.h`: FreeType override (disables zlib) for macOS/Linux.
- `build/shims/allfontsgen_ftoptions.h`: FreeType override (disables zlib) for Windows via FT_CONFIG_OPTIONS_H.
- `build/config/common_sources.txt`: common compilation units.
- `build/config/common_include_dirs.txt`: include roots.
- `build/config/common_defines.txt`: shared compile defines.
- `build/config/windows_x86_64_sources.txt`: Windows-only sources.
- `build/config/windows_x86_64_defines.txt`: Windows-only defines (incl. FT macros).
- `build/config/windows_x86_64_libraries.txt`: Windows link libraries.
- `test/config_mac.xml`: x2t test config for macOS.
- `test/config_windows.xml`: x2t test config for Windows.

## Validated Runtime Paths

### macOS arm64
- Binary: `build/bin/macos-arm64/allfontsgen`
- Generated fonts: `output/macos-arm64/fonts`

### Windows x86_64
- Binary: `build/bin/windows-x86_64/allfontsgen.exe`
- Generated fonts: `output/windows-x86_64/fonts`

### Test assets (all platforms)
- x2t test input: `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.docx`
- x2t test output: `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.pdf`

## Read Next

- [USAGE.md](USAGE.md)
- [MAINTENANCE.md](MAINTENANCE.md)