# x2t

Bundle de conversion de documents ONLYOFFICE pour macOS arm64.

## Structure

```
x2t/
├── bin/                  Binaire x2t + DLLs/frameworks + DoctRenderer.config (commite)
│   └── windows-x86_64/   Sous-dossier Windows (peuple par sync_from_install_windows.ps1)
├── build/
│   └── scripts/
│       ├── sync_from_release.sh          macOS : peuple bin/ et sdkjs/ depuis une release officielle ONLYOFFICE
│       ├── sync_from_install_windows.ps1 Windows : peuple bin/windows-x86_64/ et sdkjs/ depuis une install ONLYOFFICE Desktop locale
│       └── convert.sh                    Point d'entree recommande (macOS) : conversion + nettoyage garanti du temp dir
├── docs/
│   ├── SETUP.md          Mise en place sur un nouveau poste
│   ├── USAGE.md          Convertir un document, lancer les scripts
│   └── MAINTENANCE.md    Mise a jour depuis upstream
├── sdkjs/                Runtime JS complet : common, word, cell, slide, visio, pdf, vendor
│                         (commite, ~50 Mo), embarque integralement par
│                         convert/build/package_windows.ps1 (voir convert/docs/SUPPORTED_FORMATS.md)
└── test/
    └── config_mac.xml    Config de test pour la conversion docx→pdf
```

## Approche

x2t est assemble depuis une **installation ONLYOFFICE pre-compilee** (le binaire x2t et ses
DLLs/frameworks ne sont jamais recompiles ici) : une release officielle sur macOS
(`sync_from_release.sh`), une installation locale ONLYOFFICE Desktop Editors sur Windows
(`sync_from_install_windows.ps1`). Seul `x2t/sdkjs/common/AllFonts.js` est genere localement,
par `allfontsgen` (voir sa doc), a partir des polices installees sur le poste.

## Demarrage rapide

Voir [docs/SETUP.md](docs/SETUP.md) pour la mise en place complete.

En resume:
1. Se procurer une release officielle ONLYOFFICE (ex: DesktopEditors.app) contenant `converter/` et `editors/`
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Generer les polices: `cd allfontsgen && zsh build/scripts/generate_macos.sh`
4. `cp allfontsgen/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
5. `zsh x2t/build/scripts/convert.sh /chemin/document.docx /chemin/sortie.pdf`

Utiliser `convert.sh` plutot que d'appeler `x2t/bin/x2t` directement : x2t laisse par
defaut un dossier temporaire orphelin a cote du fichier de sortie sur macOS/Linux
(bug de nettoyage upstream, voir [docs/USAGE.md](docs/USAGE.md#pourquoi-convertsh-et-pourquoi-m_stempdir-est-obligatoire)),
et `convert.sh` garantit sa suppression.
