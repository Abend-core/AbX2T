# AbX2T Workspace

Toolkit de conversion de documents autonome sur Windows x86_64, macOS arm64, et generation de
polices (allfontsgen) sur Linux x86_64.

## Bundles

```
workspace/
|-- convert/          EXE de conversion de documents (Windows, distribue)
|-- allfontgennew/    Generateur d index de polices AllFonts.js (compile depuis core-master ; macOS, Windows, Linux)
|-- x2t/              Scripts et assets de conversion (macOS + sync Windows)
|-- core-master/      Sources upstream ONLYOFFICE (gitignore, requis pour recompiler allfontgennew)
```

## Utilisation rapide (Windows)

Dezipper l'archive, elle ne contient qu'un seul fichier : `Abx2t.exe`.

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

Au tout premier lancement, l'exe s'auto-installe (extraction des composants dans `resources\`,
generation des polices systeme dans `allfonts\`) : aucune etape manuelle requise. Un dossier
`custom-fonts\` est aussi cree pour deposer des polices supplementaires sans les installer sur
le poste (voir [convert/README.md](convert/README.md) pour le detail).

## Formats supportes

Detail et etat des tests : [convert/docs/SUPPORTED_FORMATS.md](convert/docs/SUPPORTED_FORMATS.md).

- Entree : tous les formats lus par ONLYOFFICE (word/cell/slide/visio/pdf -- docx, doc, odt, xlsx,
  xls, ods, pptx, ppt, odp, pdf, html, rtf, txt, epub, vsdx, etc.)
- Sortie : docx, odt, rtf, txt, html, pdf, pptx, odp, xlsx, ods, csv, xps
- Source et destination peuvent etre des chemins reseau (`\\serveur\partage`, lecteur mappe).

## Architecture

- `Abx2t.exe` appelle `x2t.exe` en coulisse via un XML de config temporaire, en local (TEMP
  systeme) meme si la source/destination reelle est sur un partage reseau.
- `x2t.exe` et ses DLLs viennent de l'installation ONLYOFFICE Desktop.
- `AllFonts.js` est genere par `allfontsgen.exe` depuis les polices systeme du PC et le dossier
  `custom-fonts\`, au premier lancement de `Abx2t.exe` (et regenere si `custom-fonts\` change).

## Dependances a la compilation

| Composant | Depend de core-master ? | Notes |
|---|---|---|
| `Abx2t.exe` | Non | Code C# autonome, voir [convert/README.md](convert/README.md) |
| `allfontsgen.exe` / `allfontsgen` | Oui | Sources dans `allfontgennew/src/` copiees depuis core-master (macOS, Windows, Linux) |
| `x2t.exe` | Non | Binaire pre-compile depuis ONLYOFFICE installe (macOS : release officielle : Windows : install locale) |

## Demarrage macOS

Voir **[x2t/docs/SETUP.md](x2t/docs/SETUP.md)** pour la mise en place complete.

1. Se procurer une release officielle ONLYOFFICE (dossier `Resources/`)
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Deposer `core-master/` a la racine, compiler allfontsgen : `cd allfontgennew && zsh build/scripts/build_macos.sh`
4. Generer les polices : `zsh build/scripts/generate_macos.sh`
5. `cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
6. Tester : `zsh x2t/build/scripts/convert.sh /chemin/document.docx /chemin/sortie.pdf`

## Generation de polices sur Linux

Pas de pipeline de conversion x2t sur Linux (aucun binaire ONLYOFFICE Linux disponible), mais
`allfontsgen` s'y compile et s'y execute :

```sh
cd allfontgennew
bash build/scripts/build_linux.sh
bash build/scripts/generate_linux.sh
```

Produit `output/linux-x86_64/fonts/AllFonts.js`.

## Documentation

- [convert/README.md](convert/README.md) : usage et architecture de `Abx2t.exe`
- [convert/docs/SUPPORTED_FORMATS.md](convert/docs/SUPPORTED_FORMATS.md) : formats acceptes, ce qui est teste
- [allfontgennew/docs/INDEX.md](allfontgennew/docs/INDEX.md)
- [allfontgennew/docs/USAGE.md](allfontgennew/docs/USAGE.md)
- [allfontgennew/docs/MAINTENANCE.md](allfontgennew/docs/MAINTENANCE.md)
- [x2t/docs/SETUP.md](x2t/docs/SETUP.md)
- [x2t/docs/USAGE.md](x2t/docs/USAGE.md)
- [x2t/docs/MAINTENANCE.md](x2t/docs/MAINTENANCE.md)

## License and attribution

AbX2T is distributed under the **[GNU AGPLv3](LICENSE)** license.
Copyright (C) 2026 Hugo Lagouardat, [Abend-core](https://github.com/Abend-core) project.

This repository bundles **ONLYOFFICE** components (x2t, sdkjs, and a vendored source subset
used to build `allfontsgen`), Copyright (C) Ascensio System SIA, also under AGPLv3, as well
as community spell-check dictionaries (each shipping its own license files) and FreeType
(FTL). Component details, versions, and pointers to the corresponding source code: see
**[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)**. `Abx2t.exe --license` prints the same
summary on the command line.

AbX2T is not affiliated with, endorsed by, or sponsored by Ascensio System SIA / ONLYOFFICE.

### Current distribution status

At this stage (development), `x2t/bin/` and `x2t/sdkjs/` (~160 MB, ONLYOFFICE binaries) are
committed directly into this public Git repository to simplify iteration. This is compliant
with AGPLv3 (the corresponding source code remains publicly available from ONLYOFFICE, see
THIRD-PARTY-NOTICES.md), but it is not the intended final distribution: once the product is
stable, only a ready-to-use executable (`Abx2t.exe`, following the current model: self-extracting
on first run) will be offered for download to end users, via GitHub Releases, without requiring
anyone to clone the full source repository history.
