# Note rapide sur les scripts et les shims

Ce fichier est volontairement pose a la racine pour etre jetable. Il sert juste a rappeler ce que font les scripts de `allfontgennew` et pourquoi les shims existent.

## Idee generale

Le dossier `allfontgennew/src` est traite comme une copie upstream minimale de `core`. L'idee du montage actuel est simple:

- on garde `src/` le plus proche possible de l'upstream
- on met les ajustements locaux dans `build/scripts/`, `build/shims/` et `build/generated/`
- on evite de patcher `src/` a la main a chaque maj

## Les scripts

### `allfontgennew/build/scripts/build_macos.sh`

Ce script compile le binaire `allfontsgen` pour macOS arm64.

En pratique il fait ca:

- calcule les chemins de build (`build/out`, `build/bin`)
- lance d'abord `prepare_generated_sources.sh`
- charge les listes de sources, includes, defines et frameworks depuis `build/config/`
- compile les fichiers un par un avec `clang` ou `clang++`
- injecte `build/shims/posix_compat.h` en include force pendant la compilation
- utilise une version generee d'un fichier source si elle existe dans `build/generated/`
- link le tout pour produire `build/bin/macos-arm64/allfontsgen`

En clair: c'est le script de build principal.

### `allfontgennew/build/scripts/generate_macos.sh`

Ce script execute le binaire `allfontsgen` pour produire le bundle de polices.

Il:

- verifie que le binaire existe
- lance `build_macos.sh` si besoin
- cree le dossier de sortie
- produit `font_selection.bin`, `AllFonts.js`, `AllFonts2.js` et les fichiers web associes

En clair: le build fabrique l'outil, ce script l'utilise pour generer les fichiers finaux.

### `allfontgennew/build/scripts/prepare_generated_sources.sh`

Ce script ne modifie pas `src/` directement. Il prepare un overlay temporaire dans `build/generated/`.

Aujourd'hui il ne touche qu'a un seul fichier:

- copie `src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp`
- vers `build/generated/src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp`

Puis il patch ce fichier copie pour desactiver la partie thumbnails. Le but est d'eviter de trainer des dependances raster/graphics inutiles pour ce bundle, sans salir la copie upstream dans `src/`.

En clair: c'est le script qui fabrique une version locale et jetable d'un fichier source, uniquement pour le build.

## Les shims

Un shim ici = une petite rustine de compilation placee hors de `src/`.

### `allfontgennew/build/shims/posix_compat.h`

Ce shim ajoute des includes POSIX (`unistd.h`, `sys/stat.h`, `sys/time.h`, `utime.h`) quand on compile sur macOS ou Linux.

Pourquoi: certains fichiers upstream supposent que ces declarations sont disponibles. Au lieu d'aller corriger plusieurs fichiers dans `src/`, le build force cet include une seule fois pour toutes les compilations.

En clair: il corrige l'environnement de compilation, pas les sources upstream.

### `allfontgennew/build/shims/freetype_ftoption.h`

Ce shim inclut la config FreeType standard puis retire `FT_CONFIG_OPTION_USE_ZLIB`.

Il est active via la define de build `FT_CONFIG_OPTIONS_H="freetype_ftoption.h"` dans `build/config/common_defines.txt`.

Pourquoi: ca permet de surcharger la config FreeType sans modifier les headers copies dans `src/`.

En clair: c'est une surcharge de config compile-time pour FreeType.

## Regle pratique

Si une maj de `core` casse quelque chose:

- verifier d'abord si `prepare_generated_sources.sh` matche toujours le contenu de `ApplicationFontsWorker.cpp`
- verifier ensuite les shims et les defines dans `build/config/`
- eviter autant que possible de modifier `allfontgennew/src` a la main

## Script ajoute pour les maj de `src`

J'ai ajoute a la racine:

- `sync_core_to_allfontgennew.sh`

But:

- tu poses un dossier `core` a la racine du workspace
- tu lances le script
- il remplace proprement les 4 sous-dossiers attendus dans `allfontgennew/src`:
  `Common`, `DesktopEditor`, `OdfFile`, `UnicodeConverter`

Usage typique:

```sh
cd /Users/hlm/Desktop/AbX2T
zsh ./sync_core_to_allfontgennew.sh --dry-run
zsh ./sync_core_to_allfontgennew.sh
```

Le script accepte aussi explicitement un chemin source:

```sh
zsh ./sync_core_to_allfontgennew.sh ./core
zsh ./sync_core_to_allfontgennew.sh ./core-master
```

Par defaut il cherche, dans cet ordre:

1. `./core`
2. `./core-master`
3. `./corps`

Le `--dry-run` est utile pour verifier rapidement que le bon dossier sera utilise avant d'ecraser `allfontgennew/src`.