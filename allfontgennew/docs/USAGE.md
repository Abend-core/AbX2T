# Usage

## Prerequisites

For the validated macOS workflow:

- macOS arm64
- Xcode Command Line Tools
- `clang`, `clang++`, `xcrun`, `zsh`
- an `x2t` binary available separately, outside this repository

This repository does not bundle `x2t`. The intended future layout is:

- repository root: may later host an external `x2t` bundle
- `allfontgennew/`: contains only AllFonts generation assets

## Build the macOS Binary

```sh
cd /Users/hlm/Desktop/AbX2T/allfontgennew
zsh build/scripts/build_macos.sh
```

Expected output:

- `build/bin/macos-arm64/allfontsgen`

## Generate the AllFonts Bundle

```sh
cd /Users/hlm/Desktop/AbX2T/allfontgennew
zsh build/scripts/generate_macos.sh
```

Expected output directory:

- `output/macos-arm64/fonts`

Expected files:

- `output/macos-arm64/fonts/AllFonts.js`
- `output/macos-arm64/fonts/AllFonts2.js`
- `output/macos-arm64/fonts/font_selection.bin`
- `output/macos-arm64/fonts/fonts.log`

## Run the Validated x2t Conversion Test

Validated config:

- `test/config_mac.xml`

Validated command:

```sh
cd /Users/hlm/Downloads/Resources/converter
./x2t "/Users/hlm/Desktop/AbX2T/allfontgennew/test/config_mac.xml"
```

Expected output:

- `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.pdf`

## If You Need Another Test File

Duplicate `test/config_mac.xml` and change only these fields:

- `m_sFileFrom`
- `m_sFileTo`
- `m_sAllFontsPath`
- `m_sFontDir`

Keep `m_sAllFontsPath` and `m_sFontDir` aligned with the same generated fonts directory.

## Fast Validation Checklist

After any rebuild, validate in this order:

1. `zsh build/scripts/build_macos.sh`
2. `zsh build/scripts/generate_macos.sh`
3. check that `output/macos-arm64/fonts/AllFonts.js` exists
4. run `./x2t "/Users/hlm/Desktop/AbX2T/allfontgennew/test/config_mac.xml"`
5. check that `test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.pdf` exists