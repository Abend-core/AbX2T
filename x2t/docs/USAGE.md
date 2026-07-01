# Usage

## Prerequis

Avoir execute les etapes de SETUP.md au moins une fois:
- `x2t/bin/` peuple (sync_from_release.sh)
- `x2t/sdkjs/` peuple, avec `x2t/sdkjs/common/AllFonts.js` present

## Convertir un document (recommande : convert.sh)

```sh
zsh x2t/build/scripts/convert.sh /chemin/absolu/vers/document.docx /chemin/absolu/vers/sortie.pdf
```

Ce wrapper est le point d'entree recommande en production. Il gere lui-meme un
dossier temporaire de travail (via `mktemp` + `trap`) et garantit sa suppression,
succes ou echec — voir "Pourquoi convert.sh" ci-dessous.

## Convertir un document (config XML manuelle)

Creer ou dupliquer `x2t/test/config_mac.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>/chemin/absolu/vers/document.docx</m_sFileFrom>
    <m_sFileTo>/chemin/absolu/vers/sortie.pdf</m_sFileTo>
    <m_sAllFontsPath>/chemin/absolu/vers/x2t/sdkjs/common/AllFonts.js</m_sAllFontsPath>
    <m_sFontDir>/chemin/absolu/vers/allfontgennew/output/macos-arm64/fonts</m_sFontDir>
    <m_sTempDir>/chemin/absolu/vers/dossier/temp/dedie</m_sTempDir>
</TaskQueueDataConvert>
```

Lancer la conversion:

```sh
x2t/bin/x2t "/chemin/absolu/vers/config.xml"
```

**Toujours fournir `<m_sTempDir>`** (voir section suivante) et nettoyer ce dossier
soi-meme apres l'appel — ne pas s'appuyer sur x2t pour le faire.

## Pourquoi convert.sh (et pourquoi `<m_sTempDir>` est obligatoire)

Sans `m_sTempDir` explicite, x2t cree un dossier temporaire `ascXXXXXX` **a cote du
fichier de sortie** et tente de le supprimer lui-meme en fin de conversion.

Sur macOS/Linux, ce nettoyage automatique est fiable a moitie seulement : la fonction
de listage recursif de `core-master/DesktopEditor/common/Directory.cpp`
(`GetDirectories()`) ignore explicitement les sous-dossiers dont le nom commence par
un point. Si un tel sous-dossier cache apparait pendant la conversion, la suppression
finale (`rmdir()`) echoue silencieusement — le code retour n'est pas verifie — et le
dossier `ascXXXXXX` reste orphelin a cote de la sortie. Vu dans ce workspace des le
premier test de conversion complet.

Comme x2t est ici un **binaire pre-compile** (release officielle ONLYOFFICE, jamais
recompile depuis les sources), ce bug ne peut pas etre corrige directement. La lib
prevoit deja la solution cote appelant : si `m_sTempDir` est fourni dans la config,
x2t considere le dossier comme externe et ne tente plus de le supprimer — c'est a
l'appelant de le faire.

`convert.sh` implemente ce contrat : `mktemp -d` + `trap 'rm -rf ...' EXIT`, donc le
dossier temporaire est toujours supprime (succes, echec, ou interruption), sans
dependre du nettoyage buggy interne a x2t.

## Regenerer les polices (nouvelle police installee, etc.)

Si les polices systeme ont change (ex: nouvelle police installee):

```sh
cd allfontgennew
zsh build/scripts/generate_macos.sh
cd ..
cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
```

Puis relancer la conversion.

## Mettre a jour x2t (nouvelle release ONLYOFFICE)

```sh
zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/nouvelle/Resources
```

Ce script preserve `x2t/sdkjs/common/AllFonts.js` s'il est deja present.

## Validation rapide

```sh
# 1. Verifier que le bundle est en place
ls x2t/bin/x2t x2t/sdkjs/common/AllFonts.js

# 2. Lancer la conversion de test
zsh x2t/build/scripts/convert.sh \
  "$(pwd)/allfontgennew/test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.docx" \
  "$(pwd)/x2t/test/Rapport-alternance-LGI-Hugo-Lagouardat-Massirolles.pdf"

# 3. Verifier la sortie (et l'absence de dossier ascXXXXXX residuel)
ls x2t/test/
```
