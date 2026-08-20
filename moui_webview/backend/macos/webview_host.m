#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>
#include <moonbit.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef void (*moui_macos_webview_event_trampoline_t)(
    void *closure, uint64_t native_view, int32_t kind, moonbit_bytes_t id,
    moonbit_bytes_t url, moonbit_bytes_t detail, int32_t flag);

static moui_macos_webview_event_trampoline_t g_event_trampoline = NULL;
static void *g_event_closure = NULL;

static BOOL moui_macos_webview_debug_enabled(void) {
  static BOOL initialized = NO;
  static BOOL enabled = NO;
  if (!initialized) {
    const char *value = getenv("MOUI_WEBVIEW_DEBUG");
    enabled = value != NULL && value[0] != '\0' && strcmp(value, "0") != 0;
    initialized = YES;
  }
  return enabled;
}

static void moui_macos_webview_log(NSString *format, ...) {
  if (!moui_macos_webview_debug_enabled()) {
    return;
  }
  static NSTimeInterval epoch = 0.0;
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (epoch == 0.0) {
    epoch = now;
  }
  va_list arguments;
  va_start(arguments, format);
  NSString *message = [[[NSString alloc] initWithFormat:format
                                               arguments:arguments] autorelease];
  va_end(arguments);
  NSLog(@"[MoUI WebView +%.3fs] %@", now - epoch, message);
}

static moonbit_bytes_t moui_macos_webview_make_bytes(const char *text) {
  if (text == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(bytes, text, len);
  }
  return bytes;
}

static NSString *moui_macos_webview_string_from_bytes(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    return @"";
  }
  return [[[NSString alloc] initWithBytes:bytes
                                   length:(NSUInteger)len
                                 encoding:NSUTF8StringEncoding] autorelease] ?: @"";
}

static void moui_macos_webview_emit(uint64_t parent, int32_t kind,
                                    NSString *identifier, NSString *url,
                                    NSString *detail, int32_t flag) {
  if (g_event_trampoline == NULL || g_event_closure == NULL) {
    return;
  }
  g_event_trampoline(
      g_event_closure, parent, kind,
      moui_macos_webview_make_bytes(identifier.UTF8String),
      moui_macos_webview_make_bytes(url.UTF8String),
      moui_macos_webview_make_bytes(detail.UTF8String), flag);
}

static const CGFloat kMouiMacosWebViewDragHeight = 32.0;
static NSString *const kMouiHostPixelImageViewIdentifier =
    @"moui_host_pixel_image_view";
static NSString *const kMouiHostGpuSurfaceViewIdentifier =
    @"moui_host_gpu_surface_view";

@interface NSView (MOUIOverlayStateKey)
- (BOOL)mouiOverlayActive;
- (NSValue *)mouiOverlayRect;
@end

static BOOL moui_macos_webview_presenter_overlay_active(NSView *view) {
  NSNumber *active = objc_getAssociatedObject(view, @selector(mouiOverlayActive));
  return active.boolValue;
}

