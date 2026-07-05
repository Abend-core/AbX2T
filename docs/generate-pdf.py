#!/usr/bin/env python3
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Assemble les fichiers 00-08 de docs/ en un PDF unique via pandoc.

Usage : python3 docs/generate-pdf.py
Sortie : docs/PDF/documentation-abx2t.pdf (dossier gitignore)

Prerequis : pandoc + un moteur PDF (essaye dans l'ordre : wkhtmltopdf,
weasyprint, xelatex, pdflatex).
"""

import glob
import os
import shutil
import subprocess
import sys

DOCS = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(DOCS, "PDF")
OUT = os.path.join(OUT_DIR, "documentation-abx2t.pdf")

ENGINES = ["wkhtmltopdf", "weasyprint", "xelatex", "pdflatex"]


def main() -> int:
    if shutil.which("pandoc") is None:
        print("pandoc introuvable. Installer pandoc (https://pandoc.org) et un moteur")
        print("PDF (wkhtmltopdf, weasyprint ou LaTeX), puis relancer.")
        return 1

    engine = next((e for e in ENGINES if shutil.which(e)), None)
    if engine is None:
        print(f"Aucun moteur PDF trouve (essaye : {', '.join(ENGINES)}).")
        print("En installer un, par exemple : brew install wkhtmltopdf / apt install weasyprint")
        return 1

    sources = sorted(glob.glob(os.path.join(DOCS, "0[0-8]-*.md")))
    if len(sources) < 9:
        print(f"Fichiers 00-08 incomplets dans {DOCS} ({len(sources)} trouves).")
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)
    cmd = [
        "pandoc", *sources,
        "-o", OUT,
        f"--pdf-engine={engine}",
        "--from", "gfm",
        "--toc", "--toc-depth=2",
        "--metadata", "title=AbX2T - Documentation",
        "-V", "geometry:margin=2.2cm",
        "-V", "lang=fr",
    ]
    print(" ".join(cmd))
    result = subprocess.run(cmd)
    if result.returncode == 0:
        print(f"OK : {OUT}")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
