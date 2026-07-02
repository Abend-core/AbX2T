# x2t — Maintenance

## Regles de base

- `x2t/bin/` et `x2t/sdkjs/` sont commites dans ce depot (etat actuel, voir
  [README.md](../../README.md#current-distribution-status)) : generes/re-synchronises
  localement via les scripts ci-dessous, puis commites tels quels.
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

Reinstaller ONLYOFFICE Desktop Editors puis :

```powershell
powershell -ExecutionPolicy Bypass -File x2t\build\scripts\sync_from_install_windows.ps1 -DryRun   # verifier
powershell -ExecutionPolicy Bypass -File x2t\build\scripts\sync_from_install_windows.ps1
```

Points de vigilance :
- Le script verifie la presence des JS obligatoires avant de synchroniser.
- `x2t/sdkjs/common/AllFonts.js` est preserve automatiquement si deja present.
- Repackager ensuite `assets.zip` pour `Abx2t.exe` : `powershell -ExecutionPolicy Bypass -File convert\build\package_windows.ps1` (voir [convert/README.md](../../convert/README.md)).

## Mettre a jour les dictionnaires

```sh
cp -R /chemin/vers/dictionaries-master/de_DE x2t/dictionaries/
git add x2t/dictionaries/de_DE
```

Copier le dossier upstream **en entier** : les fichiers de licence/README qu'il contient
(`license.txt`, `README_*.txt`, ...) sont l'attribution officielle du dictionnaire et doivent
voyager avec lui (exigence documentee dans [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md)).
Rien d'autre a mettre a jour : les notices sont redigees de facon generique, ajouter un
dictionnaire ne demande aucune modification de THIRD-PARTY-NOTICES.md.

## DoctRenderer.config (Windows)

Ce fichier configure les chemins JS relatifs pour x2t.exe, et differe selon la mise en page :
- Dans `x2t/bin/windows-x86_64/` (genere par `sync_from_install_windows.ps1`) : pointe vers
  `..\..\sdkjs\` (bin/windows-x86_64/ est imbrique deux niveaux sous x2t/).
- Dans `resources/` (assets.zip embarque dans `Abx2t.exe`, genere par `package_windows.ps1`) :
  pointe vers `./sdkjs/` (x2t.exe et sdkjs/ sont directement cote a cote).

Ces deux versions sont regenerees automatiquement par leurs scripts respectifs ; pas de fichier
a preserver manuellement.