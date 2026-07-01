# x2t — Usage

## Prerequis

Avoir execute les etapes de SETUP.md au moins une fois :
- `x2t/bin/` peuple (sync_from_release.sh ou copie depuis ONLYOFFICE installe)
- `x2t/sdkjs/` peuple, avec `x2t/sdkjs/common/AllFonts.js` present

## Convertir un document

### macOS (convert.sh)

```sh
zsh x2t/build/scripts/convert.sh /chemin/absolu/vers/document.docx /chemin/absolu/vers/sortie.pdf
```

### Windows (convert.exe)

```powershell
.\convert.exe "rapport.docx" "rapport.pdf"
```

`convert.exe` est le point d entree recommande sur Windows. Il genere le XML de config
en coulisse, lance x2t.exe, et nettoie apres lui.

## Formats supportes par convert.exe

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
x2t/bin/x2t "/chemin/vers/config.xml"

# Windows
cd x2t\bin\windows-x86_64
.\x2t.exe "C:\chemin\vers\config.xml"
```

## Regenerer les polices (nouvelle police installee)

### macOS

```sh
cd allfontgennew
zsh build/scripts/generate_macos.sh
cp output/macos-arm64/fonts/AllFonts.js ../x2t/sdkjs/common/AllFonts.js
```

### Windows

```powershell
# Dans le dossier convert/out/ :
.\install.ps1
```

## Pourquoi m_sTempDir est recommande (macOS/Linux)

Sans `m_sTempDir` explicite, x2t cree un dossier temporaire `ascXXXXXX` a cote du
fichier de sortie et peut ne pas le supprimer en cas d erreur. `convert.sh` gere
ce nettoyage via `mktemp -d` + `trap EXIT`. Sur Windows, `convert.exe` passe par
le dossier temp systeme (%TEMP%) et nettoie apres chaque appel.