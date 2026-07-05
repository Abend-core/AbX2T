# TODO

## Linux sans dependance glibc

Actuellement le bundle Linux depend de la glibc (plancher glibc 2.34 impose par
NativeAOT, voir src/README.md). Deux options envisagees pour s'en affranchir :

1. Recompiler x2t depuis les sources completes ONLYOFFICE/core avec un toolchain
   musl (gros chantier : x2t est aujourd'hui recupere precompile depuis le .deb
   officiel via x2t/build/scripts/sync_from_release_linux.sh, pas compile depuis
   les sources ici -- contrairement a allfontsgen qui, lui, l'est deja).
2. Garder le binaire glibc tel quel et cibler un environnement musl + `gcompat`
   (paquet Alpine qui fournit un shim glibc), sans recompilation.

## Documentation

Faire une passe de documentation propre (README, src/README.md, x2t/docs/,
THIRD-PARTY-NOTICES.md) : verifier coherence, a jour, pas de doublons entre les
differents README.

## Structure

Fait : le wrapper vit dans src/ (Abx2t.csproj), les scripts de packaging dans build/,
x2t/ et allfontsgen/ restent les deux composants.
