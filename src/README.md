# convert

Wrapper autonome (`Abx2t`) pour convertir des documents via `x2t` (ONLYOFFICE), Windows, macOS et Linux.
Formats acceptes en entree/sortie : voir [docs/SUPPORTED_FORMATS.md](../docs/SUPPORTED_FORMATS.md).

## Usage

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

Lancer sans argument affiche les extensions acceptees :

```
Usage: Abx2t.exe <source> <output>
  Accepted input  : .doc, .docx, ...
  Accepted output : .pdf, .docx, ...
  Abx2t.exe --license : AGPLv3 license and ONLYOFFICE attribution
```

`Abx2t.exe --license` prints the license (AGPLv3) and attribution for the bundled ONLYOFFICE
components (x2t, sdkjs) — full detail in [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md)
at the root of the repository.

Source et destination peuvent etre des chemins reseau (`\\serveur\partage\...`) ou un lecteur
mappe (`D:\...`) : le fichier source est copie en local (TEMP systeme) avant conversion, et le
fichier final est copie vers la destination reelle une fois la conversion terminee. Ca evite de
faire dependre x2t.exe du comportement d'un partage SMB (verrous, latence, ecriture partielle
en cas d'erreur reseau).

## Premier lancement

`Abx2t.exe` est le seul fichier a distribuer. Au premier lancement, a cote de l'exe :

```
Abx2t.exe
resources\      <- extrait automatiquement de assets.zip (x2t.exe, DLLs, allfontsgen.exe, sdkjs\)
allfonts\       <- genere automatiquement (AllFonts.js, font_selection.bin, specifique a la machine)
custom-fonts\   <- cree automatiquement, vide. Deposer ici des .ttf/.otf a utiliser sans les installer sur le poste.
```

Aucune installation manuelle requise. Les polices systeme (Windows + utilisateur courant) et
celles deposees dans `custom-fonts\` sont indexees ensemble dans `AllFonts.js`. Ajouter un fichier
dans `custom-fonts\` declenche automatiquement une regeneration a la prochaine conversion (detection
par date de modification). Pour forcer une regeneration complete (ex. police systeme mise a jour),
supprimer `allfonts\AllFonts.js` et relancer une conversion.

`resources\` est compresse NTFS a l'extraction (transparent pour x2t, ~99 Mo sur disque au
lieu de ~167 Mo) ; sans NTFS (FAT32, partage reseau), la compression est simplement ignoree.

Le dossier de travail de la conversion elle-meme (config XML + dossier temp de x2t) est cree
dans le TEMP systeme et toujours supprime a la fin (succes ou erreur) : rien ne persiste a cote
de l'exe ni du fichier de sortie.

## Reconstruire assets.zip (mainteneurs)

`assets.zip` (`src/assets.zip`, ressource embarquee par `convert.csproj`) n'est pas
versionne. Pour le reconstruire :

### Windows

```powershell
# 1. Recuperer x2t.exe + DLLs + sdkjs depuis une install ONLYOFFICE Desktop locale
powershell -ExecutionPolicy Bypass -File x2t\build\scripts\sync_from_install_windows.ps1

# 2. Assembler assets.zip (compile allfontsgen.exe si absent)
powershell -ExecutionPolicy Bypass -File build\package_windows.ps1

# 3. Builder Abx2t.exe (NativeAOT : necessite la toolchain C++ de l'OS, voir ci-dessous)
dotnet publish src\Abx2t.csproj -c Release
```

### macOS

```sh
# 1. Recuperer x2t + frameworks + sdkjs depuis une release officielle ONLYOFFICE
zsh x2t/build/scripts/sync_from_release.sh /chemin/vers/Resources

# 2. Assembler assets.zip (compile allfontsgen si absent ; utilise ditto pour preserver
#    les symlinks des .framework -- voir Architecture ci-dessous)
zsh build/package_macos.sh

# 3. Builder Abx2t (NativeAOT osx-arm64)
dotnet publish src/Abx2t.csproj -c Release -r osx-arm64
```

### Linux

```sh
# 1. Recuperer x2t + .so + sdkjs depuis le .deb officiel ONLYOFFICE Desktop Editors
#    (version alignee sur le bundle : onlyoffice-desktopeditors_9.4.0_amd64.deb, depuis
#     https://download.onlyoffice.com/repo/debian/pool/main/o/onlyoffice-desktopeditors/)
bash x2t/build/scripts/sync_from_release_linux.sh /chemin/vers/onlyoffice-desktopeditors_9.4.0_amd64.deb

# 2. Assembler assets.zip (compile allfontsgen si absent ; zip construit en preservant
#    les bits executables, restaures par .NET a l'extraction)
bash build/package_linux.sh

