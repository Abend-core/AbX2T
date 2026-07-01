#pragma once

/* Include standard FreeType options */
#include <freetype/config/ftoption.h>

/* Disable zlib: we don't need gzip-compressed font streams */
#ifdef FT_CONFIG_OPTION_USE_ZLIB
#undef FT_CONFIG_OPTION_USE_ZLIB
#endif
