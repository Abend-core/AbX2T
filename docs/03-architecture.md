# 03 — Architecture

Tout le comportement décrit ici est implémenté dans [`src/Program.cs`](../src/Program.cs)
(un seul fichier, sans dépendance externe).

## Déroulé d'une conversion

1. **Parsing CLI** — options, validation des extensions contre les listes
   `InputExtensions`/`OutputExtensions`, refus de source == sortie.
2. **Résolution du dossier de base** — le dossier de l'exe s'il est inscriptible, sinon
   le dossier de données utilisateur (`LocalApplicationData/Abx2t`).
3. **Verrou de préparation** — fichier `.abx2t.lock` ouvert en exclusif
   (`FileShare.None`, verrou réel sous Windows, `flock` sous Unix) : deux instances
   lancées en même temps sur une machine vierge ne s'extraient pas l'une sur l'autre.
   Une fois les composants prêts, les conversions elles-mêmes tournent en parallèle
   librement (chacune a son dossier de travail).
4. **Composants prêts ?** — extraction et polices, voir cycle de vie ci-dessous.
5. **Dossier de travail** — `TEMP/x2t_convert_<guid>/` : config XML + dossier scratch
   de x2t. Toujours supprimé à la fin (best-effort : un handle résiduel, antivirus par
   exemple, ne transforme pas une conversion réussie en crash).
6. **Config XML** — écrite via `XmlWriter` (échappement garanti) :

   ```xml
   <TaskQueueDataConvert>
     <m_sFileFrom>…</m_sFileFrom>       <!-- source (locale ou copie stagée) -->
     <m_sFileTo>…</m_sFileTo>           <!-- sortie -->
     <m_sAllFontsPath>…</m_sAllFontsPath>  <!-- allfonts/AllFonts.js -->
     <m_sFontDir>…</m_sFontDir>
     <m_sThemeDir>…</m_sThemeDir>       <!-- resources/sdkjs -->
     <m_sTempDir>…</m_sTempDir>         <!-- workDir/temp -->
   </TaskQueueDataConvert>
   ```

   `m_sTempDir` est toujours fourni : sans lui, x2t crée un dossier `ascXXXXXX` à côté
   du fichier de sortie et peut ne pas le supprimer en cas d'erreur (bug de nettoyage
   upstream).
7. **x2t en sous-processus** — stdout/stderr drainés en concurrence (les lire l'un
   après l'autre peut interbloquer si x2t remplit l'autre pipe), attente bornée par le
   timeout (défaut 30 min ; au dépassement : kill de l'arbre de processus, code 3).
8. **Staging réseau** — uniquement si le chemin est UNC ou sur un lecteur réseau
   Windows : la source est copiée dans le dossier de travail avant conversion, la
   sortie copiée vers la destination après. x2t ne touche jamais un partage
   directement. Les chemins locaux sont passés tels quels (aucune copie).

## Cycle de vie auto-réparant des composants

Principe : **le marqueur de complétude est toujours écrit en dernier**. Un plantage à
n'importe quel moment de la préparation laisse un état sans marqueur, donc refait
proprement au lancement suivant. Aucune détection de crash n'est nécessaire.

### `resources/` — marqueur `.version`

Écrit après une extraction réussie, contient la version du bundle (injectée depuis
[`VERSIONS`](../VERSIONS) au build). Au lancement, ré-extraction complète (wipe +
extraction) si :

- `x2t` absent (première installation) ;
- `.version` absent (extraction précédente interrompue) ;
- `.version` ≠ version embarquée (l'utilisateur a remplacé l'exe par une mise à jour —
  les composants suivent automatiquement, et `--license` reste cohérent avec la réalité).

### `allfonts/` — manifeste `fonts.manifest`

Écrit après une génération réussie. Contient la version du bundle + une ligne
`chemin|taille|mtime` par fichier de `custom-fonts/` (triées). Au lancement, l'état
courant est recalculé et comparé octet à octet ; régénération si :

- `AllFonts.js` ou le manifeste absent (premier lancement, plantage, ou suppression
  manuelle pour forcer une regénération) ;
- le manifeste diffère (police ajoutée, supprimée **ou** modifiée dans `custom-fonts/`) ;
- la version du bundle a changé (le manifeste embarque la version ; de plus la
  ré-extraction supprime le manifeste, car elle efface la copie
  `resources/sdkjs/common/AllFonts.js` que la génération restaure).

Le manifeste est supprimé **avant** de lancer la génération : si elle plante en
laissant un `AllFonts.js` corrompu, l'absence de manifeste force la régénération au
prochain lancement.

## Détails par plateforme

### Extraction de `assets.zip`

- **Windows / Linux** : `System.IO.Compression.ZipArchive`. Sur Linux, les bits
  exécutables stockés dans le zip (voir `build/package_linux.sh`) sont restaurés, et
  `Program.cs` re-chmod `x2t`/`allfontsgen` par sécurité ; x2t résout ses `.so` via son
  RPATH `$ORIGIN` (tout est côte à côte dans `resources/`).
- **macOS** : `ditto -x -k`, pas `ZipArchive` — les `.framework` reposent sur des
  symlinks (`Versions/Current → A`) et sur les attributs étendus de leur signature,
  que `ZipArchive` ne restaure pas (il écrirait des fichiers ordinaires contenant le
  texte de la cible, cassant silencieusement la résolution dyld). L'archive est
  construite par `ditto` côté packaging pour la même raison.

### Compression NTFS (Windows)

Après extraction, `compact.exe /c /s /i /q` est lancé en **fire-and-forget** sur
`resources/` : la compression NTFS est transparente (x2t lit les fichiers pendant
qu'elle tourne), donc le premier lancement n'attend pas. Le flag du dossier est hérité :
les fichiers ajoutés ensuite (AllFonts.js copié dans sdkjs/common) sont compressés
aussi. Best-effort : ignoré sans NTFS (FAT32, exFAT, partages).

### `DoctRenderer.config`

Configure les chemins JS relatifs de x2t. Deux variantes, régénérées par leurs scripts
respectifs (rien à préserver à la main) :

- dans `x2t/bin/<os-arch>/` (scripts de sync) : pointe vers `../../sdkjs/` ;
- dans `resources/` (assets.zip, scripts de packaging) : pointe vers `./sdkjs/`
  (x2t et sdkjs y sont côte à côte).

## Versions injectées au build

`src/Abx2t.csproj` (cible MSBuild `ReadBundleVersions`) lit [`VERSIONS`](../VERSIONS) et
injecte `ONLYOFFICE_VERSION` / `ONLYOFFICE_CORE_BUILD` comme métadonnées d'assembly, lues
au runtime par `Program.cs` (notice `--license`, `--version`, marqueur `.version`).
`VERSIONS` est déclaré comme entrée d'incrémentalité : bumper le fichier suffit, même
sans rebuild complet. Aucune version n'est codée en dur dans le code.

---

*Documentation à jour au commit `6c3f6e8`.*
