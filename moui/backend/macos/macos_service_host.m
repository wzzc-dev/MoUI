#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

@interface MouiMacosMenuTarget : NSObject
@property(nonatomic) NSInteger selectedIndex;
- (void)selectItem:(id)sender;
@end

@implementation MouiMacosMenuTarget
- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _selectedIndex = -1;
  }
  return self;
}

- (void)selectItem:(id)sender {
  if ([sender respondsToSelector:@selector(tag)]) {
    self.selectedIndex = [sender tag];
  }
}
@end

static NSString *moui_macos_string_from_bytes(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    return @"";
  }
  NSString *string = [[NSString alloc] initWithBytes:(const void *)bytes
                                             length:(NSUInteger)len
                                           encoding:NSUTF8StringEncoding];
  return string != nil ? string : @"";
}

static moonbit_bytes_t moui_macos_bytes_from_string(NSString *string) {
  if (string == nil) {
    return moonbit_make_bytes(0, 0);
  }
  const char *utf8 = [string UTF8String];
  if (utf8 == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(utf8);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(bytes, utf8, len);
  }
  return bytes;
}

static id<NSTextInputClient> moui_macos_native_ime_text_input_client(uint64_t raw_content_view_handle) {
  if (raw_content_view_handle == 0 || ![NSThread isMainThread]) {
    return nil;
  }
  id view = (__bridge id)(void *)raw_content_view_handle;
  if (view == nil || ![view conformsToProtocol:@protocol(NSTextInputClient)]) {
    return nil;
  }
  return (id<NSTextInputClient>)view;
}

static NSRange moui_macos_range_from_i32(int32_t location, int32_t length) {
  NSUInteger safe_location = location < 0 ? 0 : (NSUInteger)location;
  NSUInteger safe_length = length < 0 ? 0 : (NSUInteger)length;
  return NSMakeRange(safe_location, safe_length);
}

static NSArray<NSString *> *moui_macos_filter_extensions(moonbit_bytes_t filters) {
  NSString *filter_string = moui_macos_string_from_bytes(filters);
  if ([filter_string length] == 0) {
    return @[];
  }
  NSMutableArray<NSString *> *extensions = [NSMutableArray array];
  for (NSString *raw in [filter_string componentsSeparatedByString:@"\n"]) {
    NSString *item = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([item length] == 0) {
      continue;
    }
    if ([item hasPrefix:@"*."]) {
      item = [item substringFromIndex:2];
    } else if ([item hasPrefix:@"."]) {
      item = [item substringFromIndex:1];
    }
    if ([item length] > 0) {
      [extensions addObject:item];
    }
  }
  return extensions;
}

static moonbit_bytes_t moui_macos_file_dialog_result(NSArray<NSURL *> *urls) {
  NSMutableArray<NSString *> *paths = [NSMutableArray array];
  for (NSURL *url in urls) {
    NSString *path = [url path];
    if (path != nil && [path length] > 0) {
      [paths addObject:path];
    }
  }
  return moui_macos_bytes_from_string([paths componentsJoinedByString:@"\n"]);
}

static void moui_macos_apply_file_filters(NSSavePanel *panel, NSArray<NSString *> *extensions) {
  if ([extensions count] == 0) {
    return;
  }
  NSMutableArray<UTType *> *types = [NSMutableArray array];
  for (NSString *extension in extensions) {
    UTType *type = [UTType typeWithFilenameExtension:extension];
    if (type != nil) {
      [types addObject:type];
    }
  }
  if ([types count] > 0) {
    [panel setAllowedContentTypes:types];
  }
}