# 3. Builder Abx2t (NativeAOT linux-x64 ; ajouter -p:CppCompilerAndLinker=gcc si clang absent)
dotnet publish src/Abx2t.csproj -c Release -r linux-x64
```

L'exe produit ne depend que de la glibc : x2t resout ses `.so` via son RPATH `$ORIGIN`
(elles sont extraites a cote de lui dans `resources/`), allfontsgen est lie avec
`-static-libstdc++`, et l'exe NativeAOT n'a besoin ni de libstdc++ ni d'ICU
(`InvariantGlobalization`). Le bundle tourne donc sur n'importe quelle distro glibc et dans
une image conteneur **distroless** (pas besoin de `/bin/sh`, aucune libstdc++ requise ;
prevoir un volume ou WORKDIR inscriptible a cote de l'exe pour `resources/` et `allfonts/`).
En conteneur sans police systeme, deposer au moins une police dans `custom-fonts/`.

Plancher glibc mesure (publish depuis un conteneur `mcr.microsoft.com/dotnet/sdk:10.0`,
Ubuntu 24.04) :
- `x2t` (binaire ONLYOFFICE precompile) : glibc **2.14**
- `allfontsgen` (compile ici, lie avec `-static-libstdc++`) : glibc **2.14**
- `Abx2t` (runtime NativeAOT .NET 10) : glibc **2.34** -- c'est le plancher reel du bundle,
  impose par le runtime .NET lui-meme (identique quel que soit l'OS de build, meme sur un
  conteneur tres recent). Couvre Ubuntu 22.04+, Debian 12+, RHEL 9+, et les images
  distroless actuelles -- teste avec succes sur `debian:12-slim` et
  `gcr.io/distroless/base-debian12`. En dessous (Debian 11/Ubuntu 20.04 et plus vieux),
  seul un fallback JIT (`-p:PublishAot=false`, ~97 Mo, necessite le runtime .NET) fonctionne.

### Build NativeAOT

Le publish compile en natif (NativeAOT) : exe ~58 Mo au lieu de ~133 Mo, demarrage instantane.
L'AOT ne cross-compile pas : publier **sur l'OS cible**, avec sa toolchain native installee
(MSVC sur Windows, Xcode CLT sur macOS, clang/gcc sur Linux).

Sur Windows, si la detection automatique de MSVC echoue (`'vswhere.exe' n'est pas reconnu`),
lancer le publish depuis un environnement Developer :

```powershell
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && dotnet publish src\Abx2t.csproj -c Release -p:IlcUseEnvironmentalTools=true'
```

(vcvars definit `Platform=x64` : la sortie va alors dans `src\bin\x64\Release\...\publish\`.)

Sans toolchain native disponible, fallback single-file JIT compresse (~97 Mo) :

```powershell
dotnet publish src\Abx2t.csproj -c Release -p:PublishAot=false
```

## Architecture

- `src/Program.cs` : logique C# cross-plateforme (validation des formats,
  extraction, generation des polices, appel x2t, staging reseau). Detection d'OS pour le nom
  des binaires (`x2t`/`x2t.exe`, `allfontsgen`/`allfontsgen.exe`). Sur macOS, extraction de
  `assets.zip` via `ditto` plutot que `System.IO.Compression.ZipArchive`, qui ne restaure pas
  les symlinks des `.framework` (`Versions/Current -> A`) et casserait leur resolution par dyld.
- `src/Abx2t.csproj` : `AssemblyName` = `Abx2t`, publish NativeAOT (exe natif
  unique, RID par defaut selon l'OS de build : `win-x64`/`osx-arm64`/`linux-x64`).
- `build/package_windows.ps1` : assemble `assets.zip` a partir de `x2t/bin/windows-x86_64/`
  (integral, voir docs/SUPPORTED_FORMATS.md) + `x2t/sdkjs/` (integral) +
  `allfontsgen/build/bin/windows-x86_64/allfontsgen.exe` + les textes de licence (`LICENSE`,
  `THIRD-PARTY-NOTICES.md`), extraits dans `resources\` au premier lancement pour que la
  distribution mono-exe reste autonome juridiquement. `build/package_macos.sh` est
  l'equivalent macOS (`x2t/bin/macos-arm64/`, `allfontsgen/build/bin/macos-arm64/`), assemble
  avec `ditto` (pas `zip`) pour preserver les symlinks des `.framework` a travers l'archive.
  `build/package_linux.sh` est l'equivalent Linux (`x2t/bin/linux-x86_64/`,
  `allfontsgen/build/bin/linux-x86_64/`), zip construit via python3 en stockant les modes
  Unix (bits executables restaures a l'extraction, et re-chmod par Program.cs par securite).
