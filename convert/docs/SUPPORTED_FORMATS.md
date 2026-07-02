# Formats supportes

`Abx2t.exe` embarque tout ce qu'ONLYOFFICE sait lire/ecrire sur ce poste : `x2t/bin/` (109 Mo de
DLL, verifie incompressible -- un seul DLL manquant fait planter x2t.exe au demarrage, import
statique Windows, pas de plugin a la demande) et `x2t/sdkjs/` complet (common, word, cell, slide,
visio, pdf, vendor). Pas d'edition allegee : le poids des DLL domine largement celui du JS, donc
retirer des modules sdkjs ne changeait quasiment rien a la taille finale (voir historique de
`convert/build/package_windows.ps1`).

Les listes ci-dessous (`Program.cs`, constantes `InputExtensions`/`OutputExtensions`) viennent de
`core-master/Common/OfficeFileFormats.h`, la table officielle des formats ONLYOFFICE, restreinte
aux familles couvertes par les DLL/sdkjs presents dans ce bundle.

## Entree (lecture)

Document : doc, docx, docm, dotx, dotm, odt, ott, rtf, txt, html, mht, epub, fb2, mobi, hwp, hwpx, md
Presentation : ppt, pptx, pptm, ppsx, ppsm, potx, potm, odp, otp
Tableur : xls, xlsx, xlsm, xltx, xltm, xlsb, ods, ots, csv
Multiplateforme : pdf, djvu, xps, ofd
Dessin : vsdx, vssx, vstx, vsdm, vssm, vstm

## Sortie (ecriture)

docx, odt, rtf, txt, html, pdf, pptx, odp, xlsx, ods, csv, xps

Les formats legacy binaires (doc, ppt, xls) et e-book/scan (epub, fb2, mobi, djvu) sont lus mais
jamais reecrits par ONLYOFFICE (round-trip toujours vers OOXML/ODF). `.vsdx` n'est pas dans la
liste de sortie : le support en ecriture n'a pas ete confirme.

## Ce qui a ete teste

Conversions reelles executees, fichiers de sortie non vides verifies : docx → pdf, xlsx → pdf,
pptx → pdf, xlsx → csv, pptx → odp, docx → odt, docx → txt, docx → html, docx → rtf.

Le reste des combinaisons de la liste ci-dessus (ex: pptx → xlsx, qui n'a de toute facon aucun
sens ; ou les entrees djvu/xps/vsdx) n'a pas ete teste individuellement. A verifier avec un
fichier reel avant de garantir une combinaison precise.