static void moui_macos_webview_set_presenter_overlay_active(NSView *view,
                                                             BOOL active) {
  objc_setAssociatedObject(view, @selector(mouiOverlayActive), @(active),
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void moui_macos_webview_set_presenter_overlay_rect(NSView *view,
                                                           BOOL has_bounds,
                                                           NSRect rect) {
  objc_setAssociatedObject(view, @selector(mouiOverlayRect),
                           has_bounds ? [NSValue valueWithRect:rect] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL moui_macos_webview_covers_parent(NSView *view, NSView *parent) {
  if (view == nil || parent == nil) {
    return NO;
  }
  NSRect frame = view.frame;
  NSRect bounds = parent.bounds;
  return NSMinX(frame) <= NSMinX(bounds) &&
         NSMinY(frame) <= NSMinY(bounds) &&
         NSMaxX(frame) >= NSMaxX(bounds) &&
         NSMaxY(frame) >= NSMaxY(bounds);
}

// Keep a deterministic fallback for hosts that do not provide a background
// color. DSH always supplies its resolved MoUI theme color through placement.
static NSColor *moui_macos_webview_default_background(void) {
  return [NSColor whiteColor];
}

static NSColor *moui_macos_webview_background_from_string(NSString *value) {
  if (value.length == 0) {
    return moui_macos_webview_default_background();
  }
  double red = 0.0;
  double green = 0.0;
  double blue = 0.0;
  double alpha = 1.0;
  if (sscanf(value.UTF8String, "%lf,%lf,%lf,%lf", &red, &green, &blue,
             &alpha) != 4) {
    return moui_macos_webview_default_background();
  }
  return [NSColor colorWithCalibratedRed:MAX(0.0, MIN(1.0, red))
                                   green:MAX(0.0, MIN(1.0, green))
                                    blue:MAX(0.0, MIN(1.0, blue))
                                   alpha:MAX(0.0, MIN(1.0, alpha))];
}

static NSString *moui_macos_webview_drag_regions_script(void) {
  return @"(function(){"
          "var selectors='a[href],button,input,textarea,select,summary,'"
          "+'[role=button],[role=link],[contenteditable=true],[data-moui-no-drag]';"
          "var scheduled=false;"
          "function collect(){"
          "scheduled=false;"
          "var rects=[];"
          "document.querySelectorAll(selectors).forEach(function(element){"
          "var rect=element.getBoundingClientRect();"
          "if(rect.width>0&&rect.height>0&&rect.bottom>0&&rect.top<32){"
          "rects.push([rect.left,rect.top,rect.right,rect.bottom]);"
          "}});"
          "if(window.webkit&&window.webkit.messageHandlers&&"
          "window.webkit.messageHandlers.mouiDragRegions){"
          "window.webkit.messageHandlers.mouiDragRegions.postMessage(JSON.stringify(rects));"
          "}}"
          "function schedule(){"
          "if(scheduled)return;"
          "scheduled=true;"
          "if(window.requestAnimationFrame){window.requestAnimationFrame(collect);}"
          "else{window.setTimeout(collect,0);}}"
          "collect();"
          "if(window.MutationObserver&&document.documentElement){"
          "new MutationObserver(schedule).observe(document.documentElement,"
          "{subtree:true,childList:true,attributes:true});}"
          "window.addEventListener('resize',schedule);"
          "})();";
}

static NSString *moui_macos_webview_startup_debug_script(void) {
  return @"(function(){"
          "if(window.__mouiWebViewReport)return;"
          "function report(phase){"
          "try{"
          "var handler=window.webkit&&window.webkit.messageHandlers&&"
          "window.webkit.messageHandlers.mouiStartup;"
          "if(handler){handler.postMessage(JSON.stringify({phase:phase,t:"
          "(window.performance?window.performance.now():0)}));}"
          "}catch(_){}}"
          "var shellReported=false;"
          "function reportShell(){"
          "if(shellReported)return;"
          "if(document.querySelector('.pI_x6G_frame')&&"
          "document.querySelector('.hHd-Xa_root')){"
          "shellReported=true;window.__mouiDshShellReported=true;"
          "report('dsh-shell-mounted');"
          "}}"
          "window.__mouiWebViewReport=report;"
          "report('document-start');"
          "document.addEventListener('DOMContentLoaded',function(){"
          "report('dom-content-loaded');reportShell();"
          "},{once:true});"
          "window.addEventListener('load',function(){report('window-load');"
          "reportShell();"
          "},{once:true});"
          "if(window.MutationObserver&&document.documentElement){"
          "new MutationObserver(reportShell).observe(document.documentElement,"
          "{subtree:true,childList:true,attributes:true});}"
          "reportShell();"
          "})();";
}

@class MOUIMacosWebViewRecord;

@interface MOUIMacosWebViewScriptBridge : NSObject <WKScriptMessageHandler>
@property(nonatomic, assign) MOUIMacosWebViewRecord *record;
@end

@interface MOUIMacosWebViewRecord : NSObject <WKNavigationDelegate>
@property(nonatomic, assign) NSView *parent;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, retain) WKWebView *webView;
@property(nonatomic, retain) WKUserContentController *contentController;
@property(nonatomic, assign) MOUIMacosWebViewScriptBridge *scriptBridge;
@property(nonatomic, copy) NSString *desiredURL;
@property(nonatomic, assign) int32_t navigationPolicy;
@property(nonatomic, assign) uint64_t hostPatchRevision;
@property(nonatomic, assign) BOOL seen;
@property(nonatomic, assign) BOOL allowNextNavigation;
@property(nonatomic, assign) BOOL overlayActive;
- (instancetype)initWithParent:(NSView *)parent
                     identifier:(NSString *)identifier
                     background:(NSString *)background;
- (void)syncURL:(NSString *)url
          frame:(NSRect)frame
         policy:(int32_t)policy
     background:(NSString *)background
        scheme:(NSString *)scheme;
- (void)syncOverlayMask:(BOOL)hasBounds rect:(NSRect)rect;
- (void)configureHostPatchRevision:(uint64_t)revision
                    allowedOrigins:(NSString *)allowedOrigins
                 documentStartScript:(NSString *)documentStartScript
                   documentEndScript:(NSString *)documentEndScript;
- (void)updateNoDragRegions:(id)body;
- (void)reportStartup:(id)body;
- (void)runCommand:(int32_t)command text:(NSString *)text detail:(NSString *)detail;
@end

// A full-surface WKWebView stays below the transparent presenter so modal
// transitions only change hit-test ownership. Partial WebViews retain the
// normal sibling ordering and move below the presenter only for an overlay.
@interface MOUIMaskedWebView : WKWebView
@property(nonatomic, assign) BOOL hasOverlayExclusion;
@property(nonatomic, assign) NSRect overlayExclusionRect;
@property(nonatomic, retain) NSArray<NSValue *> *noDragRects;
- (void)syncOverlayExclusion:(BOOL)hasBounds rect:(NSRect)rect;
@end

@implementation MOUIMaskedWebView
- (BOOL)isInNoDragRegion:(NSPoint)point {
  NSRect bounds = self.bounds;
  CGFloat x = point.x - NSMinX(bounds);
  CGFloat top = self.isFlipped ? point.y - NSMinY(bounds)
                               : NSMaxY(bounds) - point.y;
  for (NSValue *value in self.noDragRects) {
    NSRect rect = value.rectValue;
    if (NSPointInRect(NSMakePoint(x, top), rect)) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isInDragRegion:(NSPoint)point {
  NSRect bounds = self.bounds;
  CGFloat top = self.isFlipped ? point.y - NSMinY(bounds)
                               : NSMaxY(bounds) - point.y;
  return top >= 0.0 && top < kMouiMacosWebViewDragHeight &&
         ![self isInNoDragRegion:point];
}

- (NSView *)hitTest:(NSPoint)point {
  if (self.hasOverlayExclusion && NSPointInRect(point, self.overlayExclusionRect)) {
    return self.superview;
  }
  if ([self isInDragRegion:point]) {
    return self;
  }
  return [super hitTest:point];
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
  if ([self isInDragRegion:point] && self.window != nil) {
    [self.window performWindowDragWithEvent:event];
    return;
  }
  [super mouseDown:event];
}

- (void)syncOverlayExclusion:(BOOL)hasBounds rect:(NSRect)rect {
  self.hasOverlayExclusion = NO;
  self.overlayExclusionRect = NSZeroRect;
  if (!hasBounds) {
    return;
  }

  NSRect local = [self convertRect:rect fromView:self.superview];
  NSRect clipped = NSIntersectionRect(local, self.bounds);
  if (NSIsEmptyRect(clipped)) {
    return;
  }

  self.hasOverlayExclusion = YES;
  self.overlayExclusionRect = clipped;
}

- (void)dealloc {
  [_noDragRects release];
  [super dealloc];
}
@end

@implementation MOUIMacosWebViewScriptBridge
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  (void)userContentController;
  if ([message.name isEqualToString:@"mouiBridge"]) {
    NSString *wire = [message.body isKindOfClass:[NSString class]]
        ? (NSString *)message.body
        : @"";
    NSString *source = self.record.webView.URL.absoluteString ?: @"";
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.record.parent, 8,
                            self.record.identifier, source, wire, 0);
  } else if ([message.name isEqualToString:@"mouiStartup"]) {
    [self.record reportStartup:message.body];
  } else if ([message.name isEqualToString:@"mouiDragRegions"]) {
    [self.record updateNoDragRegions:message.body];
  }
}
@end

static NSMutableArray<MOUIMacosWebViewRecord *> *g_records = nil;
static WKWebView *g_moui_macos_webview_warmup = nil;

// Start WebKit's content process before the first platform-view sync. The
// real WebView is still created lazily when layout supplies its parent and
// frame, but macOS can reuse the warmed WebKit process automatically.
static void moui_macos_webview_start_prewarm(void) {
  if (g_moui_macos_webview_warmup != nil) {
    return;
  }
  moui_macos_webview_log(@"prewarm begin");
  WKWebViewConfiguration *configuration =
      [[[WKWebViewConfiguration alloc] init] autorelease];
  g_moui_macos_webview_warmup =
      [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
  g_moui_macos_webview_warmup.hidden = YES;
  [g_moui_macos_webview_warmup
      loadHTMLString:@"<!doctype html><meta charset='utf-8'><title>MoUI</title>"
            @"<body></body>"
      baseURL:nil];
  moui_macos_webview_log(@"prewarm loadHTMLString scheduled");
}

static MOUIMacosWebViewRecord *moui_macos_webview_find(NSView *parent,
                                                       NSString *identifier) {
  for (MOUIMacosWebViewRecord *record in g_records) {
    if (record.parent == parent && [record.identifier isEqualToString:identifier]) {
      return record;
    }
  }
  return nil;
}

static BOOL moui_macos_webview_policy_allows(int32_t policy, NSString *url) {
  if (policy == 2) {
    return YES;
  }
  NSString *scheme = [NSURL URLWithString:url].scheme.lowercaseString ?: @"";
  if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
    return YES;
  }
  return policy == 0 && [scheme isEqualToString:@"file"];
}

static NSString *moui_macos_webview_canonical_url(NSString *url) {
  NSURL *nsURL = [NSURL URLWithString:url];
  if (nsURL == nil) {
    return url;
  }
  NSString *scheme = nsURL.scheme.lowercaseString ?: @"";
  if (([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) &&
      nsURL.path.length == 0) {
    NSURLComponents *components =
        [NSURLComponents componentsWithURL:nsURL resolvingAgainstBaseURL:NO];
    components.path = @"/";
    return components.URL.absoluteString ?: nsURL.absoluteString;
  }
  return nsURL.absoluteString ?: url;
}

@implementation MOUIMacosWebViewRecord
- (instancetype)initWithParent:(NSView *)parent
                     identifier:(NSString *)identifier
                     background:(NSString *)background {
  self = [super init];
  if (self != nil) {
    _parent = parent;
    _identifier = [identifier copy];
    moui_macos_webview_log(@"record create id=%@", identifier);
    WKWebViewConfiguration *configuration = [[[WKWebViewConfiguration alloc] init] autorelease];
    WKUserContentController *controller = [[[WKUserContentController alloc] init] autorelease];
    self.contentController = controller;
    MOUIMacosWebViewScriptBridge *bridge = [[[MOUIMacosWebViewScriptBridge alloc] init] autorelease];
    bridge.record = self;
    _scriptBridge = bridge;
    [controller addScriptMessageHandler:bridge name:@"mouiDragRegions"];
    [controller addScriptMessageHandler:bridge name:@"mouiBridge"];
    if (moui_macos_webview_debug_enabled()) {
      [controller addScriptMessageHandler:bridge name:@"mouiStartup"];
      [controller addUserScript:[[[WKUserScript alloc]
          initWithSource:moui_macos_webview_startup_debug_script()
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
         forMainFrameOnly:YES] autorelease]];
    }
    [controller addUserScript:[[[WKUserScript alloc]
        initWithSource:moui_macos_webview_drag_regions_script()
          injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
       forMainFrameOnly:YES] autorelease]];
    configuration.userContentController = controller;
    _webView = [[MOUIMaskedWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    NSColor *startup_background =
        moui_macos_webview_background_from_string(background);
    // `underPageBackgroundColor` is the WKWebView surface shown before the
    // document has painted. Keep a layer fallback for older macOS versions
    // and for transparent document backgrounds.
    if (@available(macOS 12.0, *)) {
      _webView.underPageBackgroundColor = startup_background;
    }
    _webView.wantsLayer = YES;
    _webView.layer.backgroundColor = startup_background.CGColor;
    [(MOUIMaskedWebView *)_webView setNoDragRects:@[]];
    _webView.navigationDelegate = self;
    _webView.autoresizingMask = NSViewNotSizable;
    [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    [_webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:NULL];
    [_webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:NULL];
    [parent addSubview:_webView positioned:NSWindowAbove relativeTo:nil];
  }
  return self;
}

- (void)configureHostPatchRevision:(uint64_t)revision
                    allowedOrigins:(NSString *)allowedOrigins
                 documentStartScript:(NSString *)documentStartScript
                   documentEndScript:(NSString *)documentEndScript {
  (void)allowedOrigins;
  if (revision == 0 || revision == self.hostPatchRevision) {
    return;
  }
  // Rebuild the script list on every revision so a tightened policy cannot
  // leave the previous patch active on a later navigation.
  [self.contentController removeAllUserScripts];
  if (moui_macos_webview_debug_enabled()) {
    [self.contentController addUserScript:[[[WKUserScript alloc]
        initWithSource:moui_macos_webview_startup_debug_script()
          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
       forMainFrameOnly:YES] autorelease]];
  }
  [self.contentController addUserScript:[[[WKUserScript alloc]
      initWithSource:moui_macos_webview_drag_regions_script()
        injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
     forMainFrameOnly:YES] autorelease]];
  if (documentStartScript.length > 0) {
    [self.contentController addUserScript:[[[WKUserScript alloc]
        initWithSource:documentStartScript
          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
       forMainFrameOnly:YES] autorelease]];
  }
  if (documentEndScript.length > 0) {
    [self.contentController addUserScript:[[[WKUserScript alloc]
        initWithSource:documentEndScript
          injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
       forMainFrameOnly:YES] autorelease]];
  }
  self.hostPatchRevision = revision;
}

- (void)syncOverlayMask:(BOOL)hasBounds rect:(NSRect)rect {
  [(MOUIMaskedWebView *)self.webView syncOverlayExclusion:hasBounds rect:rect];
  BOOL overlayActive =
      [(MOUIMaskedWebView *)self.webView hasOverlayExclusion];
  moui_macos_webview_set_presenter_overlay_rect(
      self.parent, overlayActive, rect);
  if (overlayActive != self.overlayActive) {
    moui_macos_webview_log(@"overlay id=%@ active=%d rect=(%.0f,%.0f %.0fx%.0f)",
                           self.identifier, overlayActive ? 1 : 0,
                           rect.origin.x, rect.origin.y,
                           rect.size.width, rect.size.height);
  }
  NSView *presenter = nil;
  for (NSView *subview in self.parent.subviews) {
    if ([subview.identifier isEqualToString:kMouiHostPixelImageViewIdentifier]) {
      presenter = subview;
      break;
    }
  }
  if (presenter == nil) {
    for (NSView *subview in self.parent.subviews) {
      if ([subview.identifier isEqualToString:kMouiHostGpuSurfaceViewIdentifier]) {
        presenter = subview;
        break;
      }
    }
  }
  if (presenter != nil) {
    moui_macos_webview_set_presenter_overlay_active(presenter, overlayActive);
    BOOL presenterStaysAbove = overlayActive ||
        moui_macos_webview_covers_parent(self.webView, self.parent);
    NSUInteger webIndex =
        [self.parent.subviews indexOfObjectIdenticalTo:self.webView];
    NSUInteger presenterIndex =
        [self.parent.subviews indexOfObjectIdenticalTo:presenter];
    if (presenterStaysAbove && webIndex != NSNotFound &&
        presenterIndex != NSNotFound &&
        presenterIndex < webIndex) {
      [self.parent addSubview:presenter
                    positioned:NSWindowAbove
                    relativeTo:self.webView];
    } else if (!presenterStaysAbove && webIndex != NSNotFound &&
               presenterIndex != NSNotFound && webIndex < presenterIndex) {
      [self.parent addSubview:self.webView
                    positioned:NSWindowAbove
                    relativeTo:presenter];
    }
  }
  if (overlayActive && !self.overlayActive && self.parent.window != nil) {
    [self.parent.window makeFirstResponder:self.parent];
  }
  if (!overlayActive && self.overlayActive && self.parent.window != nil &&
      self.parent.window.firstResponder == self.parent) {
    [self.parent.window makeFirstResponder:self.webView];
  }
  self.overlayActive = overlayActive;
}

- (void)updateNoDragRegions:(id)body {
  if (![body isKindOfClass:[NSString class]]) {
    return;
  }
  NSData *data = [(NSString *)body dataUsingEncoding:NSUTF8StringEncoding];
  NSArray *rows = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
  if (![rows isKindOfClass:[NSArray class]]) {
    return;
  }
  NSMutableArray<NSValue *> *rects = [NSMutableArray array];
  for (id row in rows) {
    if (![row isKindOfClass:[NSArray class]] || [row count] != 4) {
      continue;
    }
    NSNumber *left = row[0];
    NSNumber *top = row[1];
    NSNumber *right = row[2];
    NSNumber *bottom = row[3];
    if (![left isKindOfClass:[NSNumber class]] ||
        ![top isKindOfClass:[NSNumber class]] ||
        ![right isKindOfClass:[NSNumber class]] ||
        ![bottom isKindOfClass:[NSNumber class]]) {
      continue;
    }
    CGFloat width = right.doubleValue - left.doubleValue;
    CGFloat height = bottom.doubleValue - top.doubleValue;
    if (width > 0.0 && height > 0.0) {
      [rects addObject:[NSValue valueWithRect:NSMakeRect(
          left.doubleValue, top.doubleValue, width, height)]];
    }
  }
  [(MOUIMaskedWebView *)self.webView setNoDragRects:rects];
}

- (void)dealloc {
  self.scriptBridge.record = nil;
  [_contentController
      removeScriptMessageHandlerForName:@"mouiDragRegions"];
  [_contentController
      removeScriptMessageHandlerForName:@"mouiStartup"];
  [_contentController removeScriptMessageHandlerForName:@"mouiBridge"];
  @try {
    [_webView removeObserver:self forKeyPath:@"title"];
    [_webView removeObserver:self forKeyPath:@"canGoBack"];
    [_webView removeObserver:self forKeyPath:@"canGoForward"];
  } @catch (__unused NSException *exception) {
  }
  [_webView removeFromSuperview];
  _webView.navigationDelegate = nil;
  [_webView release];
  [_contentController release];
  [_identifier release];
  [_desiredURL release];
  [super dealloc];
}

- (void)loadControlledURL:(NSString *)url {
  if (url.length == 0) {
    return;
  }
  if (!moui_macos_webview_policy_allows(self.navigationPolicy, url)) {
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 4,
                            self.identifier, url,
                            @"WebView navigation policy blocked URL", 0);
    return;
  }
  NSURL *nsURL = [NSURL URLWithString:url];
  if (nsURL != nil) {
    NSString *canonicalURL = moui_macos_webview_canonical_url(url);
    moui_macos_webview_log(@"loadRequest id=%@ url=%@ canonical=%@",
                           self.identifier, url, canonicalURL);
    self.allowNextNavigation = YES;
    self.desiredURL = canonicalURL;
    [self.webView loadRequest:[NSURLRequest requestWithURL:nsURL]];
  }
}

- (void)syncURL:(NSString *)url
          frame:(NSRect)frame
         policy:(int32_t)policy
     background:(NSString *)background
        scheme:(NSString *)scheme {
  self.seen = YES;
  self.navigationPolicy = policy;
  if ([scheme isEqualToString:@"dark"]) {
    self.webView.appearance =
        [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
  } else if ([scheme isEqualToString:@"light"]) {
    self.webView.appearance =
        [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  }
  NSColor *nativeBackground =
      moui_macos_webview_background_from_string(background);
  if (@available(macOS 12.0, *)) {
    self.webView.underPageBackgroundColor = nativeBackground;
  }
  self.webView.layer.backgroundColor = nativeBackground.CGColor;
  self.webView.frame = frame;
  self.webView.hidden = frame.size.width <= 0 || frame.size.height <= 0;
  if (url.length > 0 && self.desiredURL == nil) {
    moui_macos_webview_log(@"first sync id=%@ frame=(%.0f,%.0f %.0fx%.0f) url=%@",
                           self.identifier, frame.origin.x, frame.origin.y,
                           frame.size.width, frame.size.height, url);
  }
  NSString *canonicalURL = moui_macos_webview_canonical_url(url);
  if (url.length > 0 && ![canonicalURL isEqualToString:self.desiredURL]) {
    [self loadControlledURL:canonicalURL];
  }
}

- (void)runCommand:(int32_t)command text:(NSString *)text detail:(NSString *)detail {
  moui_macos_webview_log(@"command id=%@ kind=%d textLength=%lu detail=%@",
                         self.identifier, command, (unsigned long)text.length,
                         detail);
  switch (command) {
  case 0: {
    [self loadControlledURL:text];
    break;
  }
  case 1:
    [self.webView reload:nil];
    break;
  case 2:
    [self.webView stopLoading:nil];
    break;
  case 3:
    [self.webView goBack:nil];
    break;
  case 4:
    [self.webView goForward:nil];
    break;
  case 5:
    [self.webView evaluateJavaScript:text completionHandler:^(id result, NSError *error) {
      moui_macos_webview_log(@"evaluateJavaScript complete id=%@ error=%@",
                             self.identifier, error.localizedDescription ?: @"none");
      NSString *value = error != nil ? error.localizedDescription : [NSString stringWithFormat:@"%@", result ?: @""];
      moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 8,
                              self.identifier, detail ?: @"", value ?: @"",
                              error == nil ? 0 : (int32_t)error.code);
    }];
    break;
  default:
    break;
  }
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                     decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSString *url = navigationAction.request.URL.absoluteString ?: @"";
  moui_macos_webview_log(@"navigation policy id=%@ url=%@", self.identifier, url);
  if (!moui_macos_webview_policy_allows(self.navigationPolicy, url)) {
    self.allowNextNavigation = NO;
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 4, self.identifier,
                            url, @"WebView navigation policy blocked URL", 0);
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }
  if (self.allowNextNavigation) {
    self.allowNextNavigation = NO;
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 1, self.identifier,
                            url, @"", 0);
    decisionHandler(WKNavigationActionPolicyAllow);
  } else {
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 0, self.identifier,
                            url, @"", 0);
    decisionHandler(WKNavigationActionPolicyCancel);
  }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
  (void)navigation;
  moui_macos_webview_log(@"didCommitNavigation id=%@ url=%@", self.identifier,
                         webView.URL.absoluteString ?: @"");
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 2, self.identifier,
                          webView.URL.absoluteString ?: @"", @"", 0);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  (void)navigation;
  moui_macos_webview_log(@"didFinishNavigation id=%@ url=%@", self.identifier,
                         webView.URL.absoluteString ?: @"");
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 3, self.identifier,
                          webView.URL.absoluteString ?: @"", @"", 0);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)navigation;
  moui_macos_webview_log(@"navigation failed id=%@ code=%ld reason=%@",
                         self.identifier, (long)error.code,
                         error.localizedDescription ?: @"");
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 4, self.identifier,
                          webView.URL.absoluteString ?: @"",
                          error.localizedDescription ?: @"WKWebView navigation failed",
                          (int32_t)error.code);
}

