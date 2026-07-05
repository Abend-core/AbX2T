# AbX2T Workspace

Toolkit de conversion de documents autonome sur Windows x86_64, macOS arm64 et Linux x86_64.

## Bundles

```
workspace/
|-- convert/          EXE de conversion de documents (Windows + macOS + Linux, distribue)
|-- allfontsgen/    Generateur d index de polices AllFonts.js (compile depuis core-master ; macOS, Windows, Linux)
|-- x2t/              Scripts et assets de conversion (sync macOS + Windows + Linux)
|-- core-master/      Sources upstream ONLYOFFICE (gitignore, requis pour recompiler allfontsgen)
```

## Utilisation rapide (Windows)

Dezipper l'archive, elle ne contient qu'un seul fichier : `Abx2t.exe`.

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

(Sur macOS/Linux, meme principe avec l'exe `Abx2t` : `./Abx2t rapport.docx rapport.pdf`.)

Au tout premier lancement, l'exe s'auto-installe (extraction des composants dans `resources\`,
generation des polices systeme dans `allfonts\`) : aucune etape manuelle requise. Un dossier
`custom-fonts\` est aussi cree pour deposer des polices supplementaires sans les installer sur
le poste (voir [src/README.md](src/README.md) pour le detail).

## Formats supportes

Detail et etat des tests : [docs/SUPPORTED_FORMATS.md](docs/SUPPORTED_FORMATS.md).

- Entree : tous les formats lus par ONLYOFFICE (word/cell/slide/visio/pdf -- docx, doc, odt, xlsx,
  xls, ods, pptx, ppt, odp, pdf, html, rtf, txt, epub, vsdx, etc.)
- Sortie : docx, odt, rtf, txt, html, pdf, pptx, odp, xlsx, ods, csv, xps
- Source et destination peuvent etre des chemins reseau (`\\serveur\partage`, lecteur mappe).

## Architecture

- `Abx2t` appelle `x2t` en coulisse via un XML de config temporaire, en local (TEMP
  systeme) meme si la source/destination reelle est sur un partage reseau.
- `x2t` et ses DLLs (Windows), frameworks (macOS) ou `.so` (Linux) viennent d'une installation
  ONLYOFFICE Desktop locale ou d'une release officielle, selon l'OS (voir tableau ci-dessous).
- `AllFonts.js` est genere par `allfontsgen` depuis les polices systeme du PC et le dossier
  `custom-fonts\`, au premier lancement de `Abx2t` (et regenere si `custom-fonts\` change).

## Dependances a la compilation

| Composant | Depend de core-master ? | Notes |
|---|---|---|
| `Abx2t.exe` | Non | Code C# autonome, voir [src/README.md](src/README.md) |
| `allfontsgen.exe` / `allfontsgen` | Oui | Sources dans `allfontsgen/src/` copiees depuis core-master (macOS, Windows, Linux) |
| `x2t.exe` / `x2t` | Non | Binaire pre-compile depuis ONLYOFFICE (macOS : release officielle ; Windows : install locale ; Linux : .deb officiel) |

## Demarrage macOS

Voir **[x2t/docs/SETUP.md](x2t/docs/SETUP.md)** pour la mise en place complete des composants
(x2t, sdkjs, polices), et **[src/README.md](src/README.md#macos)** pour builder
`Abx2t` lui-meme.

1. Se procurer une release officielle ONLYOFFICE (dossier `Resources/`)
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Deposer `core-master/` a la racine, compiler allfontsgen : `cd allfontsgen && zsh build/scripts/build_macos.sh`
4. Generer les polices : `zsh build/scripts/generate_macos.sh`
5. `cp allfontsgen/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
6. Tester le moteur seul : `zsh x2t/build/scripts/convert.sh /chemin/document.docx /chemin/sortie.pdf`
7. Builder l'exe `Abx2t` distribuable : `zsh build/package_macos.sh` puis
   `dotnet publish src/Abx2t.csproj -c Release -r osx-arm64` (voir
   [src/README.md](src/README.md) pour le detail NativeAOT).

## Demarrage Linux

Meme pipeline que Windows/macOS : les binaires x2t Linux viennent du `.deb` officiel
ONLYOFFICE Desktop Editors (l'exe final `Abx2t` ne depend que de la glibc — il tourne sur
n'importe quelle distro et dans une image conteneur distroless, voir
[src/README.md](src/README.md#linux)).

1. Telecharger le `.deb` officiel (version alignee sur le bundle, ici 9.4.0) :
   `https://download.onlyoffice.com/repo/debian/pool/main/o/onlyoffice-desktopeditors/onlyoffice-desktopeditors_9.4.0_amd64.deb`
2. `bash x2t/build/scripts/sync_from_release_linux.sh /chemin/vers/le.deb`
3. Compiler allfontsgen : `cd allfontsgen && bash build/scripts/build_linux.sh`
4. Generer les polices : `bash build/scripts/generate_linux.sh` puis
   `cp allfontsgen/output/linux-x86_64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
5. Builder l'exe `Abx2t` distribuable : `bash build/package_linux.sh` puis
   `dotnet publish src/Abx2t.csproj -c Release -r linux-x64` (voir
   [src/README.md](src/README.md) pour le detail NativeAOT).

## Documentation

- [src/README.md](src/README.md) : usage et architecture de `Abx2t.exe`
- [docs/SUPPORTED_FORMATS.md](docs/SUPPORTED_FORMATS.md) : formats acceptes, ce qui est teste
- [allfontsgen/docs/INDEX.md](allfontsgen/docs/INDEX.md)
- [allfontsgen/docs/USAGE.md](allfontsgen/docs/USAGE.md)
- [allfontsgen/docs/MAINTENANCE.md](allfontsgen/docs/MAINTENANCE.md)
- [x2t/docs/SETUP.md](x2t/docs/SETUP.md)
- [x2t/docs/USAGE.md](x2t/docs/USAGE.md)
- [x2t/docs/MAINTENANCE.md](x2t/docs/MAINTENANCE.md)

## License and attribution

AbX2T is distributed under the **[GNU AGPLv3](LICENSE)** license.
Copyright (C) 2026 Hugo Lagouardat, [Abend-core](https://github.com/Abend-core) project.

This repository bundles **ONLYOFFICE** components (x2t, sdkjs, and a vendored source subset
used to build `allfontsgen`), Copyright (C) Ascensio System SIA, also under AGPLv3, as well
as FreeType (FTL). Component details, versions, and pointers to the corresponding source code: see
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
