# Usage

## Prerequis

### macOS arm64
- Xcode Command Line Tools
- `clang`, `clang++`, `zsh`
- x2t disponible (via `x2t/build/scripts/sync_from_release_macos.sh`)

### Windows x86_64
- Visual Studio 2019+ avec workload C++
- PowerShell 5.1+
- ONLYOFFICE Desktop Editors installe (pour x2t.exe et ses DLLs)

### Linux x86_64
- `gcc`/`g++`, `bash`, `perl` (teste via WSL Ubuntu)
- Pas de binaire x2t Linux disponible : build + generation uniquement, pas de test de conversion

## Build

### macOS arm64

```sh
cd allfontsgen
zsh build/scripts/build_macos.sh
```

Produit : `build/bin/macos-arm64/allfontsgen`

### Windows x86_64

```powershell
cd allfontsgen
powershell -ExecutionPolicy Bypass -File build\scripts\build_windows.ps1
```

Produit : `build\bin\windows-x86_64\allfontsgen.exe`

### Linux x86_64

```sh
cd allfontsgen
bash build/scripts/build_linux.sh
```

Produit : `build/bin/linux-x86_64/allfontsgen`

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

### Linux x86_64

```sh
bash build/scripts/generate_linux.sh
```

Produit dans `output/linux-x86_64/fonts/`.

## Tester la conversion

### macOS arm64

```sh
x2t/bin/macos-arm64/x2t "$(pwd)/allfontsgen/test/config_mac.xml"
```

### Windows x86_64

```powershell
cd x2t\bin\windows-x86_64
.\x2t.exe "D:\abX2T\allfontsgen\test\config_windows.xml"
```

Ou via Abx2t.exe (recommande) :

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

### Linux x86_64

Pas de binaire x2t Linux disponible dans ce workspace : la generation des polices est validee
(voir ci-dessus), mais la conversion de document ne peut pas etre testee sur Linux.

## Validation rapide apres rebuild

1. Verifier que le binaire existe (`build/bin/.../allfontsgen`)
2. Regenerer `AllFonts.js`
3. Lancer la conversion de test
4. Verifier que le PDF est produit