- (void)reportStartup:(id)body {
  if (![body isKindOfClass:[NSString class]]) {
    return;
  }
  NSData *data = [(NSString *)body dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data
                                                              options:0
                                                                error:NULL];
  if (![payload isKindOfClass:[NSDictionary class]]) {
    return;
  }
  NSString *phase = payload[@"phase"];
  NSNumber *pageTime = payload[@"t"];
  moui_macos_webview_log(@"page phase=%@ pageTimeMs=%.1f id=%@ url=%@",
                         [phase isKindOfClass:[NSString class]] ? phase : @"unknown",
                         [pageTime isKindOfClass:[NSNumber class]] ? pageTime.doubleValue : 0.0,
                         self.identifier, self.webView.URL.absoluteString ?: @"");
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  [self webView:webView didFailNavigation:navigation withError:error];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  (void)object;
  (void)change;
  (void)context;
  if ([keyPath isEqualToString:@"title"]) {
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 5,
                            self.identifier, @"", self.webView.title ?: @"", 0);
  } else if ([keyPath isEqualToString:@"canGoBack"]) {
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 6,
                            self.identifier, @"", @"",
                            self.webView.canGoBack ? 1 : 0);
  } else if ([keyPath isEqualToString:@"canGoForward"]) {
    moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 7,
                            self.identifier, @"", @"",
                            self.webView.canGoForward ? 1 : 0);
  }
}
@end

