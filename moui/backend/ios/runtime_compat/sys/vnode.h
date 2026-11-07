/*
 * Minimal sys/vnode.h shim for iOS SDKs: dir.c/fs.c include it for the
 * file-type enum used by their __MACH__ getattrlist dirent path.
 * sys/attr.h (shipped in the iOS SDKs) defines fsobj_type_t as u_int32_t;
 * the V* enum values mirror the Darwin vnode type numbering. The shim is
 * applied only to the Moon runtime sources compiled by `moui build ios`.
 */
#ifndef MOUI_COMPAT_SYS_VNODE_H
#define MOUI_COMPAT_SYS_VNODE_H
#include <sys/attr.h>
enum { VNON = 0, VREG = 1, VDIR = 2, VBLK = 3, VCHR = 4, VLNK = 5,
       VSOCK = 6, VFIFO = 7, VBAD = 8 };
#endif
