# convert

Wrapper Windows autonome (`Abx2t.exe`) pour convertir des documents via `x2t.exe` (ONLYOFFICE).
Formats acceptes en entree/sortie : voir [docs/SUPPORTED_FORMATS.md](docs/SUPPORTED_FORMATS.md).

## Usage

```powershell
.\Abx2t.exe "rapport.docx" "rapport.pdf"
```

Lancer sans argument affiche les extensions acceptees :

```
Usage: Abx2t.exe <source> <sortie>
  Entree acceptee : .doc, .docx, ...
  Sortie acceptee : .pdf, .docx, ...
```

Source et destination peuvent etre des chemins reseau (`\\serveur\partage\...`) ou un lecteur
mappe (`D:\...`) : le fichier source est copie en local (TEMP systeme) avant conversion, et le
fichier final est copie vers la destination reelle une fois la conversion terminee. Ca evite de
faire dependre x2t.exe du comportement d'un partage SMB (verrous, latence, ecriture partielle
en cas d'erreur reseau).

## Premier lancement

`Abx2t.exe` est le seul fichier a distribuer. Au premier lancement, a cote de l'exe :

```
Abx2t.exe
resources\   <- extrait automatiquement de assets.zip (x2t.exe, DLLs, allfontsgen.exe, sdkjs\, dictionaries\)
allfonts\    <- genere automatiquement (AllFonts.js, font_selection.bin, specifique a la machine)
```

Aucune installation manuelle requise. Pour forcer une regeneration des polices (nouvelle police
installee sur le poste), supprimer `allfonts\AllFonts.js` et relancer une conversion.

Le dossier de travail de la conversion elle-meme (config XML + dossier temp de x2t) est cree
dans le TEMP systeme et toujours supprime a la fin (succes ou erreur) : rien ne persiste a cote
de l'exe ni du fichier de sortie.

## Reconstruire assets.zip (mainteneurs)

`assets.zip` (`convert/convert/assets.zip`, ressource embarquee par `convert.csproj`) n'est pas
versionne. Pour le reconstruire :

```powershell
# 1. Recuperer x2t.exe + DLLs + sdkjs depuis une install ONLYOFFICE Desktop locale
powershell -ExecutionPolicy Bypass -File ..\x2t\build\scripts\sync_from_install_windows.ps1

# 2. Assembler assets.zip (compile allfontsgen.exe si absent)
powershell -ExecutionPolicy Bypass -File build\package_windows.ps1

# 3. Builder Abx2t.exe
dotnet publish convert\convert.csproj -c Release
```

## Architecture

- `convert/convert/Program.cs` : logique C# (validation des formats, extraction, generation des
  polices, appel x2t.exe, staging reseau).
- `convert/convert/convert.csproj` : `AssemblyName` = `Abx2t`, build self-contained single-file
  (`win-x64`).
- `convert/build/package_windows.ps1` : assemble `assets.zip` a partir de `x2t/bin/windows-x86_64/`
  (integral, voir docs/SUPPORTED_FORMATS.md) + `x2t/sdkjs/` (integral) + `x2t/dictionaries/` +
  `allfontgennew/build/bin/windows-x86_64/allfontsgen.exe`.
