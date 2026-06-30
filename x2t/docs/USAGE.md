# Usage

## Prerequis

Avoir execute les etapes de SETUP.md au moins une fois:
- `x2t/src/` peuple (sync_sources.sh)
- `x2t/sdkjs/` peuple (sync_sdkjs.sh)
- `allfontgennew/output/macos-arm64/fonts/AllFonts.js` present
- `output/macos-arm64/runtime/` assemble (prepare_runtime_macos.sh)
- Un binaire `x2t` disponible

## Convertir un document

Creer ou dupliquer `x2t/test/config_mac.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>/chemin/absolu/vers/document.docx</m_sFileFrom>
    <m_sFileTo>/chemin/absolu/vers/sortie.pdf</m_sFileTo>
    <m_sAllFontsPath>/chemin/absolu/vers/output/macos-arm64/runtime/fonts/AllFonts.js</m_sAllFontsPath>
    <m_sFontDir>/chemin/absolu/vers/output/macos-arm64/runtime/fonts</m_sFontDir>
</TaskQueueDataConvert>
```

Lancer la conversion:

```sh
/chemin/vers/x2t "/chemin/absolu/vers/config.xml"
```

## Reassembler le runtime

Si AllFonts.js a ete regenere ou si sdkjs a ete mis a jour:

```sh
zsh x2t/build/scripts/prepare_runtime_macos.sh
```

## Regenerer les polices

Si les polices systeme ont change:

```sh
cd allfontgennew
zsh build/scripts/generate_macos.sh
```

Puis reassembler le runtime.

## Compiler x2t (si binaire non disponible)

Necessite Qt (`qmake` dans le PATH):

```sh
zsh x2t/build/scripts/build_macos.sh
```

Produit `output/macos-arm64/bin/x2t`.

## Validation rapide

```sh
# 1. Verifier que le runtime est en place
ls output/macos-arm64/runtime/fonts/AllFonts.js

# 2. Lancer la conversion de test
/chemin/vers/x2t "$(pwd)/x2t/test/config_mac.xml"

# 3. Verifier la sortie
ls x2t/test/*.pdf
```
