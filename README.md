# AbX2T Workspace

Toolkit de conversion et de generation de polices ONLYOFFICE, adapte macOS arm64.

## Bundles

```
workspace/
├── x2t/              Convertisseur de documents (docx/xlsx/pptx → pdf, etc.) — depuis release officielle
├── allfontgennew/    Generateur d'index de polices AllFonts.js — compile depuis core-master
└── core-master/      Sources upstream ONLYOFFICE core (gitignore, requis pour allfontgennew)
```

x2t n'est plus compile depuis les sources : le binaire et son runtime JS sont recuperes
directement depuis une release officielle ONLYOFFICE (`x2t/build/scripts/sync_from_release.sh`).
Seul allfontgennew (generateur de `AllFonts.js`) est encore compile localement depuis `core-master/`.

## Demarrage

Voir **[x2t/docs/SETUP.md](x2t/docs/SETUP.md)** pour la mise en place complete.

Ordre des etapes:
1. Se procurer une release officielle ONLYOFFICE (dossier `Resources/` avec `converter/` + `editors/`)
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Deposer `core-master/` a la racine, compiler allfontsgen: `cd allfontgennew && zsh build/scripts/build_macos.sh`
4. Generer les polices: `zsh build/scripts/generate_macos.sh`
5. `cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
6. Tester: `x2t/bin/x2t "$(pwd)/x2t/test/config_mac.xml"`

## Documentation

- [x2t/docs/SETUP.md](x2t/docs/SETUP.md)
- [x2t/docs/USAGE.md](x2t/docs/USAGE.md)
- [x2t/docs/MAINTENANCE.md](x2t/docs/MAINTENANCE.md)
- [allfontgennew/README.md](allfontgennew/README.md)
