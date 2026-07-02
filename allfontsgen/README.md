# allfontsgen

Standalone AllFonts bundle rebuilt from upstream ONLYOFFICE sources copied from `core-master`.

## Rules

- `src/` contains copied upstream sources only.
- Local build shims, manifests, generated overlays, and scripts live outside `src/`.
- Validated targets: macOS arm64, Windows x86_64, Linux x86_64 (build + font generation only,
  no x2t binary available on Linux for a conversion test).

## Quick Start

Build the macOS binary (from the repository root):

```sh
cd allfontsgen
zsh build/scripts/build_macos.sh
```

Generate the AllFonts bundle:

```sh
cd allfontsgen
zsh build/scripts/generate_macos.sh
```

Run the x2t conversion test (from the `converter/` directory of an ONLYOFFICE release; adjust
the absolute paths inside `test/config_mac.xml` to your machine first):

```sh
cd /path/to/onlyoffice/Resources/converter
./x2t "/path/to/AbX2T/allfontsgen/test/config_mac.xml"
```

On Linux (tested via WSL Ubuntu):

```sh
cd allfontsgen
bash build/scripts/build_linux.sh
bash build/scripts/generate_linux.sh
```

## Documentation Index

- [docs/INDEX.md](docs/INDEX.md): bundle map, important files, invariants, and entrypoints.
- [docs/USAGE.md](docs/USAGE.md): build, generation, and x2t test workflow.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): what was changed around upstream, why, and how to reproduce after an upstream refresh.
