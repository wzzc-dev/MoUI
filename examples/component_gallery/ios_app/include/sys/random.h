#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int moui_ios_getentropy(void *buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif
