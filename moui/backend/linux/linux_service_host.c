#ifdef __linux__

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/wait.h>
#include <moonbit.h>

static char *capture_command(const char *command);

MOONBIT_FFI_EXPORT int32_t moui_linux_accessibility_high_contrast(void) {
  const char *value = getenv("MOUI_ACCESSIBILITY_CONTRAST");
  if (value) {
    return strcmp(value, "high") == 0 || strcmp(value, "1") == 0 ? 1 : 0;
  }
  char *theme = capture_command(
      "gsettings get org.gnome.desktop.a11y.interface high-contrast 2>/dev/null");
  int32_t enabled = theme && strcmp(theme, "true") == 0 ? 1 : 0;
  free(theme);
  return enabled;
}

MOONBIT_FFI_EXPORT int32_t moui_linux_accessibility_reduce_motion(void) {
  const char *value = getenv("MOUI_REDUCED_MOTION");
  if (value) {
    return strcmp(value, "1") == 0 || strcmp(value, "true") == 0 ? 1 : 0;
  }
  char *animations = capture_command(
      "gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null");
  int32_t reduced = animations && strcmp(animations, "false") == 0 ? 1 : 0;
  free(animations);
  return reduced;
}

MOONBIT_FFI_EXPORT double moui_linux_accessibility_text_scale(void) {
  const char *override = getenv("MOUI_TEXT_SCALE");
  char *value = override ? strdup(override) : capture_command(
      "gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null");
  if (!value) return 0.0;
  char *end = NULL;
  double scale = strtod(value, &end);
  int valid = end && *end == '\0' && scale > 0.0;
  free(value);
  return valid ? scale : 0.0;
}

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

