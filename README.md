# AbX2T Workspace

Toolkit de conversion de documents (doc/docx -> pdf) autonome sur Windows x86_64 et macOS arm64.

## Bundles

```
workspace/
|-- convert/          EXE de conversion doc/docx -> pdf (Windows, distribue)
|-- allfontgennew/    Generateur d index de polices AllFonts.js (compile depuis core-master)
|-- x2t/              Scripts et assets de conversion (macOS)
|-- core-master/      Sources upstream ONLYOFFICE (gitignore, requis pour recompiler allfontgennew)
```

## Utilisation rapide (Windows)

Dezipper `convert-windows-x64.zip`, puis une seule fois par PC :

```powershell
.\install.ps1
```

Ensuite pour convertir :

```powershell
.\convert.exe "rapport.docx" "rapport.pdf"
```

## Formats supportes

- Entree : `.docx`, `.doc`
- Sortie : `.pdf`

## Architecture

- `convert.exe` appelle `x2t.exe` en coulisse via un XML de config temporaire.
- `x2t.exe` et ses DLLs viennent de linstallation ONLYOFFICE Desktop.
- `AllFonts.js` est genere par `allfontsgen.exe` depuis les polices systeme du PC.
- `install.ps1` regenere `AllFonts.js` au premier lancement (ou apres installation de nouvelles polices).

## Dependances a la compilation

| Composant | Depend de core-master ? | Notes |
|---|---|---|
| `convert.exe` | Non | Code C# autonome |
| `allfontsgen.exe` | Oui | Sources dans `allfontgennew/src/` copiees depuis core-master |
| `x2t.exe` | Non | Binaire pre-compile depuis ONLYOFFICE installe |

## Demarrage macOS

Voir **[x2t/docs/SETUP.md](x2t/docs/SETUP.md)** pour la mise en place complete.

1. Se procurer une release officielle ONLYOFFICE (dossier `Resources/`)
2. `zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources`
3. Deposer `core-master/` a la racine, compiler allfontsgen : `cd allfontgennew && zsh build/scripts/build_macos.sh`
4. Generer les polices : `zsh build/scripts/generate_macos.sh`
5. `cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js`
6. Tester : `x2t/bin/x2t "$(pwd)/x2t/test/config_mac.xml"`

## Documentation

- [convert/](convert/) : code source de convert.exe et install.ps1
- [allfontgennew/docs/INDEX.md](allfontgennew/docs/INDEX.md)
- [allfontgennew/docs/USAGE.md](allfontgennew/docs/USAGE.md)
- [allfontgennew/docs/MAINTENANCE.md](allfontgennew/docs/MAINTENANCE.md)
- [x2t/docs/SETUP.md](x2t/docs/SETUP.md)
- [x2t/docs/USAGE.md](x2t/docs/USAGE.md)
- [x2t/docs/MAINTENANCE.md](x2t/docs/MAINTENANCE.md)