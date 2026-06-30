# Setup — Mise en place sur un nouveau poste

## Ce qui est deja dans le repo

Apres un `git clone`, le bundle contient deja:

- `x2t/dictionaries/` — fr_FR, en_US, en_GB
- `x2t/build/` — scripts de build et de sync
- `x2t/test/` — configs de test

Ce qui manque et doit etre genere:

- `x2t/src/` — sources C++ (depuis core-master)
- `x2t/sdkjs/` — runtime JS (depuis sdkjs-master)
- `allfontgennew/output/` — polices (genere par allfontsgen)
- `output/` — runtime assemble (genere par prepare_runtime_macos.sh)

## Sources externes a deposer a la racine du workspace

```
workspace/
├── core-master/        ← git clone https://github.com/ONLYOFFICE/core
├── sdkjs-master/       ← git clone https://github.com/ONLYOFFICE/sdkjs
```

Ces dossiers sont gitignores. Ils servent uniquement a alimenter les scripts de sync.
Ils peuvent etre supprimes apres synchro si l'espace disque est contraint.

## Ordre de mise en place

### 1. Synchroniser les sources C++

```sh
zsh x2t/build/scripts/sync_sources.sh --dry-run   # verifier
zsh x2t/build/scripts/sync_sources.sh
```

Produit: `x2t/src/` (~200 Mo avec liens symboliques vers core-master)

### 2. Synchroniser le runtime JS

```sh
zsh x2t/build/scripts/sync_sdkjs.sh --dry-run     # verifier
zsh x2t/build/scripts/sync_sdkjs.sh
```

Produit: `x2t/sdkjs/` (~100 Mo, fichiers navigateur exclus)

### 3. Generer les polices (depuis allfontgennew)

```sh
cd allfontgennew
zsh build/scripts/build_macos.sh      # compile allfontsgen (necessite clang)
zsh build/scripts/generate_macos.sh   # genere AllFonts.js
```

Produit: `allfontgennew/output/macos-arm64/fonts/AllFonts.js`

### 4. Assembler le runtime

```sh
zsh x2t/build/scripts/prepare_runtime_macos.sh
```

Produit: `output/macos-arm64/runtime/` avec sdkjs, dictionaries, cmap.bin, fonts

### 5. Compiler x2t (optionnel — necessite Qt/qmake)

```sh
zsh x2t/build/scripts/build_macos.sh --dry-run
zsh x2t/build/scripts/build_macos.sh
```

Produit: `output/macos-arm64/bin/x2t`

Si tu utilises un binaire x2t pre-compile, saute cette etape.

### 6. Tester

```sh
/chemin/vers/x2t "$(pwd)/x2t/test/config_mac.xml"
```

Produit: `x2t/test/*.pdf`

## Prerequis systeme (macOS arm64)

- Xcode Command Line Tools (`xcode-select --install`)
- `clang`, `clang++`, `zsh` (inclus dans CLT)
- Qt5 ou Qt6 avec `qmake` (pour compiler x2t seulement)
