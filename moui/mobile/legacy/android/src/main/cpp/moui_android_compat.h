#pragma once

#if defined(__ANDROID__) && (!defined(__ANDROID_API__) || __ANDROID_API__ < 28)
#include <stddef.h>

int getentropy(void *buffer, size_t buffer_size);
#endif
