#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

static NSString *const MOUI_MACOS_SURFACE_LAYER_NAME = @"moui_macos_surface_layer";

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