static BOOL moui_macos_parse_menu_command(const char *bytes, int32_t length, int32_t *offset,
                                          BOOL *enabled, NSString **label) {
  if (*offset >= length) {
    return NO;
  }
  char enabled_char = bytes[*offset];
  if (enabled_char != '0' && enabled_char != '1') {
    return NO;
  }
  *enabled = enabled_char == '1';
  *offset += 1;
  if (*offset >= length || bytes[*offset] != ':') {
    return NO;
  }
  *offset += 1;
  int32_t label_length = 0;
  while (*offset < length && bytes[*offset] >= '0' && bytes[*offset] <= '9') {
    int32_t digit = bytes[*offset] - '0';
    if (label_length > (INT32_MAX - digit) / 10) {
      return NO;
    }
    label_length = label_length * 10 + digit;
    *offset += 1;
  }
  if (*offset >= length || bytes[*offset] != ':') {
    return NO;
  }
  *offset += 1;
  if (label_length < 0 || label_length > length - *offset) {
    return NO;
  }
  NSString *parsed_label = [[NSString alloc] initWithBytes:bytes + *offset
                                                    length:(NSUInteger)label_length
                                                  encoding:NSUTF8StringEncoding];
  if (parsed_label == nil && label_length > 0) {
    return NO;
  }
  if (parsed_label == nil) {
    parsed_label = @"";
  }
  *label = parsed_label;
  *offset += label_length;
  if (*offset < length && bytes[*offset] == '\n') {
    *offset += 1;
  }
  return YES;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_clipboard_has_text(void) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
  return text != nil ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_clipboard_read_text(void) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
  return moui_macos_bytes_from_string(text);
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_clipboard_write_text(moonbit_bytes_t text) {
  NSString *string = moui_macos_string_from_bytes(text);
  if ([string length] == 0 && Moonbit_array_length(text) > 0) {
    return 0;
  }
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  BOOL ok = [pasteboard setString:string forType:NSPasteboardTypeString];
  return ok ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_clipboard_has_image(void) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSArray *classes = @[[NSImage class]];
  return [pasteboard canReadObjectForClasses:classes options:@{}] ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_clipboard_read_image(void) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  // Try PNG first, then TIFF (convert to PNG)
  NSData *imageData = [pasteboard dataForType:NSPasteboardTypePNG];
  if (imageData == nil) {
    imageData = [pasteboard dataForType:NSPasteboardTypeTIFF];
    if (imageData != nil) {
      NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:imageData];
      if (rep != nil) {
        imageData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
      }
    }
  }
  if (imageData == nil) {
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)[imageData length];
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(bytes, [imageData bytes], (size_t)len);
  }
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_clipboard_write_image(moonbit_bytes_t data) {
  int32_t len = (int32_t)Moonbit_array_length(data);
  if (len <= 0) {
    return 0;
  }
  NSData *imageData = [NSData dataWithBytes:(const void *)data length:(NSUInteger)len];
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  BOOL ok = [pasteboard setData:imageData forType:NSPasteboardTypePNG];
  return ok ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_open_url(moonbit_bytes_t url) {
  int32_t url_len = (int32_t)Moonbit_array_length(url);
  if (url_len <= 0) {
    return 0;
  }
  NSString *string = [[NSString alloc] initWithBytes:(const void *)url
                                             length:(NSUInteger)url_len
                                           encoding:NSUTF8StringEncoding];
  if (string == nil) {
    return 0;
  }
  NSURL *ns_url = [NSURL URLWithString:string];
  if (ns_url == nil) {
    return 0;
  }
  BOOL ok = [[NSWorkspace sharedWorkspace] openURL:ns_url];
  return ok ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_system_theme_is_dark(void) {
  NSAppearance *appearance = nil;
  if (NSApp != nil) {
    appearance = [NSApp effectiveAppearance];
  }
  if (appearance == nil) {
    appearance = [NSAppearance currentDrawingAppearance];
  }
  if (appearance == nil) {
    appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  }
  NSString *match = [appearance bestMatchFromAppearancesWithNames:@[
    NSAppearanceNameAqua,
    NSAppearanceNameDarkAqua,
  ]];
  return [match isEqualToString:NSAppearanceNameDarkAqua] ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_accessibility_increase_contrast(void) {
  return [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldIncreaseContrast] ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_accessibility_reduce_motion(void) {
  return [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion] ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_settings_has_value(moonbit_bytes_t key) {
  NSString *name = moui_macos_string_from_bytes(key);
  if ([name length] == 0) {
    return 0;
  }
  return [[NSUserDefaults standardUserDefaults] objectForKey:name] != nil ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_settings_read(moonbit_bytes_t key) {
  NSString *name = moui_macos_string_from_bytes(key);
  if ([name length] == 0) {
    return moonbit_make_bytes(0, 0);
  }
  NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:name];
  return moui_macos_bytes_from_string(value);
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_settings_write(moonbit_bytes_t key, moonbit_bytes_t value) {
  NSString *name = moui_macos_string_from_bytes(key);
  NSString *text = moui_macos_string_from_bytes(value);
  if ([name length] == 0 || (Moonbit_array_length(value) > 0 && [text length] == 0)) {
    return 0;
  }
  [[NSUserDefaults standardUserDefaults] setObject:text forKey:name];
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_settings_remove(moonbit_bytes_t key) {
  NSString *name = moui_macos_string_from_bytes(key);
  if ([name length] == 0) {
    return 0;
  }
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:name];
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_native_ime_smoke_set_marked_text(uint64_t raw_content_view_handle,
                                                       moonbit_bytes_t text,
                                                       int32_t selected_location,
                                                       int32_t selected_length) {
  id<NSTextInputClient> client =
      moui_macos_native_ime_text_input_client(raw_content_view_handle);
  if (client == nil ||
      ![(id)client respondsToSelector:@selector(setMarkedText:selectedRange:replacementRange:)]) {
    return 0;
  }
  NSString *string = moui_macos_string_from_bytes(text);
  if ([string length] == 0 && Moonbit_array_length(text) > 0) {
    return 0;
  }
  [client setMarkedText:string
          selectedRange:moui_macos_range_from_i32(selected_location, selected_length)
       replacementRange:NSMakeRange(NSNotFound, 0)];
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_native_ime_smoke_first_rect(uint64_t raw_content_view_handle,
                                                 int32_t location,
                                                 int32_t length) {
  id<NSTextInputClient> client =
      moui_macos_native_ime_text_input_client(raw_content_view_handle);
  if (client == nil ||
      ![(id)client respondsToSelector:@selector(firstRectForCharacterRange:actualRange:)]) {
    return 0;
  }
  NSRange actual_range = NSMakeRange(NSNotFound, 0);
  NSRect rect = [client firstRectForCharacterRange:moui_macos_range_from_i32(location, length)
                                      actualRange:&actual_range];
  return rect.size.width > 0.0 && rect.size.height > 0.0 ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_native_ime_smoke_insert_text(uint64_t raw_content_view_handle,
                                                  moonbit_bytes_t text) {
  id<NSTextInputClient> client =
      moui_macos_native_ime_text_input_client(raw_content_view_handle);
  if (client == nil || ![(id)client respondsToSelector:@selector(insertText:replacementRange:)]) {
    return 0;
  }
  NSString *string = moui_macos_string_from_bytes(text);
  if ([string length] == 0 && Moonbit_array_length(text) > 0) {
    return 0;
  }
  [client insertText:string replacementRange:NSMakeRange(NSNotFound, 0)];
  return 1;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_file_dialog(int32_t kind, moonbit_bytes_t title, moonbit_bytes_t filters,
                                       moonbit_bytes_t default_name) {
  NSString *panel_title = moui_macos_string_from_bytes(title);
  NSArray<NSString *> *extensions = moui_macos_filter_extensions(filters);

  if (kind == 1) {
    NSSavePanel *panel = [NSSavePanel savePanel];
    if ([panel_title length] > 0) {
      [panel setTitle:panel_title];
    }
    NSString *name = moui_macos_string_from_bytes(default_name);
    if ([name length] > 0) {
      [panel setNameFieldStringValue:name];
    }
    moui_macos_apply_file_filters(panel, extensions);
    if ([panel runModal] == NSModalResponseOK && [panel URL] != nil) {
      return moui_macos_file_dialog_result(@[[panel URL]]);
    }
    return moonbit_make_bytes(0, 0);
  }

  NSOpenPanel *panel = [NSOpenPanel openPanel];
  if ([panel_title length] > 0) {
    [panel setTitle:panel_title];
  }
  if (kind == 2) {
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
  } else {
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:YES];
    moui_macos_apply_file_filters(panel, extensions);
  }
  if ([panel runModal] == NSModalResponseOK) {
    return moui_macos_file_dialog_result([panel URLs]);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_show_menu(moonbit_bytes_t commands) {
  int32_t length = (int32_t)Moonbit_array_length(commands);
  if (length <= 0) {
    return -1;
  }
  const char *bytes = (const char *)commands;
  int32_t offset = 0;
  int32_t index = 0;
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  MouiMacosMenuTarget *target = [[MouiMacosMenuTarget alloc] init];

  while (offset < length) {
    BOOL enabled = NO;
    NSString *label = nil;
    if (!moui_macos_parse_menu_command(bytes, length, &offset, &enabled, &label)) {
      return -1;
    }
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:label action:@selector(selectItem:) keyEquivalent:@""];
    [item setTarget:target];
    [item setTag:index];
    [item setEnabled:enabled];
    [menu addItem:item];
    index += 1;
  }

  if (index == 0) {
    return -1;
  }

  [menu popUpMenuPositioningItem:nil atLocation:[NSEvent mouseLocation] inView:nil];
  return (int32_t)[target selectedIndex];
}
