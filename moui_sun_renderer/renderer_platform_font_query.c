// Platform font discovery for the Sun CPU raster renderer.
//
// macOS gets its system fonts from the fixed locations listed in
// renderer_text_draw.mbt. Linux resolves the same generic families through
// fontconfig the way fc-match does, so Sun draws with the face fontconfig
// hands the Skia text provider instead of falling back to placeholder glyphs.
//
// Discovery runs once per process and is cached: renderer construction must
// stay cheap even though several renderers may be created per test run.
//
// Payload layout (little-endian int32 lengths):
//   i32 version (1)
//   i32 match_count
//     per match: i32 role, i32 path_len, path bytes, i32 family_len, family bytes
//   i32 list_count
//     per list entry: i32 path_len, path bytes, i32 family_len, family bytes
//
// role: 0 = sans, 1 = monospace, 2 = serif. Empty/missing entries are omitted,
// so an environment without fontconfig yields an empty discovery.

#include "moonbit.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MOUI_SUN_FONT_ROLE_COUNT 3
#define MOUI_SUN_FONT_PATH_MAX 1024
#define MOUI_SUN_FONT_FAMILY_MAX 256
#define MOUI_SUN_FONT_LIST_MAX 256
#define MOUI_SUN_FONT_CAPTURE_MAX 262144
#define MOUI_SUN_FONT_COMMAND_MAX 512

typedef struct {
  char path[MOUI_SUN_FONT_PATH_MAX];
  char family[MOUI_SUN_FONT_FAMILY_MAX];
  int32_t present;
} SunPlatformFontMatchSlot;

typedef struct {
  char path[MOUI_SUN_FONT_PATH_MAX];
  char family[MOUI_SUN_FONT_FAMILY_MAX];
} SunPlatformFontListEntry;

#if defined(__linux__)
static SunPlatformFontMatchSlot g_matches[MOUI_SUN_FONT_ROLE_COUNT];
static SunPlatformFontListEntry g_list[MOUI_SUN_FONT_LIST_MAX];
static int32_t g_list_count = 0;
static int32_t g_resolved = 0;

static int32_t sun_run_capture(const char *command, char *out, int32_t cap) {
  if (cap <= 1) {
    return 0;
  }
  FILE *pipe = popen(command, "r");
  if (pipe == NULL) {
    return 0;
  }
  int32_t used = 0;
  int ch = 0;
  while (used < cap - 1) {
    ch = fgetc(pipe);
    if (ch == EOF) {
      break;
    }
    out[used] = (char)ch;
    used += 1;
  }
  out[used] = '\0';
  pclose(pipe);
  return used;
}

static void sun_trim_line(char *text) {
  size_t length = strlen(text);
  while (length > 0) {
    char last = text[length - 1];
    if (last == '\n' || last == '\r') {
      text[length - 1] = '\0';
      length -= 1;
    } else {
      break;
    }
  }
}

static void sun_copy_truncated(char *dst, size_t cap, const char *src, size_t len) {
  if (cap == 0) {
    return;
  }
  if (len > cap - 1) {
    len = cap - 1;
  }
  memcpy(dst, src, len);
  dst[len] = '\0';
}

static void sun_resolve_match_slot(int32_t role, const char *query) {
  char command[MOUI_SUN_FONT_COMMAND_MAX];
  snprintf(
    command,
    sizeof(command),
    "fc-match -f '%%{file}\\n%%{family[0]}\\n' '%s' 2>/dev/null",
    query
  );
  char buffer[MOUI_SUN_FONT_COMMAND_MAX];
  if (sun_run_capture(command, buffer, (int32_t)sizeof(buffer)) <= 0) {
    return;
  }
  const char *first_end = strchr(buffer, '\n');
  size_t path_len = first_end == NULL ? strlen(buffer) : (size_t)(first_end - buffer);
  sun_copy_truncated(
    g_matches[role].path,
    sizeof(g_matches[role].path),
    buffer,
    path_len
  );
  sun_trim_line(g_matches[role].path);
  if (g_matches[role].path[0] == '\0') {
    return;
  }
  if (first_end != NULL) {
    const char *family_start = first_end + 1;
    const char *family_end = strchr(family_start, '\n');
    size_t family_len = family_end == NULL
      ? strlen(family_start)
      : (size_t)(family_end - family_start);
    sun_copy_truncated(
      g_matches[role].family,
      sizeof(g_matches[role].family),
      family_start,
      family_len
    );
    sun_trim_line(g_matches[role].family);
  }
  g_matches[role].present = 1;
}

