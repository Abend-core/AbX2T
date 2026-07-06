# Documentation AbX2T

Documentation unique du projet : tout ce qu'il faut pour comprendre, utiliser,
construire et maintenir AbX2T se trouve dans ce dossier. Les README ailleurs dans le
dépôt ne sont que des pointeurs vers ici.

## Sommaire

| Fichier | Contenu | Pour qui |
|---|---|---|
| [00-couverture.md](00-couverture.md) | Page de garde | — |
| [01-vue-ensemble.md](01-vue-ensemble.md) | Le besoin, les trois composants, le schéma global, l'organisation du dépôt | Tout le monde — **commencer ici** |
| [02-utilisation.md](02-utilisation.md) | Installer, convertir, options, codes retour, formats, polices, chemins réseau, dépannage | Utilisateurs |
| [03-architecture.md](03-architecture.md) | Déroulé d'une conversion, cycle de vie auto-réparant, détails par plateforme | Développeurs |
| [04-build.md](04-build.md) | Prérequis et pipeline complet par OS, conteneurs/glibc, fallback manuel | Mainteneurs |
| [05-composants.md](05-composants.md) | VERSIONS, x2t/sdkjs, allfontsgen (invariants), core-master | Mainteneurs |
| [06-performances.md](06-performances.md) | Ordres de grandeur de poids et de vitesse | Tout le monde |
| [07-licences.md](07-licences.md) | AGPLv3, attribution ONLYOFFICE, conformité | Tout le monde |
| [08-maintenance.md](08-maintenance.md) | Monter de version, releases/tags, veille sécurité, chantiers futurs | Mainteneurs |

## Conventions

- **Pas de chiffres exacts** pour les tailles et durées : des ordres de grandeur, qui
  ne périment pas à chaque version du bundle.
- **Footer de version** : chaque fichier se termine par *« Documentation à jour au
  commit `xxxxxxx` »* — l'état du dépôt que le fichier décrit. Si le code a beaucoup
  bougé depuis ce commit, la doc est peut-être en retard.
- La version du bundle ONLYOFFICE n'est jamais écrite en dur ici : voir
  [`VERSIONS`](../VERSIONS).

## Générer le PDF

```sh
python3 docs/generate-pdf.py        # produit docs/PDF/documentation-abx2t.pdf
```

Nécessite [pandoc](https://pandoc.org) (et un moteur PDF : wkhtmltopdf, weasyprint ou
une distribution LaTeX). Sans pandoc, le script explique quoi installer.

---

*Documentation à jour au commit `1fe36b8`.*
