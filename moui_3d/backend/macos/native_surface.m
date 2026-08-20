#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <moonbit.h>
#include <objc/runtime.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef void (*moui_macos_3d_event_trampoline_t)(
    void *closure, uint64_t native_view, int32_t kind, moonbit_bytes_t id,
    moonbit_bytes_t value, moonbit_bytes_t detail, int32_t flag);

static moui_macos_3d_event_trampoline_t g_event_trampoline = NULL;
static void *g_event_closure = NULL;

static moonbit_bytes_t moui_3d_bytes(const char *text) {
  const size_t length = text == NULL ? 0 : strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)length, 0);
  if (length > 0) memcpy(bytes, text, length);
  return bytes;
}

@interface NSView (MOUI3DOverlayStateKey)
- (BOOL)mouiOverlayActive;
- (NSValue *)mouiOverlayRect;
@end

@interface MOUIMetal3DView : NSView
@property(nonatomic, assign) uint64_t parentHandle;
@property(nonatomic, copy) NSString *viewportId;
@property(nonatomic, assign) BOOL hasOverlayExclusion;
@property(nonatomic, assign) NSRect overlayExclusionRect;
@end

@implementation MOUIMetal3DView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
  BOOL accepted = [super becomeFirstResponder];
  if (accepted) [self emit:5 value:@"" detail:@"" flag:YES];
  return accepted;
}
- (BOOL)resignFirstResponder {
  BOOL resigned = [super resignFirstResponder];
  if (resigned) [self emit:5 value:@"" detail:@"" flag:NO];
  return resigned;
}
- (NSView *)hitTest:(NSPoint)point {
  if (self.hasOverlayExclusion && NSPointInRect(point, self.overlayExclusionRect)) {
    return self.superview;
  }
  return [super hitTest:point];
}
- (void)emit:(int32_t)kind value:(NSString *)value detail:(NSString *)detail flag:(int32_t)flag {
  if (g_event_trampoline == NULL || g_event_closure == NULL) return;
  g_event_trampoline(g_event_closure, self.parentHandle, kind,
                     moui_3d_bytes(self.viewportId.UTF8String),
                     moui_3d_bytes(value.UTF8String),
                     moui_3d_bytes(detail.UTF8String), flag);
}
- (void)mouseDown:(NSEvent *)event {
  [self.window makeFirstResponder:self];
  NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
  [self emit:1 value:[NSString stringWithFormat:@"%.3f,%.3f", point.x, point.y]
       detail:@"" flag:0];
}
- (void)mouseDragged:(NSEvent *)event {
  NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
  [self emit:2 value:[NSString stringWithFormat:@"%.3f,%.3f", point.x, point.y]
       detail:@"" flag:0];
}
- (void)mouseUp:(NSEvent *)event {
  NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
  [self emit:3 value:[NSString stringWithFormat:@"%.3f,%.3f", point.x, point.y]
       detail:@"" flag:0];
}
- (void)scrollWheel:(NSEvent *)event {
  [self emit:4 value:[NSString stringWithFormat:@"%.3f", event.scrollingDeltaY]
       detail:@"" flag:0];
}
- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  if (self.window == nil) [self emit:5 value:@"" detail:@"" flag:NO];
}
@end

typedef struct MOUIMetal3DRecord {
  uint64_t parent;
  char *identifier;
  MOUIMetal3DView *view;
  BOOL seen;
  struct MOUIMetal3DRecord *next;
} MOUIMetal3DRecord;

static MOUIMetal3DRecord *g_records = NULL;

static MOUIMetal3DRecord *moui_3d_find(uint64_t parent, const char *identifier) {
  for (MOUIMetal3DRecord *record = g_records; record != NULL; record = record->next) {
    if (record->parent == parent && strcmp(record->identifier, identifier) == 0) return record;
  }
  return NULL;
}

int32_t moui_macos_3d_available(void) { return 1; }

void moui_macos_3d_install_event_callback(
    moui_macos_3d_event_trampoline_t trampoline, void *closure) {
  // Keep the ABI in the same order as the MoonBit FFI declaration and the
  // existing native platform-view bridges: trampoline first, closure second.
  // Reversing these pointers only fails when the first native pointer event
  // tries to invoke the stored callback.
  if (g_event_closure != NULL) {
    moonbit_decref(g_event_closure);
  }
  g_event_trampoline = trampoline;
  g_event_closure = closure;
}

void moui_macos_3d_platform_views_begin(uint64_t parent) {
  for (MOUIMetal3DRecord *record = g_records; record != NULL; record = record->next) {
    if (record->parent == parent) record->seen = NO;
  }
}