static void sun_resolve_list(void) {
  char *buffer = (char *)malloc(MOUI_SUN_FONT_CAPTURE_MAX);
  if (buffer == NULL) {
    return;
  }
  int32_t used = sun_run_capture(
    "fc-list -f '%{file}\\t%{family[0]}\\n' 2>/dev/null",
    buffer,
    MOUI_SUN_FONT_CAPTURE_MAX
  );
  if (used <= 0) {
    free(buffer);
    return;
  }
  char *cursor = buffer;
  while (*cursor != '\0' && g_list_count < MOUI_SUN_FONT_LIST_MAX) {
    char *line_end = strchr(cursor, '\n');
    if (line_end != NULL) {
      *line_end = '\0';
    }
    char *separator = strchr(cursor, '\t');
    if (separator != NULL) {
      *separator = '\0';
      const char *path = cursor;
      const char *family = separator + 1;
      int32_t duplicate = 0;
      for (int32_t index = 0; index < g_list_count; index += 1) {
        if (strcmp(g_list[index].path, path) == 0) {
          duplicate = 1;
          break;
        }
      }
      if (!duplicate && path[0] != '\0') {
        sun_copy_truncated(
          g_list[g_list_count].path,
          sizeof(g_list[g_list_count].path),
          path,
          strlen(path)
        );
        sun_copy_truncated(
          g_list[g_list_count].family,
          sizeof(g_list[g_list_count].family),
          family,
          strlen(family)
        );
        sun_trim_line(g_list[g_list_count].path);
        sun_trim_line(g_list[g_list_count].family);
        g_list_count += 1;
      }
    }
    if (line_end == NULL) {
      break;
    }
    cursor = line_end + 1;
  }
  free(buffer);
}

static void sun_resolve_once(void) {
  if (g_resolved) {
    return;
  }
  g_resolved = 1;
  sun_resolve_match_slot(0, "sans-serif");
  sun_resolve_match_slot(1, "monospace");
  sun_resolve_match_slot(2, "serif");
  sun_resolve_list();
}
#endif

static void sun_write_i32(uint8_t *dst, int32_t value) {
  uint32_t unsigned_value = (uint32_t)value;
  dst[0] = (uint8_t)(unsigned_value & 0xffu);
  dst[1] = (uint8_t)((unsigned_value >> 8) & 0xffu);
  dst[2] = (uint8_t)((unsigned_value >> 16) & 0xffu);
  dst[3] = (uint8_t)((unsigned_value >> 24) & 0xffu);
}

static int32_t sun_payload_size(void) {
  // version(4) + match_count(4) + list_count(4). The trailing list count is
  // part of every payload, including the empty discovery non-Linux hosts send,
  // so it must be counted outside the platform block; otherwise the fixed-size
  // write overruns the buffer and the decoder rejects the short payload.
  int32_t size = 12;
#if defined(__linux__)
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    if (!g_matches[role].present) {
      continue;
    }
    // role(4) + path_len(4) + path + family_len(4) + family.
    size += 12 + (int32_t)strlen(g_matches[role].path) +
      (int32_t)strlen(g_matches[role].family);
  }
  for (int32_t index = 0; index < g_list_count; index += 1) {
    size += 8 + (int32_t)strlen(g_list[index].path) +
      (int32_t)strlen(g_list[index].family);
  }
#endif
  return size;
}

static int32_t sun_append_text(uint8_t *dst, const char *text) {
  int32_t length = (int32_t)strlen(text);
  memcpy(dst, text, (size_t)length);
  return length;
}

moonbit_bytes_t moui_sun_linux_platform_font_payload(void) {
  int32_t match_count = 0;
  int32_t list_count = 0;
#if defined(__linux__)
  sun_resolve_once();
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    if (g_matches[role].present) {
      match_count += 1;
    }
  }
  list_count = g_list_count;
#endif
  int32_t size = sun_payload_size();
  moonbit_bytes_t payload = moonbit_make_bytes(size, 0);
  if (payload == NULL) {
    return moonbit_make_bytes(8, 0);
  }
  uint8_t *cursor = (uint8_t *)payload;
  sun_write_i32(cursor, 1);
  cursor += 4;
  sun_write_i32(cursor, match_count);
  cursor += 4;
#if defined(__linux__)
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    if (!g_matches[role].present) {
      continue;
    }
    sun_write_i32(cursor, role);
    cursor += 4;
    int32_t path_len = sun_append_text(cursor + 4, g_matches[role].path);
    sun_write_i32(cursor, path_len);
    cursor += 4 + path_len;
    int32_t family_len = sun_append_text(cursor + 4, g_matches[role].family);
    sun_write_i32(cursor, family_len);
    cursor += 4 + family_len;
  }
#endif
  sun_write_i32(cursor, list_count);
  cursor += 4;
#if defined(__linux__)
  for (int32_t index = 0; index < g_list_count; index += 1) {
    int32_t path_len = sun_append_text(cursor + 4, g_list[index].path);
    sun_write_i32(cursor, path_len);
    cursor += 4 + path_len;
    int32_t family_len = sun_append_text(cursor + 4, g_list[index].family);
    sun_write_i32(cursor, family_len);
    cursor += 4 + family_len;
  }
#endif
  return payload;
}
