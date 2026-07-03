# TODO

## Linux sans dependance glibc

Actuellement le bundle Linux depend de la glibc (plancher glibc 2.34 impose par
NativeAOT, voir convert/README.md). Deux options envisagees pour s'en affranchir :

1. Recompiler x2t depuis les sources completes ONLYOFFICE/core avec un toolchain
   musl (gros chantier : x2t est aujourd'hui recupere precompile depuis le .deb
   officiel via x2t/build/scripts/sync_from_release_linux.sh, pas compile depuis
   les sources ici -- contrairement a allfontsgen qui, lui, l'est deja).
2. Garder le binaire glibc tel quel et cibler un environnement musl + `gcompat`
   (paquet Alpine qui fournit un shim glibc), sans recompilation.

## Documentation

Faire une passe de documentation propre (README, convert/README.md, x2t/docs/,
THIRD-PARTY-NOTICES.md) : verifier coherence, a jour, pas de doublons entre les
differents README.

## Structure

Revoir la structure du repo (organisation des dossiers allfontsgen/ convert/ x2t/
core-master/, scripts de build).
