# 06 — Performances et poids

Ordres de grandeur uniquement — les chiffres exacts varient à chaque version du bundle
ONLYOFFICE et n'ont pas d'intérêt opérationnel.

## Poids

| Quoi | Échelle | Notes |
|---|---|---|
| Exécutable distribué (NativeAOT) | ~60 Mo | Dominé à >90 % par `assets.zip` (binaires ONLYOFFICE compressés) ; le wrapper .NET lui-même est marginal |
| Exécutable fallback JIT | ~100 Mo | `-p:PublishAot=false`, nécessite le runtime .NET |
| `resources/` extrait | ~150–200 Mo | Compressé NTFS sur Windows (~moitié sur disque), transparent pour x2t |
| `allfonts/` | quelques Mo | Dépend du nombre de polices de la machine |
| Dépôt git cloné | ~10 Mo de sources | Les binaires ONLYOFFICE ne sont pas versionnés (re-téléchargés au build) |

Le poids de l'exe n'est pas compressible significativement sans complexifier le code :
les DLL/frameworks/.so de x2t s'importent statiquement (rien à retirer sans recompiler
ONLYOFFICE) et alléger le JS ne change presque rien. Décision actée : pas de mécanisme
d'archive custom pour gagner quelques Mo.

## Vitesse

| Étape | Échelle | Notes |
|---|---|---|
| Premier lancement | dizaines de secondes | Extraction (~150–200 Mo) + indexation des polices ; une seule fois par machine/version. La compression NTFS tourne en arrière-plan, sans faire attendre |
| Lancements suivants | instantané | Vérification des marqueurs = quelques lectures de fichiers |
| Conversion simple (document de quelques pages) | secondes | Coût dominé par le démarrage de x2t (chargement ICU + AllFonts.js) puis la conversion elle-même |
| Gros document (centaines de pages, images) | minutes | Dépend du **contenu**, pas seulement de la taille du fichier |
| Garde-fou | 30 min par défaut | Un x2t figé (fichier malformé) ne finit jamais ; le timeout tranche entre « lent » et « mort » (`--timeout` pour ajuster) |

## Ce qui coûte (et ce qui ne coûte pas)

- **Chemins locaux** : aucune copie intermédiaire — x2t lit la source et écrit la
  destination directement.
- **Chemins réseau** : une copie complète aller (source → TEMP local) et retour
  (TEMP → destination). C'est voulu : x2t ne doit jamais dépendre du comportement d'un
  partage SMB.
- **Overhead du wrapper** (parsing, config XML, spawn du process) : millisecondes,
  négligeable devant x2t.
- **Parallélisme** : chaque instance Abx2t est indépendante (dossier de travail
  dédié) ; lancer plusieurs conversions en parallèle fonctionne et multiplie le débit
  sur les lots. Seule la préparation initiale (premier lancement) est sérialisée par
  le verrou.

---

*Documentation à jour au commit `6c3f6e8`.*
