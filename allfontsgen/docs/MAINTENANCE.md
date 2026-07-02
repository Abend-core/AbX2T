# Maintenance

## Pourquoi ce bundle existe

Reconstruire un generateur AllFonts.js minimal et autonome depuis les sources ONLYOFFICE,
sans modifier `src/`, et valide sur macOS arm64, Windows x86_64 et Linux x86_64.

## Ce qui a ete fait

### 1. Sources copiees dans src/

`allfontsgen/src/` contient un sous-ensemble copie depuis `core-master/` :
- `Common/`, `DesktopEditor/`, `OdfFile/`, `UnicodeConverter/`

### 2. Build pilote par des manifests hors src/

- `build/config/` : listes de sources, includes, defines, libraries par plateforme
- `build/scripts/` : scripts de build et de generation
- `build/shims/` : overrides injectes sans toucher src/

### 3. Dependances thumbnail desactivees hors src/

`build/scripts/build_windows.ps1` (et `prepare_generated_sources.sh`, partage par macOS et
Linux) patche `ApplicationFontsWorker.cpp` a la volee dans `build/generated/` pour desactiver
les includes raster/graphics non necessaires.

### 4. Shims par plateforme

- `build/shims/posix_compat.h` : headers POSIX (force-include sur toutes les plateformes)
- `build/shims/freetype_ftoption.h` : desactive zlib FreeType (macOS/Linux)
- `build/shims/allfontsgen_ftoptions.h` : desactive zlib FreeType (Windows, via FT_CONFIG_OPTIONS_H)

## Plateformes validees

| Plateforme | Build | Generation | Test conversion |
|---|---|---|---|
| macOS arm64 | OK | OK | OK |
| Windows x86_64 | OK | OK | OK |
| Linux x86_64 | OK (teste via WSL Ubuntu) | OK | Non applicable (pas de binaire x2t Linux) |

## Dependance a core-master

`allfontsgen/src/` est une copie statique de core-master. Elle ne se met pas a jour
automatiquement. Pour rafraichir depuis upstream :

```sh
zsh allfontsgen/build/scripts/sync_core.sh
```

Puis recompiler et retester sur toutes les plateformes.

## Rebuilder apres une maj upstream

1. Rafraichir `src/` via `sync_core.sh`
2. Verifier que le patch `ApplicationFontsWorker.cpp` correspond encore
3. Recompiler sur macOS (`build_macos.sh`), Windows (`build_windows.ps1`) et Linux (`build_linux.sh`)
4. Regenerer AllFonts.js sur les trois plateformes
5. Relancer les tests de conversion (macOS/Windows uniquement, pas de x2t Linux)
6. Mettre a jour les docs si besoin

## Fichiers a verifier en premier apres une maj

- `src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp` (patch thumbnail)
- `src/DesktopEditor/AllFontsGen/main.cpp`
- `build/config/common_sources.txt`
- `build/config/common_defines.txt`
- `build/config/windows_x86_64_defines.txt`

## Symptomes de regression

- Build echoue sur `ApplicationFontsWorker.cpp` : le patch thumbnail ne correspond plus
- Build echoue avec erreurs FreeType : verifier les shims et defines FT_CONFIG_OPTIONS_H
- AllFonts.js genere mais x2t crashe : verifier DoctRenderer.config et chemins sdkjs
- PDF absent apres conversion : verifier m_sAllFontsPath et m_sFontDir dans le XML de config

## Notes pour un prochain mainteneur

- Ne jamais patcher `src/` directement
- Les fixes locaux vont dans `build/shims/`, `build/scripts/`, ou `build/generated/`
- `build/generated/` est dans .gitignore (produit a la compilation, pas commite)
- Windows : le define `FT_CONFIG_OPTIONS_H=<allfontsgen_ftoptions.h>` est la cle pour
  overrider les options FreeType sans toucher src/
- `ftgzip.c` est compile sur Windows avec zlib desactive (stubs internes) via ce shim