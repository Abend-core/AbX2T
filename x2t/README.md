# x2t

Bundle de conversion de documents ONLYOFFICE pour macOS arm64.

## Structure

```
x2t/
├── bin/                  Binaire x2t + frameworks + DoctRenderer.config (gitignore, genere par sync_from_release.sh)
├── build/
│   └── scripts/
│       ├── sync_from_release.sh     Peuple bin/ et sdkjs/ depuis une release officielle ONLYOFFICE
│       ├── convert.sh               Point d'entree recommande : conversion + nettoyage garanti du temp dir
│       ├── sync_sources.sh          Legacy : peuple x2t/src/ depuis core-master (compilation source)
│       ├── sync_sdkjs.sh            Legacy : peuple x2t/sdkjs/ depuis sdkjs-master (compilation source)
│       ├── build_macos.sh           Legacy : compile x2t (necessite Qt/qmake)
│       └── prepare_runtime_macos.sh Legacy : assemble le runtime JS dans output/
├── dictionaries/         fr_FR, en_US, en_GB (commites)
├── docs/
│   ├── SETUP.md          Mise en place sur un nouveau poste
│   ├── USAGE.md          Convertir un document, lancer les scripts
│   └── MAINTENANCE.md    Mise a jour depuis upstream
├── sdkjs/                Runtime JS minimal (gitignore, genere par sync_from_release.sh)
└── test/
    └── config_mac.xml    Config de test pour la conversion docx→pdf
```

## Approche

x2t est assemble depuis une **release officielle ONLYOFFICE pre-compilee** (le binaire x2t et ses
frameworks ne sont jamais recompiles ici). Seul `x2t/sdkjs/common/AllFonts.js` est genere
localement, par `allfontgennew` (voir sa doc), a partir des polices installees sur le poste.

Les scripts `sync_sources.sh` / `sync_sdkjs.sh` / `build_macos.sh` / `prepare_runtime_macos.sh`
restent presents pour une compilation depuis les sources (core-master/sdkjs-master), mais ne
sont pas le chemin utilise actuellement.

## Demarrage rapide

Voir [docs/SETUP.md](docs/SETUP.md) pour la mise en place complete.

En resume:
1. Se procurer une release officielle ONLYOFFICE (ex: DesktopEditors.app) contenant `converter/` et `editors/`
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Generer les polices: `cd allfontgennew && zsh build/scripts/generate_macos.sh`
4. `cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
5. `zsh x2t/build/scripts/convert.sh /chemin/document.docx /chemin/sortie.pdf`

Utiliser `convert.sh` plutot que d'appeler `x2t/bin/x2t` directement : x2t laisse par
defaut un dossier temporaire orphelin a cote du fichier de sortie sur macOS/Linux
(bug de nettoyage upstream, voir [docs/USAGE.md](docs/USAGE.md#pourquoi-convertsh-et-pourquoi-m_stempdir-est-obligatoire)),
et `convert.sh` garantit sa suppression.
