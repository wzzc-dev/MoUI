#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

static NSString *const MOUI_MACOS_SURFACE_LAYER_NAME = @"moui_macos_surface_layer";
static NSString *const MOUI_MACOS_SKIA_LAYER_NAME = @"moui_macos_skia_pixel_layer";

enum {
  MOUI_MACOS_SKIA_PRESENT_OK = 0,
  MOUI_MACOS_SKIA_PRESENT_BAD_VIEW = 1,
  MOUI_MACOS_SKIA_PRESENT_BAD_DIMENSIONS = 2,
  MOUI_MACOS_SKIA_PRESENT_BAD_PIXELS = 3,
  MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED = 4,
};

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

static int64_t moui_macos_skia_expected_pixel_bytes(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return -1;
  }
  int64_t packed_row_bytes = (int64_t)width * 4;
  if (height > INT32_MAX / packed_row_bytes) {
    return -1;
  }
  return packed_row_bytes * height;
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
void *moui_macos_surface_host_layer_from_view(uint64_t raw_content_view_handle, int32_t width,
                                              int32_t height, double scale_factor) {
  if (raw_content_view_handle == 0) {
    return NULL;
  }

  NSView *view = (__bridge NSView *)(void *)raw_content_view_handle;
  if (view == nil) {
    return NULL;
  }

  view.wantsLayer = YES;

  CAMetalLayer *metal_layer = nil;
  CALayer *existing_layer = view.layer;
  if ([existing_layer isKindOfClass:[CAMetalLayer class]]) {
    metal_layer = (CAMetalLayer *)existing_layer;
  }

  if (metal_layer == nil) {
    metal_layer = [CAMetalLayer layer];
    metal_layer.name = MOUI_MACOS_SURFACE_LAYER_NAME;
    view.layer = metal_layer;
    view.wantsLayer = YES;
  }

  double layer_scale = scale_factor > 0.0 ? scale_factor : view.window.backingScaleFactor;
  if (layer_scale <= 0.0) {
    layer_scale = 1.0;
  }
  CGRect bounds = view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0, width / layer_scale, height / layer_scale);
  }
  if (bounds.size.width <= 0.0) {
    bounds.size.width = 1.0;
  }
  if (bounds.size.height <= 0.0) {
    bounds.size.height = 1.0;
  }
  metal_layer.frame = bounds;
  metal_layer.bounds = CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height);
  metal_layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
  metal_layer.contentsScale = layer_scale;
  metal_layer.drawableSize = CGSizeMake(width > 0 ? width : bounds.size.width * layer_scale,
                                        height > 0 ? height : bounds.size.height * layer_scale);
  metal_layer.opaque = YES;

  return (void *)metal_layer;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_present_skia_pixels_to_view(uint64_t raw_content_view_handle,
                                               int32_t width, int32_t height,
                                               int32_t row_bytes,
                                               const uint8_t *pixels,
                                               int32_t pixels_len) {
  if (raw_content_view_handle == 0) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_VIEW;
  }
  NSView *view = (__bridge NSView *)(void *)raw_content_view_handle;
  if (view == nil) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_VIEW;
  }

  int64_t expected_len = moui_macos_skia_expected_pixel_bytes(width, height);
  int64_t packed_row_bytes = expected_len > 0 ? (int64_t)width * 4 : 0;
  if (expected_len <= 0 || row_bytes < packed_row_bytes) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * height;
  if (required_len <= 0 || required_len > INT32_MAX || pixels == NULL || pixels_len < required_len) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_PIXELS;
  }

  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)expected_len];
  if (data == nil || data.mutableBytes == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * (size_t)packed_row_bytes,
           pixels + (size_t)y * (size_t)row_bytes,
           (size_t)packed_row_bytes);
  }

  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  if (color_space == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  if (provider == NULL) {
    CGColorSpaceRelease(color_space);
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGBitmapInfo bitmap_info = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32,
                                   (size_t)packed_row_bytes, color_space,
                                   bitmap_info, provider, NULL, false,
                                   kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(color_space);
  if (image == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }

  view.wantsLayer = YES;
  CALayer *layer = nil;
  for (CALayer *sublayer in view.layer.sublayers) {
    if ([sublayer.name isEqualToString:MOUI_MACOS_SKIA_LAYER_NAME]) {
      layer = sublayer;
      break;
    }
  }
  if (layer == nil) {
    layer = [CALayer layer];
    layer.name = MOUI_MACOS_SKIA_LAYER_NAME;
    layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    layer.contentsGravity = kCAGravityResize;
    [view.layer addSublayer:layer];
  }

  CGFloat scale = view.window.backingScaleFactor > 0.0 ? view.window.backingScaleFactor : 1.0;
  layer.frame = view.bounds;
  layer.bounds = CGRectMake(0.0, 0.0, view.bounds.size.width, view.bounds.size.height);
  layer.contentsScale = scale;
  layer.contents = (__bridge id)image;
  [layer setNeedsDisplay];

  CGImageRelease(image);
  return MOUI_MACOS_SKIA_PRESENT_OK;
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
