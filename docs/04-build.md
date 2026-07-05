# 04 — Build

Pipeline complet, identique sur les trois OS :

```
1. fetch_onlyoffice_<os>     → x2t/bin/<os-arch>/ + x2t/sdkjs/   (télécharge la release officielle)
2. build allfontsgen          → allfontsgen/build/bin/<os-arch>/  (compile depuis core-master)
3. generate polices           → AllFonts.js copié dans x2t/sdkjs/common/
4. package_<os>               → src/assets.zip                    (x2t + sdkjs + allfontsgen + licences)
5. dotnet publish (NativeAOT) → l'exécutable distribuable
6. smoke test                 → validation de bout en bout
```

Les étapes 2–3 ne sont nécessaires qu'une fois par machine (ou après une montée de
version) : le binaire `allfontsgen` produit est réutilisé par les packagings suivants.

## Prérequis

| | Windows x86_64 | macOS arm64 | Linux x86_64 |
|---|---|---|---|
| SDK .NET (10+) | ✔ | ✔ | ✔ |
| Toolchain C++ (NativeAOT + allfontsgen) | Visual Studio 2019+ workload C++ | Xcode Command Line Tools | `gcc`/`g++` ou clang |
| Divers | PowerShell 5.1+ | `zsh` (inclus) | `bash`, `python3`, `dpkg-deb` |
| `core-master/` à la racine | ✔ (pour compiler allfontsgen) | ✔ | ✔ |

`core-master/` = checkout des sources <https://github.com/ONLYOFFICE/core> au tag indiqué
dans [`VERSIONS`](../VERSIONS) (non versionné ici).

## macOS

```sh
zsh build/fetch_onlyoffice_macos.sh                      # 1. binaires ONLYOFFICE (hash vérifié)
cd allfontsgen && zsh build/scripts/build_macos.sh       # 2. compile allfontsgen
zsh build/scripts/generate_macos.sh && cd ..             # 3. génère les polices
cp allfontsgen/output/macos-arm64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
zsh build/package_macos.sh                               # 4. assemble src/assets.zip
dotnet publish src/Abx2t.csproj -c Release -r osx-arm64  # 5. exe NativeAOT
bash build/smoke_test.sh src/bin/Release/net10.0/osx-arm64/publish/Abx2t   # 6. validation
```

## Windows

```powershell
powershell -ExecutionPolicy Bypass -File build\fetch_onlyoffice_windows.ps1   # 1
cd allfontsgen; powershell -ExecutionPolicy Bypass -File build\scripts\build_windows.ps1      # 2
powershell -ExecutionPolicy Bypass -File build\scripts\generate_windows.ps1; cd ..           # 3
Copy-Item allfontsgen\output\windows-x86_64\fonts\AllFonts.js x2t\sdkjs\common\AllFonts.js
powershell -ExecutionPolicy Bypass -File build\package_windows.ps1            # 4
dotnet publish src\Abx2t.csproj -c Release                                    # 5
powershell -ExecutionPolicy Bypass -File build\smoke_test.ps1 -ExePath src\bin\Release\net10.0\win-x64\publish\Abx2t.exe  # 6
```

Si la détection de MSVC échoue (`'vswhere.exe' n'est pas reconnu`), publier depuis un
environnement Developer :

```powershell
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && dotnet publish src\Abx2t.csproj -c Release -p:IlcUseEnvironmentalTools=true'
```

(vcvars définit `Platform=x64` : la sortie va alors dans `src\bin\x64\Release\...\publish\`.)

## Linux

```sh
bash build/fetch_onlyoffice_linux.sh                       # 1
cd allfontsgen && bash build/scripts/build_linux.sh        # 2
bash build/scripts/generate_linux.sh && cd ..              # 3
cp allfontsgen/output/linux-x86_64/fonts/AllFonts.js x2t/sdkjs/common/AllFonts.js
bash build/package_linux.sh                                # 4
dotnet publish src/Abx2t.csproj -c Release -r linux-x64    # 5  (-p:CppCompilerAndLinker=gcc si clang absent)
bash build/smoke_test.sh src/bin/Release/net10.0/linux-x64/publish/Abx2t   # 6
```

### Compatibilité glibc / conteneurs

L'exe produit ne dépend que de la glibc : x2t résout ses `.so` via son RPATH `$ORIGIN`,
allfontsgen est lié avec `-static-libstdc++`, et l'exe NativeAOT n'a besoin ni de
libstdc++ ni d'ICU (`InvariantGlobalization`).

Plancher glibc mesuré : x2t et allfontsgen acceptent une glibc ancienne (2.14) ; le
plancher réel du bundle est celui du runtime .NET NativeAOT, **glibc 2.34** (identique
quel que soit l'OS de build). Couvre Ubuntu 22.04+, Debian 12+, RHEL 9+ et les images
distroless actuelles — testé sur `debian:12-slim` et `gcr.io/distroless/base-debian12`
(pas besoin de `/bin/sh` ni de libstdc++). Prévoir un volume ou WORKDIR inscriptible pour
`resources/` et `allfonts/`, et au moins une police dans `custom-fonts/` si l'image n'a
pas de polices système. En dessous de glibc 2.34, seul le fallback JIT fonctionne.

## Notes de publication

- **NativeAOT ne cross-compile pas** : publier sur l'OS cible, avec sa toolchain native.
- **Fallback JIT** sans toolchain native : `dotnet publish -p:PublishAot=false` produit
  un single-file compressé sensiblement plus gros et nécessitant le runtime, mais
  fonctionnel partout.
- Le RID par défaut suit l'OS de build (`win-x64`/`osx-arm64`/`linux-x64`) ; `-r` pour
  forcer (ex. `-r osx-x64` sur un Mac Intel).

## Fallback manuel (sans les scripts fetch)

Si les URL de téléchargement cassent ou qu'ONLYOFFICE change de canal de distribution,
les scripts de sync s'utilisent directement avec une source obtenue à la main :

```sh
# macOS : dossier Resources/ d'une release (DesktopEditors.app/Contents/Resources)
zsh x2t/build/scripts/sync_from_release_macos.sh [--dry-run] /chemin/vers/Resources
# Linux : .deb officiel ou dossier déjà extrait (/opt/onlyoffice/desktopeditors)
bash x2t/build/scripts/sync_from_release_linux.sh [--dry-run] /chemin/vers/le.deb
```

```powershell
# Windows : installation locale ONLYOFFICE Desktop Editors
powershell -ExecutionPolicy Bypass -File x2t\build\scripts\sync_from_install_windows.ps1 [-DryRun] [-InstallDir "..."]
```

Les scripts vérifient la présence des JS obligatoires avant d'écrire, préservent
`x2t/sdkjs/common/AllFonts.js` s'il existe déjà, et régénèrent `DoctRenderer.config`.

---

*Documentation à jour au commit `b3ddb7b`.*
