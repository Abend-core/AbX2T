# 02 — Utilisation

## Installation

Il n'y en a pas : `Abx2t.exe` (Windows) ou `Abx2t` (macOS/Linux) est le seul fichier à
récupérer. Le poser où l'on veut et le lancer.

Au **premier lancement**, l'exécutable s'auto-installe à côté de lui :

```
Abx2t.exe
resources/      ← extrait automatiquement (x2t, DLLs/frameworks/.so, sdkjs/, licences)
allfonts/       ← généré automatiquement (index des polices de la machine)
custom-fonts/   ← créé vide : y déposer des .ttf/.otf à utiliser sans les installer
```

Si le dossier de l'exécutable n'est pas inscriptible (`C:\Program Files`,
`/usr/local/bin`…), ces dossiers vont dans le répertoire de données utilisateur
(`%LOCALAPPDATA%\Abx2t`, `~/Library/Application Support/Abx2t`, `~/.local/share/Abx2t`)
— un message l'indique au lancement.

> **Windows SmartScreen / macOS Gatekeeper** : l'exécutable n'est pas signé. Windows
> affichera « application non reconnue » (Informations complémentaires → Exécuter quand
> même) ; macOS mettra le fichier téléchargé en quarantaine
> (`xattr -d com.apple.quarantine ./Abx2t`). Vérifier le SHA-256 publié avec la release
> avant de passer outre.

## Convertir

```
Abx2t [options] <source> <sortie>
Abx2t [options] --to <ext> <sources...> <dossier_sortie>
```

Le format est déduit des extensions (ou de `--to` en mode batch). Exemples :

```powershell
.\Abx2t.exe rapport.docx rapport.pdf
.\Abx2t.exe classeur.xlsx donnees.csv
.\Abx2t.exe presentation.pptx presentation.odp
.\Abx2t.exe "\\serveur\partage\entrant.docx" "\\serveur\partage\sorti.pdf"

# Batch : plusieurs sources (wildcards acceptés, meme sous cmd/PowerShell)
# converties en parallèle vers un dossier, chacune sous son propre nom
.\Abx2t.exe --to pdf *.docx sortie\
.\Abx2t.exe --to pdf --jobs 4 rapport.docx classeur.xlsx sortie\
```

### Options

| Option | Effet |
|---|---|
| `--to <ext>` | Mode batch : format de sortie ; chaque source est convertie dans le dossier cible sous son propre nom |
| `--jobs <n>` | Mode batch : conversions en parallèle (défaut : 2 à 4 selon le CPU) |
| `--timeout <minutes>` | Durée maximale de la conversion, par fichier (défaut : 30 ; `0` = illimité) |
| `--verbose` | Affiche la sortie de x2t même quand la conversion réussit |
| `--version` | Version d'Abx2t et du bundle ONLYOFFICE embarqué |
| `--license` | Licence AGPLv3 et attribution ONLYOFFICE |
| `--help` | Aide complète |

### Codes retour

| Code | Signification |
|---|---|
| 0 | Succès |
| 1 | Erreur d'usage ou du wrapper (fichier introuvable, format refusé, source = sortie…) |
| 2 | Erreur du moteur x2t (fichier corrompu, conversion impossible) |
| 3 | Timeout dépassé (x2t a été tué) |

En mode batch, chaque fichier est converti indépendamment : un résumé
(`Done: X/Y succeeded`) est affiché et le code retour est le pire code rencontré
(0 seulement si toutes les conversions ont réussi). Deux sources qui produiraient le
même fichier de sortie (même nom de base) sont refusées d'emblée.

## Formats supportés

Les listes viennent de la table officielle des formats ONLYOFFICE
(`core-master/Common/OfficeFileFormats.h`), restreinte aux familles couvertes par les
binaires du bundle. Le bundle embarque tout ce qu'ONLYOFFICE sait lire/écrire — pas
d'édition allégée : les DLL de x2t s'importent statiquement (un seul fichier manquant
empêche x2t de démarrer) et dominent largement le poids total, alléger le JS ne
changerait presque rien.

### Entrée (lecture)

| Famille | Extensions |
|---|---|
| Document | doc, docx, docm, dotx, dotm, odt, ott, rtf, txt, html, mht, epub, fb2, mobi, hwp, hwpx, md |
| Présentation | ppt, pptx, pptm, ppsx, ppsm, potx, potm, odp, otp |
| Tableur | xls, xlsx, xlsm, xltx, xltm, xlsb, ods, ots, csv |
| Multiplateforme | pdf, djvu, xps, ofd |
| Dessin | vsdx, vssx, vstx, vsdm, vssm, vstm |

### Sortie (écriture)

docx, odt, rtf, txt, html, pdf, pptx, odp, xlsx, ods, csv, xps

Les formats legacy binaires (doc, ppt, xls) et e-book/scan (epub, fb2, mobi, djvu) sont
lus mais jamais réécrits par ONLYOFFICE (round-trip toujours vers OOXML/ODF). `.vsdx`
n'est pas en sortie : le support en écriture n'a pas été confirmé.

### Ce qui a été testé

Conversions réelles exécutées et sorties vérifiées : docx→pdf, xlsx→pdf, pptx→pdf,
xlsx→csv, pptx→odp, docx→odt, docx→txt, docx→html, docx→rtf. Le smoke test
(`build/smoke_test.sh`) rejoue docx→pdf et docx→txt à chaque validation. Les autres
combinaisons de la matrice n'ont pas été testées individuellement — vérifier avec un
fichier réel avant de garantir une combinaison précise.

## Polices

x2t n'utilise pas directement les polices du système : il lit un index (`AllFonts.js`)
généré au premier lancement à partir des polices installées (système + utilisateur)
**et** du dossier `custom-fonts/`.

- **Ajouter une police sans l'installer** : déposer le .ttf/.otf dans `custom-fonts/`.
  L'index est régénéré automatiquement à la prochaine conversion (tout ajout,
  suppression ou modification dans ce dossier est détecté).
- **Police installée dans le système après coup** : supprimer `allfonts/AllFonts.js` et
  relancer une conversion — l'index est reconstruit.
- **En conteneur sans polices système** : déposer au moins une police dans
  `custom-fonts/`.

## Chemins réseau

Source et sortie peuvent être des chemins UNC (`\\serveur\partage\...`) ou un lecteur
réseau mappé. Dans ce cas le fichier est copié localement avant conversion et le
résultat copié vers la destination à la fin : x2t ne lit/n'écrit jamais directement sur
le partage (pas de verrous SMB, pas d'écriture partielle en cas de coupure). Les chemins
locaux, eux, sont convertis sur place, sans copie intermédiaire.

## Dépannage

| Symptôme | Cause probable | Remède |
|---|---|---|
| Conversion qui ne finit jamais | Fichier malformé, x2t figé | Le timeout (30 min) le tue avec le code 3 ; `--timeout` pour ajuster |
| Sortie produite mais étrange | Voir ce que dit x2t | Relancer avec `--verbose` |
| Police manquante dans le rendu | Index de polices obsolète | Supprimer `allfonts/AllFonts.js`, relancer |
| Composants suspects/corrompus | Extraction interrompue | Supprimer `resources/`, relancer (ré-extraction complète) ; c'est automatique si le marqueur `resources/.version` manque |
| « Another Abx2t instance is preparing components » | Deux lancements simultanés sur machine vierge | Normal : l'un prépare, l'autre attend puis convertit |
| Premier lancement refusé (droits) | Dossier non inscriptible | Automatique : les composants vont dans le dossier de données utilisateur (message affiché) |

---

*Documentation à jour au commit `1fe36b8`.*
