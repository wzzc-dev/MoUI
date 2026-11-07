/*
 * Minimal sys/random.h shim for iOS SDKs: env.c includes it for getentropy.
 * The header is absent from the iOS Simulator SDK but the getentropy symbol
 * exists in libSystem.
 */
#ifndef MOUI_COMPAT_SYS_RANDOM_H
#define MOUI_COMPAT_SYS_RANDOM_H
#include <stddef.h>
extern int getentropy(void *buffer, size_t size);
#endif
