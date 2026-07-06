# 07 — Licences et attribution

## AbX2T

AbX2T est distribué sous **[GNU AGPLv3](../LICENSE)**.
Copyright (C) 2026 Hugo Lagouardat, projet [Abend-core](https://github.com/Abend-core).

## Composants tiers embarqués

L'exécutable distribué embarque des composants tiers, extraits dans `resources/` au
premier lancement **avec leurs textes de licence** (`LICENSE`,
`THIRD-PARTY-NOTICES.md`), pour que la distribution mono-exe reste autonome
juridiquement :

| Composant | Copyright | Licence | Source correspondante |
|---|---|---|---|
| x2t / sdkjs (moteur et runtime de conversion) | Ascensio System SIA | AGPLv3 | `github.com/ONLYOFFICE/core` et `/sdkjs`, au tag `ONLYOFFICE_CORE_BUILD` de [`VERSIONS`](../VERSIONS) |
| allfontsgen (indexeur de polices, compilé depuis un sous-ensemble vendored de ONLYOFFICE/core) | Ascensio System SIA ; portions FreeType Project | AGPLv3 ; FTL | `allfontsgen/src/` dans ce dépôt + upstream ONLYOFFICE/core |

Les binaires x2t embarquent eux-mêmes d'autres bibliothèques tierces (ICU, FreeType,
HarfBuzz, V8…) : voir `3DPARTY.md` dans le dépôt ONLYOFFICE/core.

Détail complet, versions et pointeurs : **[THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md)**.
`Abx2t --license` affiche le même résumé en ligne de commande.

## Conformité AGPLv3 — points clés

- Les composants ONLYOFFICE sont utilisés **non modifiés**, emballés et invoqués en
  sous-processus ; le code source correspondant à la version exacte embarquée reste
  publiquement disponible chez ONLYOFFICE (liens versionnés ci-dessus).
- Le code d'AbX2T lui-même est public dans ce dépôt.
- Les tags de release d'AbX2T reprennent la numérotation du bundle ONLYOFFICE : le
  binaire `vX.Y.Z.B` correspond aux sources ONLYOFFICE `vX.Y.Z.B` — la traçabilité
  binaire ↔ source est directe.

AbX2T n'est ni affilié à, ni approuvé, ni sponsorisé par Ascensio System SIA /
ONLYOFFICE.

---

*Documentation à jour au commit `1fe36b8`.*
