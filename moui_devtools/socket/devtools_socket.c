#include <moonbit.h>

#include <stdint.h>
#include <string.h>

#ifdef _WIN32

/*
 * Windows socket transport is a later slice. The functions stay linkable so
 * the addon builds everywhere; callers treat -1 as "socket unavailable" and
 * fall back to the file transport.
 */
int32_t moui_devtools_listen(int32_t port) {
  (void)port;
  return -1;
}
int32_t moui_devtools_port(int32_t fd) {
  (void)fd;
  return -1;
}
int32_t moui_devtools_accept(int32_t fd) {
  (void)fd;
  return -1;
}
int32_t moui_devtools_connect(int32_t port) {
  (void)port;
  return -1;
}
int32_t moui_devtools_read(int32_t fd, moonbit_bytes_t buf, int32_t len) {
  (void)fd;
  (void)buf;
  (void)len;
  return -1;
}
int32_t moui_devtools_write(int32_t fd, moonbit_bytes_t buf, int32_t len) {
  (void)fd;
  (void)buf;
  (void)len;
  return -1;
}
void moui_devtools_close(int32_t fd) {
  (void)fd;
}

#else

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

static void moui_devtools_set_nonblock(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags >= 0) {
    (void)fcntl(fd, F_SETFL, flags | O_NONBLOCK);
  }
}

static int moui_devtools_loopback(struct sockaddr_in *addr, int32_t port) {
  memset(addr, 0, sizeof(*addr));
  addr->sin_family = AF_INET;
  addr->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr->sin_port = htons((uint16_t)port);
  return 0;
}

int32_t moui_devtools_listen(int32_t port) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  int yes = 1;
  (void)setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
  struct sockaddr_in addr;
  moui_devtools_loopback(&addr, port);
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  if (listen(fd, 4) != 0) {
    close(fd);
    return -1;
  }
  moui_devtools_set_nonblock(fd);
  return fd;
}

int32_t moui_devtools_port(int32_t fd) {
  struct sockaddr_in addr;
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    return -1;
  }
  return (int32_t)ntohs(addr.sin_port);
}

int32_t moui_devtools_accept(int32_t fd) {
  int client = accept(fd, NULL, NULL);
  if (client < 0) {
    return -1;
  }
  moui_devtools_set_nonblock(client);
  return client;
}

int32_t moui_devtools_connect(int32_t port) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  struct timeval timeout;
  timeout.tv_sec = 2;
  timeout.tv_usec = 0;
  (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  (void)setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
  struct sockaddr_in addr;
  moui_devtools_loopback(&addr, port);
  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  return fd;
}

int32_t moui_devtools_read(int32_t fd, moonbit_bytes_t buf, int32_t len) {
  if (buf == NULL || len <= 0) {
    return -1;
  }
  ssize_t read_len = recv(fd, buf, (size_t)len, 0);
  if (read_len < 0) {
    return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1;
  }
  if (read_len == 0) {
    return -1;
  }
  return (int32_t)read_len;
}

int32_t moui_devtools_write(int32_t fd, moonbit_bytes_t buf, int32_t len) {
  if (buf == NULL || len <= 0) {
    return 0;
  }
  ssize_t written = send(fd, buf, (size_t)len, 0);
  if (written < 0) {
    return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1;
  }
  return (int32_t)written;
}

void moui_devtools_close(int32_t fd) {
  if (fd >= 0) {
    (void)close(fd);
  }
}

#endif
