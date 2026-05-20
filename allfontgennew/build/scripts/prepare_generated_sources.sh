#!/usr/bin/env zsh

set -euo pipefail

repo=$(cd -- "${0:A:h}/../.." && pwd)
generated_root="$repo/build/generated"
generated_file="$generated_root/src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp"

mkdir -p "${generated_file:h}"
rm -f "$generated_file" "$generated_file.orig" "$generated_file.rej"
cp "$repo/src/DesktopEditor/fontengine/ApplicationFontsWorker.cpp" "$generated_file"

perl -0pi -e '
my $old_includes = q~#include "../graphics/pro/Fonts.h"
#include "../raster/BgraFrame.h"
#include "../graphics/pro/Graphics.h"~;
my $new_includes = qq~#include "../graphics/pro/Fonts.h"
#ifndef ALLFONTSGEN_DISABLE_THUMBNAILS
#include "../raster/BgraFrame.h"
#include "../graphics/pro/Graphics.h"
#endif~;
s/\Q$old_includes\E/$new_includes/s or die "failed to patch thumbnail includes\n";

my $old_entry = q~	void SaveThumbnails(NSFonts::IApplicationFonts* applicationFonts)
	{
		std::vector<std::wstring> arrFiles;~;
my $new_entry = qq~	void SaveThumbnails(NSFonts::IApplicationFonts* applicationFonts)
	{
#ifdef ALLFONTSGEN_DISABLE_THUMBNAILS
		(void)applicationFonts;
		return;
#else
		std::vector<std::wstring> arrFiles;~;
s/\Q$old_entry\E/$new_entry/s or die "failed to patch thumbnail entry\n";

my $old_exit = q~		if (applicationFonts == NULL)
			RELEASEOBJECT(applicationFontsGood);
	}
};~;
my $new_exit = qq~		if (applicationFonts == NULL)
			RELEASEOBJECT(applicationFontsGood);
#endif
	}
};~;
s/\Q$old_exit\E/$new_exit/s or die "failed to patch thumbnail exit\n";
' "$generated_file"

echo "$generated_root"
