# AbX2T Workspace

Toolkit de conversion et de generation de polices ONLYOFFICE, adapte macOS arm64.

## Bundles

```
workspace/
├── x2t/              Convertisseur de documents (docx/xlsx/pptx → pdf, etc.)
├── allfontgennew/    Generateur d'index de polices AllFonts.js
├── output/           Runtime assemble (gitignore, genere localement)
├── core-master/      Sources upstream ONLYOFFICE core (gitignore, optionnel)
└── sdkjs-master/     Sources upstream ONLYOFFICE sdkjs (gitignore, optionnel)
```

## Demarrage

Voir **[x2t/docs/SETUP.md](x2t/docs/SETUP.md)** pour la mise en place complete.

Ordre des etapes:
1. Cloner/deposer `core-master/` et `sdkjs-master/` a la racine
2. `zsh x2t/build/scripts/sync_sources.sh`
3. `zsh x2t/build/scripts/sync_sdkjs.sh`
4. Compiler allfontsgen: `zsh allfontgennew/build/scripts/build_macos.sh`
5. Generer les polices: `zsh allfontgennew/build/scripts/generate_macos.sh`
6. Assembler le runtime: `zsh x2t/build/scripts/prepare_runtime_macos.sh`
7. Tester: `/chemin/vers/x2t "$(pwd)/x2t/test/config_mac.xml"`

## Documentation

- [x2t/docs/SETUP.md](x2t/docs/SETUP.md)
- [x2t/docs/USAGE.md](x2t/docs/USAGE.md)
- [x2t/docs/MAINTENANCE.md](x2t/docs/MAINTENANCE.md)
- [allfontgennew/README.md](allfontgennew/README.md)
