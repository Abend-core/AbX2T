# x2t — Usage

## Prerequis

Avoir execute les etapes de SETUP.md au moins une fois :
- `x2t/bin/` peuple (`sync_from_release.sh` sur macOS, `sync_from_install_windows.ps1` sur Windows)
- `x2t/sdkjs/` peuple, avec `x2t/sdkjs/common/AllFonts.js` present

## Convertir un document

### macOS (convert.sh)

```sh
zsh x2t/build/scripts/convert.sh /chemin/absolu/vers/document.docx /chemin/absolu/vers/sortie.pdf
```

### Windows (Abx2t.exe)

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

`Abx2t.exe` est le point d'entree recommande sur Windows (voir [src/README.md](../../src/README.md)).
Il s'auto-installe au premier lancement, genere le XML de config en coulisse, lance x2t.exe, et
nettoie apres lui.

## Formats supportes par Abx2t.exe

- Entree : `.docx`, `.doc`
- Sortie : `.pdf`

## Conversion manuelle via XML (toutes plateformes)

Creer un fichier XML de config :

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>/chemin/absolu/vers/document.docx</m_sFileFrom>
    <m_sFileTo>/chemin/absolu/vers/sortie.pdf</m_sFileTo>
    <m_sAllFontsPath>/chemin/vers/AllFonts.js</m_sAllFontsPath>
    <m_sFontDir>/chemin/vers/dossier/polices</m_sFontDir>
    <m_sThemeDir>/chemin/vers/sdkjs</m_sThemeDir>
</TaskQueueDataConvert>
```

Lancer :

```sh
# macOS
x2t/bin/macos-arm64/x2t "/chemin/vers/config.xml"

# Windows
cd x2t\bin\windows-x86_64
.\x2t.exe "C:\chemin\vers\config.xml"
```

## Regenerer les polices (nouvelle police installee)

### macOS

```sh
cd allfontsgen
zsh build/scripts/generate_macos.sh
cp output/macos-arm64/fonts/AllFonts.js ../x2t/sdkjs/common/AllFonts.js
```

### Windows

`Abx2t.exe` regenere automatiquement `allfonts\AllFonts.js` s'il est absent. Pour forcer une
regeneration (nouvelle police installee), supprimer le fichier et relancer une conversion :

```powershell
Remove-Item allfonts\AllFonts.js
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

## Pourquoi m_sTempDir est recommande (macOS/Linux)

Sans `m_sTempDir` explicite, x2t cree un dossier temporaire `ascXXXXXX` a cote du
fichier de sortie et peut ne pas le supprimer en cas d erreur. `convert.sh` gere
ce nettoyage via `mktemp -d` + `trap EXIT`. Sur Windows, `Abx2t.exe` passe par
le dossier temp systeme (%TEMP%) et nettoie apres chaque appel.