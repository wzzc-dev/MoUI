#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef void (*moui_macos_webview_event_trampoline_t)(
    void *closure, uint64_t native_view, int32_t kind, moonbit_bytes_t id,
    moonbit_bytes_t url, moonbit_bytes_t detail, int32_t flag);

static moui_macos_webview_event_trampoline_t g_event_trampoline = NULL;
static void *g_event_closure = NULL;

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

@interface MOUIMacosWebViewRecord : NSObject <WKNavigationDelegate>
@property(nonatomic, assign) NSView *parent;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, retain) WKWebView *webView;
@property(nonatomic, copy) NSString *desiredURL;
@property(nonatomic, assign) int32_t navigationPolicy;
@property(nonatomic, assign) BOOL seen;
@property(nonatomic, assign) BOOL allowNextNavigation;
- (instancetype)initWithParent:(NSView *)parent identifier:(NSString *)identifier;
- (void)syncURL:(NSString *)url frame:(NSRect)frame policy:(int32_t)policy;
- (void)runCommand:(int32_t)command text:(NSString *)text detail:(NSString *)detail;
@end

static NSMutableArray<MOUIMacosWebViewRecord *> *g_records = nil;

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

@implementation MOUIMacosWebViewRecord
- (instancetype)initWithParent:(NSView *)parent identifier:(NSString *)identifier {
  self = [super init];
  if (self != nil) {
    _parent = parent;
    _identifier = [identifier copy];
    WKWebViewConfiguration *configuration = [[[WKWebViewConfiguration alloc] init] autorelease];
    _webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    _webView.navigationDelegate = self;
    _webView.autoresizingMask = NSViewNotSizable;
    [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    [_webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:NULL];
    [_webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:NULL];
    [parent addSubview:_webView positioned:NSWindowAbove relativeTo:nil];
  }
  return self;
}

- (void)dealloc {
  @try {
    [_webView removeObserver:self forKeyPath:@"title"];
    [_webView removeObserver:self forKeyPath:@"canGoBack"];
    [_webView removeObserver:self forKeyPath:@"canGoForward"];
  } @catch (__unused NSException *exception) {
  }
  [_webView removeFromSuperview];
  _webView.navigationDelegate = nil;
  [_webView release];
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
    self.allowNextNavigation = YES;
    self.desiredURL = url;
    [self.webView loadRequest:[NSURLRequest requestWithURL:nsURL]];
  }
}

- (void)syncURL:(NSString *)url frame:(NSRect)frame policy:(int32_t)policy {
  self.seen = YES;
  self.navigationPolicy = policy;
  self.webView.frame = frame;
  self.webView.hidden = frame.size.width <= 0 || frame.size.height <= 0;
  if (url.length > 0 && ![url isEqualToString:self.desiredURL]) {
    [self loadControlledURL:url];
  }
}

- (void)runCommand:(int32_t)command text:(NSString *)text detail:(NSString *)detail {
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
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 2, self.identifier,
                          webView.URL.absoluteString ?: @"", @"", 0);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  (void)navigation;
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 3, self.identifier,
                          webView.URL.absoluteString ?: @"", @"", 0);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)navigation;
  moui_macos_webview_emit((uint64_t)(uintptr_t)self.parent, 4, self.identifier,
                          webView.URL.absoluteString ?: @"",
                          error.localizedDescription ?: @"WKWebView navigation failed",
                          (int32_t)error.code);
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
                             int32_t policy, double x, double y, double width,
                             double height) {
  (void)title;
  NSView *parent = (__bridge NSView *)(void *)raw_content_view_handle;
  if (parent == nil) {
    return;
  }
  NSString *identifier = moui_macos_webview_string_from_bytes(id);
  MOUIMacosWebViewRecord *record = moui_macos_webview_find(parent, identifier);
  if (record == nil) {
    record = [[[MOUIMacosWebViewRecord alloc] initWithParent:parent
                                                  identifier:identifier] autorelease];
    [g_records addObject:record];
  }
  CGFloat flippedY = parent.bounds.size.height - y - height;
  [record syncURL:moui_macos_webview_string_from_bytes(url)
            frame:NSMakeRect(x, flippedY, width, height)
           policy:policy];
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
