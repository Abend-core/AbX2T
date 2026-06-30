# x2t

Bundle de conversion de documents ONLYOFFICE pour macOS arm64.

## Structure

```
x2t/
├── build/
│   ├── config/           Fichiers de configuration (posix_compat.h, freetype_ftoption.h)
│   ├── project/          Fichier .pro Qt
│   └── scripts/
│       ├── build_macos.sh           Compile x2t (necessite Qt/qmake)
│       ├── prepare_runtime_macos.sh Assemble le runtime JS dans output/
│       ├── sync_sources.sh          Peuple x2t/src/ depuis core-master
│       └── sync_sdkjs.sh            Peuple x2t/sdkjs/ depuis sdkjs-master
├── dictionaries/         fr_FR, en_US, en_GB (commites)
├── docs/
│   ├── SETUP.md          Mise en place sur un nouveau poste
│   ├── USAGE.md          Convertir un document, lancer les scripts
│   └── MAINTENANCE.md    Mise a jour depuis upstream
├── src/                  Sources C++ (gitignore, genere par sync_sources.sh)
├── sdkjs/                Runtime JS (gitignore, genere par sync_sdkjs.sh)
└── test/
    └── config_mac.xml    Config de test pour la conversion docx→pdf
```

## Demarrage rapide

Voir [docs/SETUP.md](docs/SETUP.md) pour la mise en place complete.

En resume:
1. Deposer `core-master/` et `sdkjs-master/` a la racine du workspace
2. `zsh x2t/build/scripts/sync_sources.sh`
3. `zsh x2t/build/scripts/sync_sdkjs.sh`
4. `zsh x2t/build/scripts/prepare_runtime_macos.sh`
5. `zsh x2t/build/scripts/build_macos.sh` (optionnel si binaire disponible)
6. `/chemin/vers/x2t "$(pwd)/x2t/test/config_mac.xml"`