@interface MOUITestFirstResponderView : NSView
@end

@implementation MOUITestFirstResponderView
- (BOOL)acceptsFirstResponder {
  return YES;
}
@end

@interface MOUITestTransparentPresenterView : NSView
@end

@implementation MOUITestTransparentPresenterView
- (NSView *)hitTest:(NSPoint)point {
  (void)point;
  return moui_macos_webview_presenter_overlay_active(self) ? self.superview
                                                            : nil;
}
@end

MOONBIT_FFI_EXPORT
int32_t moui_macos_webview_overlay_composition_test(void) {
  @autoreleasepool {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, 320.0, 200.0)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    MOUITestFirstResponderView *parent = [[MOUITestFirstResponderView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 320.0, 200.0)];
    window.contentView = parent;
    [parent release];

    MOUIMacosWebViewRecord *record = [[MOUIMacosWebViewRecord alloc]
        initWithParent:parent
            identifier:@"test-webview"
            background:@""];
    record.webView.frame = parent.bounds;

    NSView *presenter =
        [[MOUITestTransparentPresenterView alloc] initWithFrame:parent.bounds];
    presenter.identifier = kMouiHostGpuSurfaceViewIdentifier;
    [parent addSubview:presenter
              positioned:NSWindowBelow
              relativeTo:record.webView];
    [presenter release];

    MOUITestFirstResponderView *previousResponder =
        [[MOUITestFirstResponderView alloc] initWithFrame:NSZeroRect];
    [parent addSubview:previousResponder];
    [window makeFirstResponder:previousResponder];
    [previousResponder release];

    [record syncOverlayMask:YES rect:parent.bounds];
    NSUInteger webIndex = [parent.subviews indexOfObjectIdenticalTo:record.webView];
    NSUInteger presenterIndex = [parent.subviews indexOfObjectIdenticalTo:presenter];
    BOOL opened = record.overlayActive &&
                  record.webView.layer.mask == nil &&
                  [record.webView hitTest:NSMakePoint(1.0, 1.0)] == parent &&
                  [presenter hitTest:NSMakePoint(1.0, 1.0)] == parent &&
                  [parent hitTest:NSMakePoint(1.0, 1.0)] == parent &&
                  presenterIndex > webIndex &&
                  window.firstResponder == parent;

    [record syncOverlayMask:NO rect:NSZeroRect];
    webIndex = [parent.subviews indexOfObjectIdenticalTo:record.webView];
    presenterIndex = [parent.subviews indexOfObjectIdenticalTo:presenter];
    BOOL closed = !record.overlayActive && presenterIndex > webIndex &&
                  [presenter hitTest:NSMakePoint(1.0, 1.0)] == nil &&
                  [parent hitTest:NSMakePoint(1.0, 1.0)] == record.webView &&
                  window.firstResponder == record.webView;

    [record release];

    record = [[MOUIMacosWebViewRecord alloc]
        initWithParent:parent
            identifier:@"test-partial-webview"
            background:@""];
    record.webView.frame = NSMakeRect(20.0, 20.0, 160.0, 100.0);
    [parent addSubview:presenter
              positioned:NSWindowBelow
              relativeTo:record.webView];
    [record syncOverlayMask:NO rect:NSZeroRect];
    webIndex = [parent.subviews indexOfObjectIdenticalTo:record.webView];
    presenterIndex = [parent.subviews indexOfObjectIdenticalTo:presenter];
    BOOL partialIdle = webIndex > presenterIndex;
    [record syncOverlayMask:YES rect:record.webView.frame];
    webIndex = [parent.subviews indexOfObjectIdenticalTo:record.webView];
    presenterIndex = [parent.subviews indexOfObjectIdenticalTo:presenter];
    BOOL partialOpened = presenterIndex > webIndex;
    [record syncOverlayMask:NO rect:NSZeroRect];
    webIndex = [parent.subviews indexOfObjectIdenticalTo:record.webView];
    presenterIndex = [parent.subviews indexOfObjectIdenticalTo:presenter];
    BOOL partialClosed = webIndex > presenterIndex;

    [record release];
    window.contentView = nil;
    [window release];
    return opened && closed && partialIdle && partialOpened && partialClosed
               ? 1
               : 0;
  }
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_install_event_callback(
    moui_macos_webview_event_trampoline_t trampoline, void *closure) {
  if (g_event_closure != NULL) {
    moonbit_decref(g_event_closure);
  }
  g_event_trampoline = trampoline;
  g_event_closure = closure;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_webview_available(void) { return 1; }

MOONBIT_FFI_EXPORT
void moui_macos_webview_prewarm(void) {
  moui_macos_webview_start_prewarm();
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_platform_views_begin(uint64_t raw_content_view_handle) {
  if (g_records == nil) {
    g_records = [[NSMutableArray alloc] init];
  }
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  for (MOUIMacosWebViewRecord *record in g_records) {
    if (record.parent == parent) {
      record.seen = NO;
    }
  }
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_sync(uint64_t raw_content_view_handle, moonbit_bytes_t id,
                             moonbit_bytes_t url, moonbit_bytes_t title,
                             moonbit_bytes_t background, moonbit_bytes_t scheme,
                             int32_t policy,
                             double x, double y, double width, double height) {
  (void)title;
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  if (parent == nil) {
    return;
  }
  NSString *identifier = moui_macos_webview_string_from_bytes(id);
  MOUIMacosWebViewRecord *record = moui_macos_webview_find(parent, identifier);
  if (record == nil) {
    record = [[[MOUIMacosWebViewRecord alloc]
        initWithParent:parent
             identifier:identifier
             background:moui_macos_webview_string_from_bytes(background)] autorelease];
    [g_records addObject:record];
  }
  // The window content view (MBWContentView) overrides `isFlipped` to return
  // YES, so it already uses a top-left origin matching the MoonBit layout
  // frame (origin.y grows downward). Do NOT flip the Y axis here; doing so
  // anchors the webview to the bottom of the window and keeps its distance
  // to the bottom edge fixed across vertical resizes.
  [record syncURL:moui_macos_webview_string_from_bytes(url)
            frame:NSMakeRect(x, y, width, height)
           policy:policy
       background:moui_macos_webview_string_from_bytes(background)
            scheme:moui_macos_webview_string_from_bytes(scheme)];
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_configure(uint64_t raw_content_view_handle,
                                   moonbit_bytes_t id, uint64_t revision,
                                   moonbit_bytes_t allowed_origins,
                                   moonbit_bytes_t document_start,
                                   moonbit_bytes_t document_end) {
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  if (parent == nil) {
    return;
  }
  MOUIMacosWebViewRecord *record =
      moui_macos_webview_find(parent, moui_macos_webview_string_from_bytes(id));
  if (record == nil) {
    return;
  }
  [record configureHostPatchRevision:revision
                      allowedOrigins:moui_macos_webview_string_from_bytes(allowed_origins)
                   documentStartScript:moui_macos_webview_string_from_bytes(document_start)
                     documentEndScript:moui_macos_webview_string_from_bytes(document_end)];
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_sync_overlay_mask(uint64_t raw_content_view_handle,
                                           moonbit_bytes_t id,
                                           int32_t has_bounds,
                                           double x,
                                           double y,
                                           double width,
                                           double height) {
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  MOUIMacosWebViewRecord *record =
      moui_macos_webview_find(parent, moui_macos_webview_string_from_bytes(id));
  if (record == nil) {
    return;
  }
  [record syncOverlayMask:has_bounds != 0
                      rect:NSMakeRect(x, y, width, height)];
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_platform_views_end(uint64_t raw_content_view_handle) {
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  for (MOUIMacosWebViewRecord *record in g_records) {
    if (record.parent == parent && !record.seen) {
      record.webView.hidden = YES;
    }
  }
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_platform_views_dispose(uint64_t raw_content_view_handle) {
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  NSIndexSet *remove = [g_records indexesOfObjectsPassingTest:^BOOL(MOUIMacosWebViewRecord *record, NSUInteger idx, BOOL *stop) {
    (void)idx;
    (void)stop;
    return record.parent == parent;
  }];
  [g_records removeObjectsAtIndexes:remove];
}

MOONBIT_FFI_EXPORT
void moui_macos_webview_command(uint64_t raw_content_view_handle, moonbit_bytes_t id,
                                int32_t command, moonbit_bytes_t text,
                                moonbit_bytes_t detail) {
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  MOUIMacosWebViewRecord *record =
      moui_macos_webview_find(parent, moui_macos_webview_string_from_bytes(id));
  if (record == nil) {
    return;
  }
  [record runCommand:command
                text:moui_macos_webview_string_from_bytes(text)
              detail:moui_macos_webview_string_from_bytes(detail)];
}
