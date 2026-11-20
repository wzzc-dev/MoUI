// Platform font discovery for the Sun CPU raster renderer.
//
// Linux resolves the generic families through fontconfig the way fc-match
// does, so Sun draws with the face fontconfig hands the Skia text provider.
// Windows resolves the system faces Skia's DirectWrite manager would pick
// (Segoe UI, Consolas, Times New Roman, with Arial/Georgia/Courier New as
// fallbacks) from the Windows Fonts directory, plus Segoe UI Symbol so a glyph
// the text families do not cover (a check mark, an arrow) draws its outline
// instead of the .notdef box DirectWrite's fallback would never show. macOS gets
// its system fonts from the fixed locations listed in renderer_text_draw.mbt.
//
// Discovery runs once per process and is cached: renderer construction must
// stay cheap even though several renderers may be created per test run.
//
// Payload layout (little-endian int32 lengths):
//   i32 version (3)
//   i32 match_count
//     per match: i32 role, i32 weight, i32 path_len, path bytes,
//                i32 family_len, family bytes
//   i32 list_count
//     per list entry: i32 path_len, path bytes, i32 family_len, family bytes
//
// role: 0 = sans, 1 = monospace, 2 = serif, 3 = symbol. weight is the CSS weight
// bucket the face was matched for (see the fc weight table below); a face only
// gets a bucket entry when the host resolves that weight to it. Empty/missing
// entries are omitted, so a host without the platform query yields an empty
// discovery. Version 3 added the symbol role; hosts that never resolve one
// simply omit it, so the layout is otherwise identical to version 2.

#include "moonbit.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#endif

#define MOUI_SUN_FONT_ROLE_COUNT 4
// Roles the fontconfig match loop resolves. Symbol faces are resolved by the
// Windows candidate table only, so Linux keeps querying the three text roles.
#define MOUI_SUN_FONT_MATCH_ROLE_COUNT 3
#define MOUI_SUN_FONT_WEIGHT_COUNT 6
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

// Role query order matches the payload role codes.
static const char *const g_role_query[MOUI_SUN_FONT_MATCH_ROLE_COUNT] = {
  "sans-serif",
  "monospace",
  "serif",
};

// CSS weight buckets, paired with the fontconfig weight constant they ask for.
// The buckets mirror `moui_linux_fontconfig_weight` in the Skia text provider:
// fontconfig quantises a CSS weight to one FC_WEIGHT constant, so querying the
// same constants makes Sun resolve the same face Skia does at the same weight.
static const int32_t g_weight_css[MOUI_SUN_FONT_WEIGHT_COUNT] = {
  100, 300, 400, 600, 700, 800,
};
static const char *const g_weight_query[MOUI_SUN_FONT_WEIGHT_COUNT] = {
  "light", "book", "regular", "demibold", "bold", "black",
};

#if defined(__linux__) || defined(_WIN32)
static SunPlatformFontMatchSlot
  g_matches[MOUI_SUN_FONT_ROLE_COUNT][MOUI_SUN_FONT_WEIGHT_COUNT];
static SunPlatformFontListEntry g_list[MOUI_SUN_FONT_LIST_MAX];
static int32_t g_list_count = 0;
static int32_t g_resolved = 0;
#endif

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

#if defined(__linux__)

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

static void sun_resolve_match_slot(int32_t role, int32_t weight_index) {
  char command[MOUI_SUN_FONT_COMMAND_MAX];
  snprintf(
    command,
    sizeof(command),
    "fc-match -f '%%{file}\\n%%{family[0]}\\n' '%s:weight=%s' 2>/dev/null",
    g_role_query[role],
    g_weight_query[weight_index]
  );
  char buffer[MOUI_SUN_FONT_COMMAND_MAX];
  if (sun_run_capture(command, buffer, (int32_t)sizeof(buffer)) <= 0) {
    return;
  }
  SunPlatformFontMatchSlot *slot = &g_matches[role][weight_index];
  const char *first_end = strchr(buffer, '\n');
  size_t path_len = first_end == NULL ? strlen(buffer) : (size_t)(first_end - buffer);
  sun_copy_truncated(slot->path, sizeof(slot->path), buffer, path_len);
  sun_trim_line(slot->path);
  if (slot->path[0] == '\0') {
    return;
  }
  if (first_end != NULL) {
    const char *family_start = first_end + 1;
    const char *family_end = strchr(family_start, '\n');
    size_t family_len = family_end == NULL
      ? strlen(family_start)
      : (size_t)(family_end - family_start);
    sun_copy_truncated(
      slot->family,
      sizeof(slot->family),
      family_start,
      family_len
    );
    sun_trim_line(slot->family);
  }
  slot->present = 1;
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
  for (int32_t role = 0; role < MOUI_SUN_FONT_MATCH_ROLE_COUNT; role += 1) {
    for (
      int32_t weight_index = 0;
      weight_index < MOUI_SUN_FONT_WEIGHT_COUNT;
      weight_index += 1
    ) {
      sun_resolve_match_slot(role, weight_index);
    }
  }
  sun_resolve_list();
}
#elif defined(_WIN32)

