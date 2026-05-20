# allfontgennew

Standalone AllFonts bundle rebuilt from upstream ONLYOFFICE sources copied from `core-master`.

This bundle is the current reference. `oldmodifysources` is no longer needed.

## Rules

- `src/` contains copied upstream sources only.
- Local build shims, manifests, generated overlays, and scripts live outside `src/`.
- The first validated target is macOS arm64.
- Planned targets are macOS arm64, Linux x86_64, and Windows x86_64.

## Quick Start

Build the macOS binary:

```sh
cd /Users/hlm/Desktop/AbX2T/allfontgennew
zsh build/scripts/build_macos.sh
```

Generate the AllFonts bundle:

```sh
cd /Users/hlm/Desktop/AbX2T/allfontgennew
zsh build/scripts/generate_macos.sh
```

Run the validated x2t conversion test:

```sh
cd /Users/hlm/Downloads/Resources/converter
./x2t "/Users/hlm/Desktop/AbX2T/allfontgennew/test/config_mac.xml"
```

## Documentation Index

- [docs/INDEX.md](docs/INDEX.md): bundle map, important files, invariants, and entrypoints.
- [docs/USAGE.md](docs/USAGE.md): build, generation, and x2t test workflow.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): what was changed around upstream, why, and how to reproduce after an upstream refresh.
