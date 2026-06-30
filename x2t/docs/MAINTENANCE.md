# Maintenance — Mise a jour depuis upstream

## Regles de base

- `x2t/src/` et `x2t/sdkjs/` sont generes par les scripts de sync, ne pas les modifier a la main.
- `x2t/dictionaries/` est commite (fr_FR, en_US, en_GB) — mise a jour manuelle si besoin.
- Les corrections locales vont dans `x2t/build/` (config, shims), pas dans `src/`.

## Mettre a jour les sources C++ (core)

Deposer ou mettre a jour `core-master/` a la racine, puis:

```sh
zsh x2t/build/scripts/sync_sources.sh --dry-run
zsh x2t/build/scripts/sync_sources.sh
```

Points de vigilance apres maj:
- Verifier que tous les composants attendus sont presents dans core (`sync_sources.sh` le valide).
- Les liens symboliques dans `src/` pointent vers `../../../core-master/` — core-master doit rester en place pour la compilation.
- Relancer le build Qt apres synchro.

## Mettre a jour sdkjs

Deposer ou mettre a jour `sdkjs-master/` a la racine, puis:

```sh
zsh x2t/build/scripts/sync_sdkjs.sh --dry-run
zsh x2t/build/scripts/sync_sdkjs.sh
```

Le script exclut automatiquement les fichiers inutiles pour x2t:
- Fichiers navigateur: `drawingfile_ie.js`, `drawingfile.wasm`, `viewer.js`, `drawingfile.js`
- Outils de build: `build/`, `tools/`, `pdf/build/`, `pdf/test/`, scripts Python, `Makefile`

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

```sh
zsh allfontgennew/build/scripts/sync_core.sh --dry-run
zsh allfontgennew/build/scripts/sync_core.sh
```

Remplace uniquement: `Common`, `DesktopEditor`, `OdfFile`, `UnicodeConverter`.

Si `prepare_generated_sources.sh` echoue apres maj, verifier que le patch
perl dans le script correspond encore a `ApplicationFontsWorker.cpp`.

## Reassembler le runtime apres toute maj

```sh
zsh x2t/build/scripts/prepare_runtime_macos.sh
```

Puis relancer le test de conversion pour valider.