// Windows system faces, in the order Skia's DirectWrite font manager resolves
// the generic families. Paths are built from the Windows directory at run time
// so a relocated Windows install still works.
typedef struct {
  int32_t role;
  int32_t weight;
  const char *family;
  const char *file;
} SunWindowsFontCandidate;

static const SunWindowsFontCandidate g_windows_candidates[] = {
  // Segoe UI is the DirectWrite sans default. Light serves both the 100 and 300
  // buckets, Semibold/Bold/Black cover 600/700/800.
  { 0, 100, "Segoe UI", "segoeuil.ttf" },
  { 0, 300, "Segoe UI", "segoeuil.ttf" },
  { 0, 400, "Segoe UI", "segoeui.ttf" },
  { 0, 600, "Segoe UI", "seguisb.ttf" },
  { 0, 700, "Segoe UI", "segoeuib.ttf" },
  { 0, 800, "Segoe UI", "seguibl.ttf" },
  { 1, 400, "Consolas", "consola.ttf" },
  { 1, 700, "Consolas", "consolab.ttf" },
  { 2, 400, "Times New Roman", "times.ttf" },
  { 2, 700, "Times New Roman", "timesbd.ttf" },
  // Segoe UI Symbol is the face DirectWrite's system fallback shows for symbols
  // the text families do not cover (the U+2713 check mark, arrows, dingbats).
  // Registering it draws those outlines instead of the .notdef box; it is only
  // reachable through its own family key, so it never becomes a text fallback.
  { 3, 400, "Segoe UI Symbol", "seguisym.ttf" },
};

static const SunWindowsFontCandidate g_windows_fallbacks[] = {
  { 0, 400, "Arial", "arial.ttf" },
  { 0, 700, "Arial", "arialbd.ttf" },
  { 1, 400, "Courier New", "cour.ttf" },
  { 1, 700, "Courier New", "courbd.ttf" },
  { 2, 400, "Georgia", "georgia.ttf" },
  { 2, 700, "Georgia", "georgiab.ttf" },
};

static int32_t sun_windows_weight_index(int32_t weight) {
  for (int32_t index = 0; index < MOUI_SUN_FONT_WEIGHT_COUNT; index += 1) {
    if (g_weight_css[index] == weight) {
      return index;
    }
  }
  return -1;
}

static void sun_windows_fonts_dir(char *dst, size_t cap) {
  wchar_t wide[MOUI_SUN_FONT_PATH_MAX];
  UINT length = GetWindowsDirectoryW(wide, (UINT)MOUI_SUN_FONT_PATH_MAX);
  if (length == 0 || length >= MOUI_SUN_FONT_PATH_MAX) {
    return;
  }
  char utf8[MOUI_SUN_FONT_PATH_MAX];
  int written = WideCharToMultiByte(
    CP_UTF8,
    0,
    wide,
    (int)length,
    utf8,
    (int)sizeof(utf8) - 1,
    NULL,
    NULL
  );
  if (written <= 0) {
    return;
  }
  utf8[written] = '\0';
  snprintf(dst, cap, "%s\\Fonts", utf8);
}

