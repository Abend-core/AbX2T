# x2t — Maintenance

## Regles de base

- `x2t/bin/` et `x2t/sdkjs/` sont dans .gitignore — generes localement, pas commites.
- `x2t/dictionaries/` est commite (fr_FR, en_US, en_GB).
- Sur Windows, x2t.exe et ses DLLs viennent de ONLYOFFICE Desktop installe.
- Sur macOS, x2t vient d une release officielle ONLYOFFICE via sync_from_release.sh.
- `AllFonts.js` est toujours genere par allfontsgen depuis les polices du PC cible.

## Mettre a jour x2t (macOS — nouvelle release ONLYOFFICE)

```sh
zsh x2t/build/scripts/sync_from_release.sh --dry-run /chemin/vers/nouvelle/Resources
zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/nouvelle/Resources
```

Points de vigilance :
- Le script verifie la presence des JS obligatoires avant de synchroniser.
- `x2t/sdkjs/common/AllFonts.js` est preserve automatiquement si deja present.
- Relancer le test de conversion pour valider.

## Mettre a jour x2t (Windows — nouvelle version ONLYOFFICE)

Reinstaller ONLYOFFICE Desktop Editors puis recopier les fichiers :

```powershell
$src = "C:\Program Files\ONLYOFFICE\DesktopEditors\converter"
$dest = "d:\abX2T\x2t\bin\windows-x86_64"
Copy-Item "$src\*" $dest -Recurse -Force
# Restaurer DoctRenderer.config personnalise apres la copie
```

Puis recopier sdkjs si besoin et relancer install.ps1 dans convert/out/.

## Mettre a jour les dictionnaires

```sh
cp -R /chemin/vers/dictionaries-master/de_DE x2t/dictionaries/
git add x2t/dictionaries/de_DE
```

## DoctRenderer.config (Windows)

Ce fichier configure les chemins JS relatifs pour x2t.exe.
La version dans `x2t/bin/windows-x86_64/` pointe vers `../../sdkjs/`.
La version dans `convert/out/` pointe vers `sdkjs/` (relatif au meme dossier).
Ne pas ecraser ce fichier lors d une maj ONLYOFFICE sans le restaurer.

## Chemin legacy : compiler x2t depuis les sources

Les scripts `sync_sources.sh`, `sync_sdkjs.sh`, `build_macos.sh`, `prepare_runtime_macos.sh`
restent presents mais ne sont pas le chemin valide actuellement. Ils necessitent Qt et ICU.