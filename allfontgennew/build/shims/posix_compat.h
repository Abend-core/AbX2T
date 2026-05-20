#pragma once

#if defined(__APPLE__) || defined(__linux__) || defined(_MAC) || defined(MAC) || defined(_LINUX)
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <utime.h>
#endif