static int32_t sun_windows_file_exists(const char *path) {
  wchar_t wide[MOUI_SUN_FONT_PATH_MAX];
  int length = MultiByteToWideChar(
    CP_UTF8,
    0,
    path,
    -1,
    wide,
    (int)MOUI_SUN_FONT_PATH_MAX
  );
  if (length <= 0) {
    return 0;
  }
  DWORD attributes = GetFileAttributesW(wide);
  return attributes != INVALID_FILE_ATTRIBUTES &&
    (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

static void sun_windows_try_candidate(
  const char *fonts_dir,
  const SunWindowsFontCandidate *candidate
) {
  int32_t weight_index = sun_windows_weight_index(candidate->weight);
  if (weight_index < 0) {
    return;
  }
  SunPlatformFontMatchSlot *slot = &g_matches[candidate->role][weight_index];
  if (slot->present) {
    return;
  }
  char path[MOUI_SUN_FONT_PATH_MAX];
  snprintf(path, sizeof(path), "%s\\%s", fonts_dir, candidate->file);
  if (!sun_windows_file_exists(path)) {
    return;
  }
  sun_copy_truncated(slot->path, sizeof(slot->path), path, strlen(path));
  sun_copy_truncated(
    slot->family,
    sizeof(slot->family),
    candidate->family,
    strlen(candidate->family)
  );
  slot->present = 1;
}

static int32_t sun_windows_role_has_face(int32_t role) {
  for (int32_t index = 0; index < MOUI_SUN_FONT_WEIGHT_COUNT; index += 1) {
    if (g_matches[role][index].present) {
      return 1;
    }
  }
  return 0;
}

static void sun_resolve_once(void) {
  if (g_resolved) {
    return;
  }
  g_resolved = 1;
  char fonts_dir[MOUI_SUN_FONT_PATH_MAX];
  fonts_dir[0] = '\0';
  sun_windows_fonts_dir(fonts_dir, sizeof(fonts_dir));
  if (fonts_dir[0] == '\0') {
    return;
  }
  size_t candidate_count =
    sizeof(g_windows_candidates) / sizeof(g_windows_candidates[0]);
  for (size_t index = 0; index < candidate_count; index += 1) {
    sun_windows_try_candidate(fonts_dir, &g_windows_candidates[index]);
  }
  size_t fallback_count =
    sizeof(g_windows_fallbacks) / sizeof(g_windows_fallbacks[0]);
  for (size_t index = 0; index < fallback_count; index += 1) {
    const SunWindowsFontCandidate *candidate = &g_windows_fallbacks[index];
    if (sun_windows_role_has_face(candidate->role)) {
      continue;
    }
    sun_windows_try_candidate(fonts_dir, candidate);
  }
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
  // part of every payload, including the empty discovery hosts without a
  // platform query send, so it must be counted outside the platform block;
  // otherwise the fixed-size write overruns the buffer and the decoder rejects
  // the short payload.
  int32_t size = 12;
#if defined(__linux__) || defined(_WIN32)
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    for (
      int32_t weight_index = 0;
      weight_index < MOUI_SUN_FONT_WEIGHT_COUNT;
      weight_index += 1
    ) {
      if (!g_matches[role][weight_index].present) {
        continue;
      }
      // role(4) + weight(4) + path_len(4) + path + family_len(4) + family.
      size += 16 + (int32_t)strlen(g_matches[role][weight_index].path) +
        (int32_t)strlen(g_matches[role][weight_index].family);
    }
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

moonbit_bytes_t moui_sun_platform_font_payload(void) {
  int32_t match_count = 0;
  int32_t list_count = 0;
#if defined(__linux__) || defined(_WIN32)
  sun_resolve_once();
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    for (
      int32_t weight_index = 0;
      weight_index < MOUI_SUN_FONT_WEIGHT_COUNT;
      weight_index += 1
    ) {
      if (g_matches[role][weight_index].present) {
        match_count += 1;
      }
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
  sun_write_i32(cursor, 3);
  cursor += 4;
  sun_write_i32(cursor, match_count);
  cursor += 4;
#if defined(__linux__) || defined(_WIN32)
  for (int32_t role = 0; role < MOUI_SUN_FONT_ROLE_COUNT; role += 1) {
    for (
      int32_t weight_index = 0;
      weight_index < MOUI_SUN_FONT_WEIGHT_COUNT;
      weight_index += 1
    ) {
      SunPlatformFontMatchSlot *slot = &g_matches[role][weight_index];
      if (!slot->present) {
        continue;
      }
      sun_write_i32(cursor, role);
      cursor += 4;
      sun_write_i32(cursor, g_weight_css[weight_index]);
      cursor += 4;
      int32_t path_len = sun_append_text(cursor + 4, slot->path);
      sun_write_i32(cursor, path_len);
      cursor += 4 + path_len;
      int32_t family_len = sun_append_text(cursor + 4, slot->family);
      sun_write_i32(cursor, family_len);
      cursor += 4 + family_len;
    }
  }
#endif
  sun_write_i32(cursor, list_count);
  cursor += 4;
#if defined(__linux__) || defined(_WIN32)
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
