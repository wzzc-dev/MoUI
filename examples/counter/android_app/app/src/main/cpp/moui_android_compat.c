#if defined(__ANDROID__) && (!defined(__ANDROID_API__) || __ANDROID_API__ < 28)
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>

int getentropy(void *buffer, size_t buffer_size) {
  if (buffer == NULL && buffer_size != 0) {
    errno = EFAULT;
    return -1;
  }
  arc4random_buf(buffer, buffer_size);
  return 0;
}
#endif