uint64_t moui_macos_3d_sync(uint64_t parent, moonbit_bytes_t id_bytes,
                            double x, double y, double width, double height,
                            double scale_factor) {
  const int32_t length = (int32_t)Moonbit_array_length(id_bytes);
  char *identifier = (char *)calloc((size_t)length + 1, 1);
  if (identifier == NULL) return 0;
  if (length > 0) memcpy(identifier, id_bytes, (size_t)length);
  NSView *parent_view = (NSView *)(uintptr_t)parent;
  if (parent_view == nil) { free(identifier); return 0; }
  MOUIMetal3DRecord *record = moui_3d_find(parent, identifier);
  CGFloat effective_scale = parent_view.window.backingScaleFactor;
  if (effective_scale <= 0) effective_scale = scale_factor > 0 ? scale_factor : 1.0;
  if (record == NULL) {
    record = (MOUIMetal3DRecord *)calloc(1, sizeof(*record));
    record->parent = parent;
    record->identifier = strdup(identifier);
    record->view = [[[MOUIMetal3DView alloc] initWithFrame:NSZeroRect] autorelease];
    record->view.parentHandle = parent;
    record->view.viewportId = [NSString stringWithUTF8String:identifier] ?: @"";
    record->view.wantsLayer = YES;
    record->view.layer = [CAMetalLayer layer];
    record->view.layer.contentsScale = effective_scale;
    [parent_view addSubview:record->view positioned:NSWindowAbove relativeTo:nil];
    record->next = g_records;
    g_records = record;
  }
  free(identifier);
  record->seen = YES;
  record->view.frame = NSMakeRect(x, y, width, height);
  CAMetalLayer *metal_layer = (CAMetalLayer *)record->view.layer;
  metal_layer.contentsScale = effective_scale;
  metal_layer.drawableSize = CGSizeMake(width * metal_layer.contentsScale,
                                        height * metal_layer.contentsScale);
  return (uint64_t)(uintptr_t)record->view.layer;
}

static void moui_3d_sync_presenter_overlay(NSView *parent, BOOL active,
                                           NSRect rect) {
  if (parent == nil) return;
  NSView *presenter = nil;
  for (NSView *subview in parent.subviews) {
    NSString *identifier = subview.identifier;
    if ([identifier isEqualToString:@"moui_host_pixel_image_view"] ||
        [identifier isEqualToString:@"moui_host_gpu_surface_view"]) {
      presenter = subview;
      break;
    }
  }
  if (presenter == nil) return;
  objc_setAssociatedObject(
      presenter, @selector(mouiOverlayActive), @(active),
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(
      parent, @selector(mouiOverlayRect),
      active ? [NSValue valueWithRect:rect] : nil,
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void moui_macos_3d_sync_overlay_mask(uint64_t parent_handle,
                                     moonbit_bytes_t id_bytes,
                                     int32_t has_bounds, double x, double y,
                                     double width, double height) {
  NSView *parent = (NSView *)(uintptr_t)parent_handle;
  if (parent == nil) return;
  const int32_t length = (int32_t)Moonbit_array_length(id_bytes);
  char *identifier = (char *)calloc((size_t)length + 1, 1);
  if (identifier == NULL) return;
  if (length > 0) memcpy(identifier, id_bytes, (size_t)length);
  MOUIMetal3DRecord *record = moui_3d_find(parent_handle, identifier);
  free(identifier);
  if (record == NULL) return;
  BOOL active = has_bounds != 0;
  NSRect overlay = NSMakeRect(x, y, width, height);
  NSRect local = [record->view convertRect:overlay fromView:parent];
  NSRect clipped = active
      ? NSIntersectionRect(local, record->view.bounds)
      : NSZeroRect;
  active = active && !NSIsEmptyRect(clipped);
  record->view.hasOverlayExclusion = active;
  record->view.overlayExclusionRect = clipped;
  moui_3d_sync_presenter_overlay(parent, active, overlay);
  NSView *presenter = nil;
  for (NSView *subview in parent.subviews) {
    NSString *subviewIdentifier = subview.identifier;
    if ([subviewIdentifier isEqualToString:@"moui_host_pixel_image_view"] ||
        [subviewIdentifier isEqualToString:@"moui_host_gpu_surface_view"]) {
      presenter = subview;
      break;
    }
  }
  if (presenter == nil) return;
  if (active) {
    [parent addSubview:presenter positioned:NSWindowAbove relativeTo:record->view];
    if (parent.window != nil) [parent.window makeFirstResponder:parent];
  } else {
    [parent addSubview:record->view positioned:NSWindowAbove relativeTo:presenter];
  }
}

double moui_macos_3d_surface_scale(uint64_t surface_handle) {
  CAMetalLayer *layer = (CAMetalLayer *)(uintptr_t)surface_handle;
  if (layer == nil || layer.contentsScale <= 0) return 1.0;
  return layer.contentsScale;
}

void moui_macos_3d_platform_views_end(uint64_t parent) {
  MOUIMetal3DRecord **cursor = &g_records;
  while (*cursor != NULL) {
    MOUIMetal3DRecord *record = *cursor;
    if (record->parent == parent && !record->seen) {
      moui_3d_sync_presenter_overlay(
          (NSView *)(uintptr_t)parent, NO, NSZeroRect);
      [record->view removeFromSuperview];
      *cursor = record->next;
      free(record->identifier);
      free(record);
    } else {
      cursor = &record->next;
    }
  }
}

void moui_macos_3d_platform_views_dispose(uint64_t parent) {
  MOUIMetal3DRecord **cursor = &g_records;
  while (*cursor != NULL) {
    MOUIMetal3DRecord *record = *cursor;
    if (record->parent == parent) {
      moui_3d_sync_presenter_overlay(
          (NSView *)(uintptr_t)parent, NO, NSZeroRect);
      [record->view removeFromSuperview];
      *cursor = record->next;
      free(record->identifier);
      free(record);
    } else {
      cursor = &record->next;
    }
  }
}
