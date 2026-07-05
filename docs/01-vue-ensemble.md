# 01 — Vue d'ensemble

## Le besoin

Convertir des documents bureautiques (docx, xlsx, pptx, pdf, odt…) en ligne de commande,
sans installer de suite bureautique, sans dépendance à un service en ligne, et sans étape
de configuration : **un seul fichier à distribuer, qui s'auto-installe au premier
lancement**.

```
Abx2t rapport.docx rapport.pdf
```

Le moteur de conversion est celui d'ONLYOFFICE (`x2t`), utilisé tel quel, jamais modifié ni
recompilé : AbX2T l'emballe, le pilote et gère tout ce qu'il ne fait pas lui-même
(installation, polices, fichiers temporaires, chemins réseau, timeouts, codes retour).

## Les trois composants

| Composant | Rôle | Provenance |
|---|---|---|
| **Abx2t** (`src/`) | L'exécutable distribué. Wrapper C# NativeAOT : CLI, auto-installation, cycle de vie des composants, appel de x2t | Code du projet |
| **x2t + sdkjs** (`x2t/`) | Le moteur de conversion ONLYOFFICE (binaire natif + runtime JS) | Releases officielles ONLYOFFICE, téléchargées par les scripts fetch — jamais recompilé ici |
| **allfontsgen** (`allfontsgen/`) | Génère l'index de polices (`AllFonts.js`) dont x2t a besoin, à partir des polices de la machine cible | Compilé ici depuis un sous-ensemble des sources ONLYOFFICE/core |

Le détail de chaque composant : [05-composants.md](05-composants.md).

## Comment ça s'assemble

```
                       ┌──────────────────────────────────────────┐
   BUILD (mainteneur)  │  fetch_onlyoffice_<os>  → x2t/bin, sdkjs │
                       │  build allfontsgen      → allfontsgen    │
                       │  package_<os>           → assets.zip     │
                       │  dotnet publish (AOT)   → Abx2t (1 exe)  │
                       └──────────────────┬───────────────────────┘
                                          │  distribution : ce seul fichier
                       ┌──────────────────▼───────────────────────┐
   PREMIER LANCEMENT   │  extraction assets.zip → resources/      │
   (utilisateur)       │  allfontsgen           → allfonts/       │
                       │  création              → custom-fonts/   │
                       └──────────────────┬───────────────────────┘
                                          │
                       ┌──────────────────▼───────────────────────┐
   CHAQUE CONVERSION   │  config XML → x2t (sous-processus)       │
                       │  → fichier converti                      │
                       └──────────────────────────────────────────┘
```

## Plateformes

| Plateforme | Statut |
|---|---|
| Windows x86_64 | Cible publique principale (`Abx2t.exe`) |
| macOS arm64 | Supporté (développement et usage) |
| Linux x86_64 | Supporté, y compris conteneurs distroless (voir [04-build.md](04-build.md#linux)) |

L'exécutable est spécifique à chaque plateforme (NativeAOT ne cross-compile pas) mais le
code et le pipeline sont identiques partout.

## Organisation du dépôt

```
AbX2T/
├── README.md, LICENSE, THIRD-PARTY-NOTICES.md, VERSIONS
├── docs/           Cette documentation (source unique — les README de modules pointent ici)
├── src/            Abx2t.csproj + Program.cs : le produit
├── build/          Scripts de fetch (téléchargement ONLYOFFICE), packaging, smoke test
├── x2t/            Composant moteur : bin/<os-arch>/ et sdkjs/ (non versionnés,
│                   re-téléchargeables), scripts de sync
├── allfontsgen/    Composant polices : sources vendored + build + génération
└── core-master/    Checkout des sources ONLYOFFICE/core (non versionné, requis
                    uniquement pour recompiler allfontsgen)
```

Les binaires ONLYOFFICE (`x2t/bin/`, `x2t/sdkjs/`) ne sont **pas commités** : ils se
retéléchargent à l'identique depuis les releases officielles, version épinglée et hash
vérifié par [`VERSIONS`](../VERSIONS) (voir [05-composants.md](05-composants.md#versions)).

---

*Documentation à jour au commit `6c3f6e8`.*
