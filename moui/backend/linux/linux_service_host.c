#ifdef __linux__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <moonbit.h>

static char *copy_bytes(const uint8_t *bytes, int32_t len,
                        const char *fallback) {
  if (!bytes || len <= 0) {
    return strdup(fallback);
  }
  char *out = (char *)malloc((size_t)len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static char *shell_quote(const char *text) {
  if (!text) {
    return strdup("''");
  }
  size_t len = strlen(text);
  char *out = (char *)malloc(len * 4 + 3);
  if (!out) {
    return NULL;
  }
  char *dst = out;
  *dst++ = '\'';
  for (size_t i = 0; i < len; ++i) {
    if (text[i] == '\'') {
      memcpy(dst, "'\\''", 4);
      dst += 4;
    } else {
      *dst++ = text[i];
    }
  }
  *dst++ = '\'';
  *dst = '\0';
  return out;
}

static char *gvariant_quote_string(const char *text) {
  if (!text) {
    return strdup("''");
  }
  size_t len = strlen(text);
  char *out = (char *)malloc(len * 2 + 3);
  if (!out) {
    return NULL;
  }
  char *dst = out;
  *dst++ = '\'';
  for (size_t i = 0; i < len; ++i) {
    if (text[i] == '\'' || text[i] == '\\') {
      *dst++ = '\\';
    }
    *dst++ = text[i];
  }
  *dst++ = '\'';
  *dst = '\0';
  return out;
}

static int run_command(const char *command) {
  int status = system(command);
  return status != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static char *capture_command(const char *command) {
  FILE *pipe = popen(command, "r");
  if (!pipe) {
    return NULL;
  }
  size_t capacity = 4096;
  size_t length = 0;
  char *buffer = (char *)malloc(capacity);
  if (!buffer) {
    pclose(pipe);
    return NULL;
  }
  while (!feof(pipe)) {
    char chunk[2048];
    size_t count = fread(chunk, 1, sizeof(chunk), pipe);
    if (count > 0) {
      if (length + count + 1 > capacity) {
        size_t next_capacity = capacity * 2;
        while (length + count + 1 > next_capacity) {
          next_capacity *= 2;
        }
        char *next = (char *)realloc(buffer, next_capacity);
        if (!next) {
          free(buffer);
          pclose(pipe);
          return NULL;
        }
        buffer = next;
        capacity = next_capacity;
      }
      memcpy(buffer + length, chunk, count);
      length += count;
    }
  }
  int status = pclose(pipe);
  if (status == -1 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    free(buffer);
    return NULL;
  }
  while (length > 0 && (buffer[length - 1] == '\n' ||
                        buffer[length - 1] == '\r')) {
    length--;
  }
  buffer[length] = '\0';
  return buffer;
}

static char *extract_object_path(const char *text) {
  if (!text) {
    return NULL;
  }
  const char *start = strchr(text, '\'');
  if (!start) {
    return NULL;
  }
  start++;
  const char *end = strchr(start, '\'');
  if (!end || end <= start) {
    return NULL;
  }
  size_t len = (size_t)(end - start);
  char *out = (char *)malloc(len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, start, len);
  out[len] = '\0';
  return out;
}

static int hex_digit(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  if (c >= 'a' && c <= 'f') {
    return 10 + c - 'a';
  }
  if (c >= 'A' && c <= 'F') {
    return 10 + c - 'A';
  }
  return -1;
}

static char *decode_file_uri(const char *uri, size_t len) {
  const char *prefix = "file://";
  size_t prefix_len = strlen(prefix);
  if (!uri || len < prefix_len || strncmp(uri, prefix, prefix_len) != 0) {
    return NULL;
  }
  const char *cursor = uri + prefix_len;
  size_t remaining = len - prefix_len;
  if (remaining >= 10 && strncmp(cursor, "localhost/", 10) == 0) {
    cursor += 9;
    remaining -= 9;
  } else if (remaining > 0 && cursor[0] != '/') {
    const char *slash = memchr(cursor, '/', remaining);
    if (!slash) {
      return NULL;
    }
    remaining -= (size_t)(slash - cursor);
    cursor = slash;
  }
  char *out = (char *)malloc(remaining + 1);
  if (!out) {
    return NULL;
  }
  size_t out_len = 0;
  for (size_t i = 0; i < remaining; ++i) {
    if (cursor[i] == '%' && i + 2 < remaining) {
      int hi = hex_digit(cursor[i + 1]);
      int lo = hex_digit(cursor[i + 2]);
      if (hi >= 0 && lo >= 0) {
        out[out_len++] = (char)((hi << 4) | lo);
        i += 2;
        continue;
      }
    }
    out[out_len++] = cursor[i];
  }
  out[out_len] = '\0';
  return out;
}

static char *append_line(char *text, size_t *len, size_t *capacity,
                         const char *line) {
  if (!line || !line[0]) {
    return text;
  }
  size_t line_len = strlen(line);
  size_t needed = *len + line_len + 2;
  if (needed > *capacity) {
    size_t next_capacity = *capacity ? *capacity * 2 : 256;
    while (needed > next_capacity) {
      next_capacity *= 2;
    }
    char *next = (char *)realloc(text, next_capacity);
    if (!next) {
      free(text);
      return NULL;
    }
    text = next;
    *capacity = next_capacity;
  }
  if (*len > 0) {
    text[(*len)++] = '\n';
  }
  memcpy(text + *len, line, line_len);
  *len += line_len;
  text[*len] = '\0';
  return text;
}

static char *extract_file_uris_as_paths(const char *response) {
  if (!response ||
      (strstr(response, "uint32 0") == NULL &&
       strstr(response, "Response (0,") == NULL &&
       strstr(response, "(0,") == NULL)) {
    return NULL;
  }
  size_t capacity = 256;
  size_t length = 0;
  char *paths = (char *)calloc(capacity, 1);
  if (!paths) {
    return NULL;
  }
  const char *cursor = response;
  while ((cursor = strstr(cursor, "file://")) != NULL) {
    const char *end = cursor;
    while (*end && *end != '\'' && *end != '"' && *end != ']' &&
           *end != ',' && *end != '>' && *end != ' ') {
      end++;
    }
    char *path = decode_file_uri(cursor, (size_t)(end - cursor));
    if (path) {
      paths = append_line(paths, &length, &capacity, path);
      free(path);
      if (!paths) {
        return NULL;
      }
    }
    cursor = end;
  }
  if (length == 0) {
    free(paths);
    return NULL;
  }
  return paths;
}

static int portal_response_seen(const char *response) {
  return response && strstr(response, "Response") != NULL;
}

static moonbit_bytes_t bytes_from_string(const char *text) {
  if (!text || !text[0]) {
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, text, (size_t)len);
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_open_url(const uint8_t *url, int32_t url_len) {
  char *url_text = copy_bytes(url, url_len, "");
  if (!url_text || !url_text[0]) {
    free(url_text);
    return 0;
  }
  char *quoted = shell_quote(url_text);
  if (!quoted) {
    free(url_text);
    return 0;
  }
  size_t portal_len =
      strlen(quoted) + 220;
  char *portal = (char *)malloc(portal_len);
  if (!portal) {
    free(quoted);
    free(url_text);
    return 0;
  }
  snprintf(portal, portal_len,
           "gdbus call --session --dest org.freedesktop.portal.Desktop "
           "--object-path /org/freedesktop/portal/desktop "
           "--method org.freedesktop.portal.OpenURI.OpenURI '' %s '{}' "
           ">/dev/null 2>&1",
           quoted);
  int ok = run_command(portal);
  if (!ok) {
    size_t fallback_len = strlen(quoted) + 40;
    char *fallback = (char *)malloc(fallback_len);
    if (fallback) {
      snprintf(fallback, fallback_len, "xdg-open %s >/dev/null 2>&1", quoted);
      ok = run_command(fallback);
      free(fallback);
    }
  }
  free(portal);
  free(quoted);
  free(url_text);
  return ok ? 1 : 0;
}

static char *portal_file_dialog(int32_t kind, const char *title,
                                const char *default_name) {
  char *quoted_title = shell_quote(title ? title : "");
  char *variant_default = gvariant_quote_string(default_name ? default_name : "");
  if (!quoted_title || !variant_default) {
    free(quoted_title);
    free(variant_default);
    return NULL;
  }
  const char *method = "OpenFile";
  char options[512];
  if (kind == 2) {
    method = "OpenFolder";
    snprintf(options, sizeof(options), "{'multiple': <true>}");
  } else if (kind == 1) {
    method = "SaveFile";
    snprintf(options, sizeof(options), "{'current_name': <%s>}",
             variant_default);
  } else {
    snprintf(options, sizeof(options), "{'multiple': <true>}");
  }
  char *quoted_options = shell_quote(options);
  if (!quoted_options) {
    free(quoted_title);
    free(variant_default);
    return NULL;
  }
  size_t call_len =
      strlen(method) + strlen(quoted_title) + strlen(quoted_options) + 260;
  char *call = (char *)malloc(call_len);
  if (!call) {
    free(quoted_title);
    free(variant_default);
    free(quoted_options);
    return NULL;
  }
  snprintf(call, call_len,
           "gdbus call --session --dest org.freedesktop.portal.Desktop "
           "--object-path /org/freedesktop/portal/desktop "
           "--method org.freedesktop.portal.FileChooser.%s '' %s %s "
           "2>/dev/null",
           method, quoted_title, quoted_options);
  char *call_output = capture_command(call);
  char *handle = extract_object_path(call_output);
  free(call_output);
  free(call);
  if (!handle) {
    free(quoted_title);
    free(variant_default);
    free(quoted_options);
    return NULL;
  }
  char *quoted_handle = shell_quote(handle);
  char *paths = NULL;
  if (quoted_handle) {
    size_t monitor_len = strlen(quoted_handle) + 260;
    char *monitor = (char *)malloc(monitor_len);
    if (monitor) {
      snprintf(monitor, monitor_len,
               "timeout 300s gdbus monitor --session "
               "--dest org.freedesktop.portal.Desktop --object-path %s "
               "2>/dev/null | awk '/Response/ { print; fflush(); exit }'",
               quoted_handle);
      char *response = capture_command(monitor);
      paths = extract_file_uris_as_paths(response);
      if (!paths && portal_response_seen(response)) {
        paths = strdup("");
      }
      free(response);
      free(monitor);
    }
  }
  free(quoted_handle);
  free(handle);
  free(quoted_title);
  free(variant_default);
  free(quoted_options);
  return paths;
}

static char *zenity_file_dialog(int32_t kind, const char *title,
                                const char *default_name) {
  char *quoted_title = shell_quote(title ? title : "");
  char *quoted_default = shell_quote(default_name ? default_name : "");
  if (!quoted_title || !quoted_default) {
    free(quoted_title);
    free(quoted_default);
    return NULL;
  }
  size_t command_len = strlen(quoted_title) + strlen(quoted_default) + 180;
  char *command = (char *)malloc(command_len);
  if (!command) {
    free(quoted_title);
    free(quoted_default);
    return NULL;
  }
  if (kind == 2) {
    snprintf(command, command_len,
             "zenity --file-selection --directory --title=%s 2>/dev/null",
             quoted_title);
  } else if (kind == 1) {
    snprintf(command, command_len,
             "zenity --file-selection --save --confirm-overwrite "
             "--filename=%s --title=%s 2>/dev/null",
             quoted_default, quoted_title);
  } else {
    snprintf(command, command_len,
             "zenity --file-selection --multiple --separator='\\n' "
             "--title=%s 2>/dev/null",
             quoted_title);
  }
  char *selection = capture_command(command);
  free(command);
  free(quoted_title);
  free(quoted_default);
  return selection;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_file_dialog(int32_t kind, const uint8_t *title,
                                       int32_t title_len,
                                       const uint8_t *filters,
                                       int32_t filters_len,
                                       const uint8_t *default_name,
                                       int32_t default_name_len) {
  (void)filters;
  (void)filters_len;
  char *title_text = copy_bytes(title, title_len, "");
  char *default_text = copy_bytes(default_name, default_name_len, "");
  char *selection =
      portal_file_dialog(kind, title_text ? title_text : "",
                         default_text ? default_text : "");
  if (!selection) {
    selection = zenity_file_dialog(kind, title_text ? title_text : "",
                                   default_text ? default_text : "");
  }
  moonbit_bytes_t bytes = bytes_from_string(selection);
  free(selection);
  free(title_text);
  free(default_text);
  return bytes;
}

#else

#include <stdint.h>
#include <moonbit.h>

MOONBIT_FFI_EXPORT
int32_t moui_linux_open_url(const uint8_t *url, int32_t url_len) {
  (void)url;
  (void)url_len;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_file_dialog(int32_t kind, const uint8_t *title,
                                       int32_t title_len,
                                       const uint8_t *filters,
                                       int32_t filters_len,
                                       const uint8_t *default_name,
                                       int32_t default_name_len) {
  (void)kind;
  (void)title;
  (void)title_len;
  (void)filters;
  (void)filters_len;
  (void)default_name;
  (void)default_name_len;
  return moonbit_make_bytes(0, 0);
}

#endif
