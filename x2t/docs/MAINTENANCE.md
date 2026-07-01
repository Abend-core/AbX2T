# Maintenance — Mise a jour depuis upstream

## Regles de base

- `x2t/bin/` et `x2t/sdkjs/` sont generes par `sync_from_release.sh`, ne pas les modifier a la main
  (sauf `x2t/sdkjs/common/AllFonts.js`, genere separement par allfontgennew et preserve par le script).
- `x2t/dictionaries/` est commite (fr_FR, en_US, en_GB) — mise a jour manuelle si besoin.
- x2t lui-meme (binaire + JS de conversion) vient toujours d'une release officielle ONLYOFFICE,
  jamais recompile depuis core-master/sdkjs-master dans ce flux.

## Mettre a jour x2t (nouvelle release ONLYOFFICE)

Se procurer le nouveau dossier `Resources/` de la release, puis:

```sh
zsh x2t/build/scripts/sync_from_release.sh --dry-run /chemin/vers/nouvelle/Resources
zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/nouvelle/Resources
```

Points de vigilance apres maj:
- Le script verifie que les fichiers JS attendus (`sdk-all-min.js` + `sdk-all.js` pour
  word/slide/cell, `fonts_native.js`, `native.js`, `xregexp-all-min.js`, `drawingfile_native.js`,
  `cmap.bin`) sont bien presents dans la release avant de synchroniser.
- `sdk-all-min.js` et `sdk-all.js` sont **obligatoires ensemble** — `sdk-all.js` definit
  `AscFonts.vbj` et les autres methodes appelees par `InitNativeEditors()` au demarrage.
- `x2t/sdkjs/common/AllFonts.js` est preserve automatiquement si deja present.
- Relancer le test de conversion pour valider (voir USAGE.md).

## Mettre a jour les dictionnaires

`x2t/dictionaries/` contient fr_FR, en_US, en_GB commites directement.

Pour ajouter une langue:
```sh
cp -R /chemin/vers/dictionaries-master/de_DE x2t/dictionaries/
git add x2t/dictionaries/de_DE
```

Pour rafraichir depuis upstream:
```sh
cp -R /chemin/vers/dictionaries-master/fr_FR x2t/dictionaries/fr_FR
# idem pour en_US, en_GB
```

## Mettre a jour allfontgennew/src (pour allfontsgen)

`allfontgennew` reste compile depuis les sources core-master (contrairement a x2t) :

```sh
zsh allfontgennew/build/scripts/sync_core.sh --dry-run
zsh allfontgennew/build/scripts/sync_core.sh
```

Remplace uniquement: `Common`, `DesktopEditor`, `OdfFile`, `UnicodeConverter`.

Si `prepare_generated_sources.sh` echoue apres maj, verifier que le patch
perl dans le script correspond encore a `ApplicationFontsWorker.cpp`.

Recompiler puis regenerer les polices:
```sh
cd allfontgennew
zsh build/scripts/build_macos.sh
zsh build/scripts/generate_macos.sh
cd ..
cp allfontgennew/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
```

Puis relancer le test de conversion pour valider.

## Chemin legacy : compiler x2t depuis les sources

Les scripts `sync_sources.sh`, `sync_sdkjs.sh`, `build_macos.sh`, `prepare_runtime_macos.sh`
dans `x2t/build/scripts/` restent presents pour compiler x2t soi-meme depuis `core-master/` et
`sdkjs-master/`, mais ne sont pas le chemin utilise/valide actuellement. Voir les scripts pour
le detail si ce chemin est necessaire (ex: patch local a tester avant upstream).
