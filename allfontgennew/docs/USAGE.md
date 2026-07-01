# Usage

## Prerequis

### macOS arm64
- Xcode Command Line Tools
- `clang`, `clang++`, `zsh`
- x2t disponible (via `x2t/build/scripts/sync_from_release.sh`)

### Windows x86_64
- Visual Studio 2019+ avec workload C++
- PowerShell 5.1+
- ONLYOFFICE Desktop Editors installe (pour x2t.exe et ses DLLs)

## Build

### macOS arm64

```sh
cd allfontgennew
zsh build/scripts/build_macos.sh
```

Produit : `build/bin/macos-arm64/allfontsgen`

### Windows x86_64

```powershell
cd allfontgennew
powershell -ExecutionPolicy Bypass -File build\scripts\build_windows.ps1
```

Produit : `build\bin\windows-x86_64\allfontsgen.exe`

## Generer AllFonts.js

### macOS arm64

```sh
zsh build/scripts/generate_macos.sh
```

Produit dans `output/macos-arm64/fonts/` :
- `AllFonts.js`
- `AllFonts2.js`
- `font_selection.bin`
- `fonts.log`

### Windows x86_64

```powershell
powershell -ExecutionPolicy Bypass -File build\scripts\generate_windows.ps1
```

Produit dans `output\windows-x86_64\fonts\`.

## Tester la conversion

### macOS arm64

```sh
x2t/bin/x2t "$(pwd)/allfontgennew/test/config_mac.xml"
```

### Windows x86_64

```powershell
cd x2t\bin\windows-x86_64
.\x2t.exe "D:\abX2T\allfontgennew\test\config_windows.xml"
```

Ou via convert.exe (recommande) :

```powershell
.\convert.exe "rapport.docx" "rapport.pdf"
```

## Validation rapide apres rebuild

1. Verifier que le binaire existe (`build/bin/.../allfontsgen`)
2. Regenerer `AllFonts.js`
3. Lancer la conversion de test
4. Verifier que le PDF est produit