static moonbit_bytes_t read_binary_command(const char *command) {
  FILE *pipe = popen(command, "r");
  if (!pipe) {
    return moonbit_make_bytes(0, 0);
  }
  size_t capacity = 4096;
  size_t length = 0;
  uint8_t *buffer = (uint8_t *)malloc(capacity);
  if (!buffer) {
    pclose(pipe);
    return moonbit_make_bytes(0, 0);
  }
  while (!feof(pipe)) {
    if (length + 2048 > capacity) {
      size_t next_capacity = capacity * 2;
      uint8_t *next = (uint8_t *)realloc(buffer, next_capacity);
      if (!next) {
        free(buffer);
        pclose(pipe);
        return moonbit_make_bytes(0, 0);
      }
      buffer = next;
      capacity = next_capacity;
    }
    size_t n = fread(buffer + length, 1, capacity - length, pipe);
    if (n == 0) {
      break;
    }
    length += n;
  }
  int status = pclose(pipe);
  if (status != 0 || length == 0) {
    free(buffer);
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  memcpy(result, buffer, length);
  free(buffer);
  return result;
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

static char *append_text(char *text, size_t *len, size_t *capacity,
                         const char *chunk) {
  if (!chunk) {
    return text;
  }
  size_t chunk_len = strlen(chunk);
  size_t needed = *len + chunk_len + 1;
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
  memcpy(text + *len, chunk, chunk_len);
  *len += chunk_len;
  text[*len] = '\0';
  return text;
}

typedef struct MouiLinuxMenuCommand {
  int enabled;
  char *label;
} MouiLinuxMenuCommand;

static void free_menu_commands(MouiLinuxMenuCommand *commands, int32_t count) {
  if (!commands) {
    return;
  }
  for (int32_t i = 0; i < count; ++i) {
    free(commands[i].label);
  }
  free(commands);
}

static int parse_menu_command(const char *bytes, int32_t length,
                              int32_t *offset,
                              MouiLinuxMenuCommand *command) {
  if (*offset >= length) {
    return 0;
  }
  char enabled_char = bytes[*offset];
  if (enabled_char != '0' && enabled_char != '1') {
    return 0;
  }
  command->enabled = enabled_char == '1';
  *offset += 1;
  if (*offset >= length || bytes[*offset] != ':') {
    return 0;
  }
  *offset += 1;
  int32_t label_length = 0;
  while (*offset < length && bytes[*offset] >= '0' && bytes[*offset] <= '9') {
    int32_t digit = bytes[*offset] - '0';
    if (label_length > (INT32_MAX - digit) / 10) {
      return 0;
    }
    label_length = label_length * 10 + digit;
    *offset += 1;
  }
  if (*offset >= length || bytes[*offset] != ':') {
    return 0;
  }
  *offset += 1;
  if (label_length < 0 || label_length > length - *offset) {
    return 0;
  }
  command->label = (char *)malloc((size_t)label_length + 1);
  if (!command->label) {
    return 0;
  }
  memcpy(command->label, bytes + *offset, (size_t)label_length);
  command->label[label_length] = '\0';
  *offset += label_length;
  if (*offset < length && bytes[*offset] == '\n') {
    *offset += 1;
  }
  return 1;
}

static MouiLinuxMenuCommand *parse_menu_commands(const char *bytes,
                                                 int32_t length,
                                                 int32_t *count_out) {
  int32_t count = 1;
  for (int32_t i = 0; i < length; ++i) {
    if (bytes[i] == '\n') {
      count += 1;
    }
  }
  MouiLinuxMenuCommand *commands =
      (MouiLinuxMenuCommand *)calloc((size_t)count, sizeof(MouiLinuxMenuCommand));
  if (!commands) {
    return NULL;
  }
  int32_t offset = 0;
  int32_t parsed = 0;
  while (offset < length) {
    if (!parse_menu_command(bytes, length, &offset, &commands[parsed])) {
      free_menu_commands(commands, parsed + 1);
      return NULL;
    }
    parsed += 1;
  }
  *count_out = parsed;
  return commands;
}

static int command_exists(const char *name) {
  size_t command_len = strlen(name) + 32;
  char *command = (char *)malloc(command_len);
  if (!command) {
    return 0;
  }
  snprintf(command, command_len, "command -v %s >/dev/null 2>&1", name);
  int ok = run_command(command);
  free(command);
  return ok;
}

static char *menu_display_label(const MouiLinuxMenuCommand *command) {
  if (command->enabled) {
    return strdup(command->label ? command->label : "");
  }
  const char *label = command->label ? command->label : "";
  size_t len = strlen(label) + 12;
  char *display = (char *)malloc(len);
  if (!display) {
    return NULL;
  }
  snprintf(display, len, "%s (disabled)", label);
  return display;
}

static char *build_zenity_menu_command(MouiLinuxMenuCommand *commands,
                                       int32_t count) {
  size_t len = 0;
  size_t capacity = 0;
  char *command = NULL;
  command = append_text(command, &len, &capacity,
                        "zenity --list --title='MoUI Menu' --hide-header "
                        "--hide-column=1 --print-column=1 "
                        "--column='Index' --column='Command'");
  for (int32_t i = 0; i < count && command; ++i) {
    char index[32];
    snprintf(index, sizeof(index), "%d", i);
    char *display = menu_display_label(&commands[i]);
    char *quoted_index = shell_quote(index);
    char *quoted_label = shell_quote(display ? display : "");
    free(display);
    if (!quoted_index || !quoted_label) {
      free(quoted_index);
      free(quoted_label);
      free(command);
      return NULL;
    }
    command = append_text(command, &len, &capacity, " ");
    command = append_text(command, &len, &capacity, quoted_index);
    command = append_text(command, &len, &capacity, " ");
    command = append_text(command, &len, &capacity, quoted_label);
    free(quoted_index);
    free(quoted_label);
  }
  if (command) {
    command = append_text(command, &len, &capacity, " 2>/dev/null");
  }
  return command;
}

static char *build_kdialog_menu_command(MouiLinuxMenuCommand *commands,
                                        int32_t count) {
  size_t len = 0;
  size_t capacity = 0;
  char *command = NULL;
  command = append_text(command, &len, &capacity, "kdialog --menu 'MoUI Menu'");
  for (int32_t i = 0; i < count && command; ++i) {
    char index[32];
    snprintf(index, sizeof(index), "%d", i);
    char *display = menu_display_label(&commands[i]);
    char *quoted_index = shell_quote(index);
    char *quoted_label = shell_quote(display ? display : "");
    free(display);
    if (!quoted_index || !quoted_label) {
      free(quoted_index);
      free(quoted_label);
      free(command);
      return NULL;
    }
    command = append_text(command, &len, &capacity, " ");
    command = append_text(command, &len, &capacity, quoted_index);
    command = append_text(command, &len, &capacity, " ");
    command = append_text(command, &len, &capacity, quoted_label);
    free(quoted_index);
    free(quoted_label);
  }
  if (command) {
    command = append_text(command, &len, &capacity, " 2>/dev/null");
  }
  return command;
}

static int32_t parse_selected_menu_index(const char *selection, int32_t count) {
  if (!selection || !selection[0]) {
    return -1;
  }
  errno = 0;
  char *end = NULL;
  long value = strtol(selection, &end, 10);
  if (errno != 0 || end == selection || value < 0 || value >= count) {
    return -1;
  }
  while (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r') {
    end++;
  }
  if (*end != '\0') {
    return -1;
  }
  return (int32_t)value;
}

static int32_t show_menu_with_command(char *command, int32_t count) {
  if (!command) {
    return -2;
  }
  char *selection = capture_command(command);
  free(command);
  int32_t selected = parse_selected_menu_index(selection, count);
  free(selection);
  return selected;
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

static char *moui_linux_settings_directory(void) {
  const char *xdg = getenv("XDG_CONFIG_HOME");
  const char *home = getenv("HOME");
  char *base = NULL;
  if (xdg && xdg[0]) {
    base = strdup(xdg);
  } else if (home && home[0]) {
    size_t length = strlen(home) + strlen("/.config") + 1;
    base = (char *)malloc(length);
    if (base) {
      snprintf(base, length, "%s/.config", home);
    }
  }
  if (!base) {
    return NULL;
  }
  size_t moui_length = strlen(base) + strlen("/moui") + 1;
  char *moui = (char *)malloc(moui_length);
  if (!moui) {
    free(base);
    return NULL;
  }
  snprintf(moui, moui_length, "%s/moui", base);
  size_t settings_length = strlen(moui) + strlen("/settings") + 1;
  char *settings = (char *)malloc(settings_length);
  if (!settings) {
    free(moui);
    free(base);
    return NULL;
  }
  snprintf(settings, settings_length, "%s/settings", moui);
  if ((mkdir(base, 0700) != 0 && errno != EEXIST) ||
      (mkdir(moui, 0700) != 0 && errno != EEXIST) ||
      (mkdir(settings, 0700) != 0 && errno != EEXIST)) {
    free(settings);
    settings = NULL;
  }
  free(moui);
  free(base);
  return settings;
}

static char *moui_linux_settings_path(moonbit_bytes_t key) {
  int32_t key_length = (int32_t)Moonbit_array_length(key);
  if (key_length <= 0) {
    return NULL;
  }
  char *directory = moui_linux_settings_directory();
  if (!directory) {
    return NULL;
  }
  static const char digits[] = "0123456789abcdef";
  size_t directory_length = strlen(directory);
  size_t path_length = directory_length + 1 + (size_t)key_length * 2 + 1;
  char *path = (char *)malloc(path_length);
  if (!path) {
    free(directory);
    return NULL;
  }
  memcpy(path, directory, directory_length);
  path[directory_length] = '/';
  for (int32_t i = 0; i < key_length; ++i) {
    uint8_t byte = ((const uint8_t *)key)[i];
    path[directory_length + 1 + (size_t)i * 2] = digits[byte >> 4];
    path[directory_length + 2 + (size_t)i * 2] = digits[byte & 0x0f];
  }
  path[path_length - 1] = '\0';
  free(directory);
  return path;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_has_value(moonbit_bytes_t key) {
  char *path = moui_linux_settings_path(key);
  if (!path) {
    return 0;
  }
  int exists = access(path, F_OK) == 0 ? 1 : 0;
  free(path);
  return exists;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_settings_read(moonbit_bytes_t key) {
  char *path = moui_linux_settings_path(key);
  if (!path) {
    return moonbit_make_bytes(0, 0);
  }
  FILE *file = fopen(path, "rb");
  free(path);
  if (!file || fseek(file, 0, SEEK_END) != 0) {
    if (file) fclose(file);
    return moonbit_make_bytes(0, 0);
  }
  long size = ftell(file);
  if (size < 0 || size > INT32_MAX || fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)size, 0);
  if (size > 0 && fread(result, 1, (size_t)size, file) != (size_t)size) {
    fclose(file);
    return moonbit_make_bytes(0, 0);
  }
  fclose(file);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_write(moonbit_bytes_t key, moonbit_bytes_t value) {
  char *path = moui_linux_settings_path(key);
  if (!path) {
    return 0;
  }
  size_t temp_length = strlen(path) + 48;
  char *temp = (char *)malloc(temp_length);
  if (!temp) {
    free(path);
    return 0;
  }
  snprintf(temp, temp_length, "%s.tmp.%ld", path, (long)getpid());
  FILE *file = fopen(temp, "wb");
  int32_t value_length = (int32_t)Moonbit_array_length(value);
  int ok = file != NULL;
  if (ok && value_length > 0) {
    ok = fwrite(value, 1, (size_t)value_length, file) == (size_t)value_length;
  }
  if (file && fclose(file) != 0) {
    ok = 0;
  }
  if (ok) {
    chmod(temp, 0600);
    ok = rename(temp, path) == 0;
  }
  if (!ok) {
    unlink(temp);
  }
  free(temp);
  free(path);
  return ok ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_remove(moonbit_bytes_t key) {
  char *path = moui_linux_settings_path(key);
  if (!path) {
    return 0;
  }
  int ok = unlink(path) == 0 || errno == ENOENT;
  free(path);
  return ok ? 1 : 0;
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

MOONBIT_FFI_EXPORT
int32_t moui_linux_show_menu(moonbit_bytes_t commands_bytes) {
  int32_t length = (int32_t)Moonbit_array_length(commands_bytes);
  if (length <= 0) {
    return -1;
  }
  int32_t count = 0;
  MouiLinuxMenuCommand *commands =
      parse_menu_commands((const char *)commands_bytes, length, &count);
  if (!commands || count <= 0) {
    free_menu_commands(commands, count);
    return -2;
  }

  int32_t selected = -2;
  if (command_exists("zenity")) {
    selected = show_menu_with_command(build_zenity_menu_command(commands, count),
                                      count);
  }
  if (selected == -2 && command_exists("kdialog")) {
    selected = show_menu_with_command(build_kdialog_menu_command(commands, count),
                                      count);
  }
  free_menu_commands(commands, count);
  return selected;
}

///|
/// Clipboard image support.
/// Uses wl-clipboard (wl-paste/wl-copy) to read/write PNG images.
MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_clipboard_read_image() {
  // Read binary clipboard image data with a dynamic buffer.
  // Primary: wl-paste for PNG images.
  moonbit_bytes_t result = read_binary_command(
    "wl-paste --type image/png 2>/dev/null");
  if (result && Moonbit_array_length(result) > 0) {
    return result;
  }
  // Fallback: try GTK for older environments.
  result = read_binary_command(
    "gdbus call --session --dest org.gtk.Clipboard "
    "--object-path /org/gtk/Clipboard "
    "--method org.gtk.Clipboard.ReadImage 2>/dev/null");
  if (result) {
    return result;
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_clipboard_write_image(moonbit_bytes_t mime,
                                         moonbit_bytes_t data) {
  if (!data) {
    return 0;
  }
  int32_t data_len = (int32_t)Moonbit_array_length(data);
  if (data_len <= 0) {
    return 0;
  }
  // Choose MIME type: use the provided mime or default to image/png.
  const char *mime_type = "image/png";
  if (mime) {
    int32_t mime_len = (int32_t)Moonbit_array_length(mime);
    if (mime_len > 0) {
      // Accept common image MIME types passed from MoonBit.
      const char *mime_cstr = (const char *)mime;
      if (strncmp(mime_cstr, "image/", 6) == 0) {
        mime_type = mime_cstr;
      }
    }
  }
  // Primary: wl-copy with the resolved MIME type.
  size_t cmd_len = strlen(mime_type) + 64;
  char *cmd = (char *)malloc(cmd_len);
  if (!cmd) {
    return 0;
  }
  snprintf(cmd, cmd_len, "wl-copy --type %s 2>/dev/null", mime_type);
  FILE *pipe = popen(cmd, "w");
  free(cmd);
  if (!pipe) {
    return 0;
  }
  size_t written = fwrite(data, 1, (size_t)data_len, pipe);
  int status = pclose(pipe);
  if (written != (size_t)data_len || status != 0) {
    return 0;
  }
  return 1;
}

#else

#include <stdint.h>
#include <stdio.h>
#include <moonbit.h>

MOONBIT_FFI_EXPORT int32_t moui_linux_accessibility_high_contrast(void) { return 0; }
MOONBIT_FFI_EXPORT int32_t moui_linux_accessibility_reduce_motion(void) { return 0; }
MOONBIT_FFI_EXPORT double moui_linux_accessibility_text_scale(void) { return 0.0; }

MOONBIT_FFI_EXPORT
int32_t moui_linux_open_url(const uint8_t *url, int32_t url_len) {
  (void)url;
  (void)url_len;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_has_value(moonbit_bytes_t key) {
  (void)key;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_settings_read(moonbit_bytes_t key) {
  (void)key;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_write(moonbit_bytes_t key, moonbit_bytes_t value) {
  (void)key;
  (void)value;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_settings_remove(moonbit_bytes_t key) {
  (void)key;
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

MOONBIT_FFI_EXPORT
int32_t moui_linux_show_menu(moonbit_bytes_t commands) {
  (void)commands;
  return -2;
}

///|
/// Clipboard image stubs.
/// These functions are only called on Linux; non-Linux stubs return empty.
MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_clipboard_read_image() {
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_clipboard_write_image(moonbit_bytes_t mime,
                                         moonbit_bytes_t data) {
  (void)mime;
  (void)data;
  return 0;
}

#endif
