# Setup — Mise en place sur un nouveau poste

## Ce qui est deja dans le repo

Apres un `git clone`, le bundle contient deja:

- `x2t/build/` — scripts de sync
- `x2t/test/` — configs de test

Ce qui manque et doit etre genere:

- `x2t/bin/macos-arm64/` — binaire x2t + frameworks (depuis une release officielle ONLYOFFICE)
- `x2t/sdkjs/` — runtime JS minimal (depuis la meme release)
- `allfontsgen/output/` — polices (genere par allfontsgen, compile depuis core-master)

## Source externe a se procurer

Une **release officielle ONLYOFFICE** contenant un dossier `Resources/` avec:
- `Resources/converter/` — binaire `x2t` + `*.framework`
- `Resources/editors/sdkjs/` — sources JS du moteur de rendu
- `Resources/editors/web-apps/vendor/` — dependances JS (xregexp, etc.)

Sur macOS, ce dossier se trouve dans `DesktopEditors.app/Contents/Resources` si
ONLYOFFICE Desktop Editors est installe, ou dans l'archive de release correspondante.

## Ordre de mise en place

### 1. Synchroniser x2t depuis la release

```sh
zsh x2t/build/scripts/sync_from_release.sh --dry-run /chemin/vers/Resources   # verifier
zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources
```

Produit:
- `x2t/bin/macos-arm64/` (~112 Mo — binaire, frameworks, DoctRenderer.config)
- `x2t/sdkjs/` (~42 Mo — JS minimal necessaire a la conversion)

### 2. Compiler allfontsgen et generer les polices

```sh
cd allfontsgen
zsh build/scripts/build_macos.sh      # compile allfontsgen depuis core-master (necessite clang)
zsh build/scripts/generate_macos.sh   # genere AllFonts.js depuis les polices systeme
```

Produit: `allfontsgen/output/macos-arm64/fonts/AllFonts.js`

Voir [allfontsgen/README.md](../../allfontsgen/README.md) pour le detail de ce bundle
(il compile toujours depuis `core-master/`, contrairement a x2t).

### 3. Copier AllFonts.js dans x2t/sdkjs

```sh
cp allfontsgen/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
```

`sync_from_release.sh` preserve ce fichier lors des synchros suivantes s'il est deja present.

### 4. Tester

```sh
x2t/bin/macos-arm64/x2t "$(pwd)/x2t/test/config_mac.xml"
```

Produit: `x2t/test/*.pdf`

## Prerequis systeme (macOS arm64)

- Xcode Command Line Tools (`xcode-select --install`) — pour compiler allfontsgen
- `clang`, `clang++`, `zsh` (inclus dans CLT)
- Une release officielle ONLYOFFICE (pour x2t) — aucune compilation Qt necessaire

## Windows

Voir [MAINTENANCE.md](MAINTENANCE.md) : `sync_from_install_windows.ps1` peuple `x2t/bin/windows-x86_64/`
et `x2t/sdkjs/` depuis une installation locale ONLYOFFICE Desktop Editors.

## Linux

Meme demarche que macOS, depuis le paquet .deb officiel (pas besoin de l'installer —
le script sait l'extraire avec `dpkg-deb`) :

```sh
# .deb officiel, version alignee sur le bundle (ici 9.4.0) :
# https://download.onlyoffice.com/repo/debian/pool/main/o/onlyoffice-desktopeditors/
bash x2t/build/scripts/sync_from_release_linux.sh --dry-run /chemin/vers/onlyoffice-desktopeditors_9.4.0_amd64.deb
bash x2t/build/scripts/sync_from_release_linux.sh /chemin/vers/onlyoffice-desktopeditors_9.4.0_amd64.deb
```

Produit :
- `x2t/bin/linux-x86_64/` (~162 Mo — binaire x2t, .so, icudtl*.dat, DoctRenderer.config)
- `x2t/sdkjs/` (~51 Mo — identique aux autres plateformes a version egale)

Accepte aussi un dossier deja installe/extrait (`/opt/onlyoffice/desktopeditors`).

Puis polices et test :

```sh
cd allfontsgen && bash build/scripts/build_linux.sh && bash build/scripts/generate_linux.sh && cd ..
cp allfontsgen/output/linux-x86_64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
```

Prerequis : `gcc`/`g++`, `bash`, `python3` (packaging), `dpkg-deb` (extraction du .deb).
