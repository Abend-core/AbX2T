#pragma once

#if defined(__APPLE__) || defined(__linux__) || defined(_MAC) || defined(MAC) || defined(_LINUX)
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <utime.h>
#endif

#ifdef _WIN32
/* Disable zlib dependency in FreeType — we don't need gzip font support */
#ifdef FT_CONFIG_OPTION_USE_ZLIB
#undef FT_CONFIG_OPTION_USE_ZLIB
#endif
#endif
