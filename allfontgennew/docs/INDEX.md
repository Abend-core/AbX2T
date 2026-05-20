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
- The current validated platform is macOS arm64.
- The current validated output directory is `output/macos-arm64/fonts`.
- The current validated x2t test config is `test/config_mac.xml`.

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
- `build/scripts/build_macos.sh`: validated macOS arm64 build command.
- `build/scripts/generate_macos.sh`: validated AllFonts generation command.
- `build/scripts/prepare_generated_sources.sh`: generated overlay step that disables thumbnail-only dependencies outside `src/`.
- `build/shims/posix_compat.h`: POSIX header shim injected by the build.
- `build/shims/freetype_ftoption.h`: FreeType override that disables zlib for this bundle.
- `build/config/common_sources.txt`: common compilation units.
- `build/config/common_include_dirs.txt`: include roots.
- `build/config/common_defines.txt`: shared compile defines.
- `build/config/macos_arm64_sources.txt`: macOS-only sources.
- `build/config/macos_arm64_defines.txt`: macOS-only defines.
- `build/config/macos_arm64_frameworks.txt`: macOS frameworks.
- `test/config_mac.xml`: validated x2t test config for macOS.

## Validated Runtime Paths

- Binary: `build/bin/macos-arm64/allfontsgen`
- Generated fonts: `output/macos-arm64/fonts`
- x2t test input: `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.docx`
- x2t test output: `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.pdf`

## Read Next

- [USAGE.md](USAGE.md)
- [MAINTENANCE.md](MAINTENANCE.md)