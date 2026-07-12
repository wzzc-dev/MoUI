#import <UIKit/UIKit.h>
#include <moonbit.h>

#include <math.h>
#include <stdint.h>
#include <cstring>
#include <mutex>

#ifndef MOUI_MOBILE_APP_ARG
#define MOUI_MOBILE_APP_ARG "moui-mobile-ios"
#endif

#ifndef MOUI_MOBILE_APP_ID
#define MOUI_MOBILE_APP_ID "unknown"
#endif

#ifndef MOUI_MOBILE_RENDERER_REQUESTED
#define MOUI_MOBILE_RENDERER_REQUESTED "auto"
#endif

#ifndef MOUI_MOBILE_RENDERER_SELECTED
#define MOUI_MOBILE_RENDERER_SELECTED "skia-raster"
#endif

namespace {

std::once_flag g_moonbit_init_once;

extern "C" void moonbit_runtime_init(int argc, char **argv);
extern "C" void moonbit_init(void);

extern "C" int32_t MOUI_MOBILE_ATTACH_VIEW(uint64_t view_handle,
                                            int32_t width,
                                            int32_t height,
                                            double scale_factor);
extern "C" int32_t MOUI_MOBILE_RESIZE(int32_t width,
                                       int32_t height,
                                       double scale_factor);
extern "C" int32_t MOUI_MOBILE_DISPATCH_POINTER(int32_t phase,
                                                 double x,
                                                 double y,
                                                 double time_ms);
#if MOUI_MOBILE_ENABLE_SCROLL
extern "C" int32_t MOUI_MOBILE_DISPATCH_SCROLL(double x,
                                                double y,
                                                double delta_x,
                                                double delta_y,
                                                int32_t phase);
#endif
extern "C" int32_t MOUI_MOBILE_FRAME_TICK(double time_ms);
extern "C" int32_t MOUI_MOBILE_RENDER_FRAME(void);
extern "C" void MOUI_MOBILE_DETACH_VIEW(void);
extern "C" moonbit_string_t moui_mobile_take_host_updates_json(void);
extern "C" int32_t moui_mobile_dispatch_text_input(
    int32_t kind,
    moonbit_string_t text,
    int32_t start,
    int32_t end);
extern "C" int32_t moui_mobile_dispatch_command(int32_t kind);
extern "C" int32_t moui_mobile_dispatch_accessibility(
    int32_t element_id,
    int32_t action,
    moonbit_string_t value);
extern "C" int32_t moui_mobile_complete_clipboard(
    int32_t id,
    int32_t kind,
    moonbit_string_t text,
    moonbit_bytes_t bytes);

moonbit_string_t moonbit_string_from_nsstring(NSString *value) {
  NSUInteger length = value != nil ? value.length : 0;
  moonbit_string_t result = moonbit_make_string_raw((int32_t)length);
  if (length > 0) {
    [value getCharacters:reinterpret_cast<unichar *>(result)
                  range:NSMakeRange(0, length)];
  }
  return result;
}

NSString *nsstring_from_moonbit(moonbit_string_t value) {
  if (value == nullptr) {
    return @"";
  }
  int32_t length = Moonbit_array_length(value);
  NSString *result = [[NSString alloc]
      initWithCharacters:reinterpret_cast<const unichar *>(value)
                  length:(NSUInteger)length];
  moonbit_decref(value);
  return result;
}

BOOL dispatch_mobile_text(int32_t kind, NSString *text, NSInteger start, NSInteger end) {
  moonbit_string_t native = moonbit_string_from_nsstring(text ?: @"");
  int32_t result = moui_mobile_dispatch_text_input(
      kind, native, (int32_t)start, (int32_t)end);
  moonbit_decref(native);
  NSLog(@"moui-mobile service ime edit kind=%d result=%d", kind, result);
  return result != 0;
}

BOOL dispatch_mobile_accessibility(int32_t elementId, int32_t action, NSString *value) {
  moonbit_string_t native = moonbit_string_from_nsstring(value ?: @"");
  int32_t result = moui_mobile_dispatch_accessibility(elementId, action, native);
  moonbit_decref(native);
  NSLog(@"moui-mobile service accessibility %@ id=%d action=%d result=%d",
        action == 1 ? @"focus" : @"action", elementId, action, result);
  return result != 0;
}

BOOL complete_mobile_clipboard(int32_t requestId, int32_t kind, NSString *text, NSData *data) {
  moonbit_string_t nativeText = moonbit_string_from_nsstring(text ?: @"");
  moonbit_bytes_t nativeBytes = moonbit_make_bytes_raw((int32_t)data.length);
  if (data.length > 0) {
    memcpy(nativeBytes, data.bytes, data.length);
  }
  int32_t result = moui_mobile_complete_clipboard(
      requestId, kind, nativeText, nativeBytes);
  moonbit_decref(nativeText);
  moonbit_decref(nativeBytes);
  return result != 0;
}

void ensure_moonbit_runtime() {
  std::call_once(g_moonbit_init_once, [] {
    static char app_name[] = MOUI_MOBILE_APP_ARG;
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
    NSLog(@"moui-mobile runtime initialized app=%s renderer-requested=%s renderer-selected=%s",
          MOUI_MOBILE_APP_ID,
          MOUI_MOBILE_RENDERER_REQUESTED,
          MOUI_MOBILE_RENDERER_SELECTED);
  });
}

}  // namespace

@class MOUIMobileViewController;

@interface MOUIMobileAccessibilityElement : UIAccessibilityElement
@property(nonatomic, assign) int32_t elementId;
@property(nonatomic, assign) BOOL supportsScroll;
@end

@interface MOUIMobileRootView : UIView
@property(nonatomic, weak) MOUIMobileViewController *mobileController;
@end

@interface MOUIMobileViewController : UIViewController <UITextViewDelegate>
- (void)attachOrResizeIfNeeded;
- (void)handleTouches:(NSSet<UITouch *> *)touches
                phase:(int32_t)phase
                event:(UIEvent *)event;
- (void)detachMobileRuntime;
- (void)handleDisplayLink:(CADisplayLink *)displayLink;
- (void)processHostUpdates;
- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
@end

@interface MOUIMobileImeProxyView : UITextView
@property(nonatomic, weak) MOUIMobileViewController *mobileController;
@property(nonatomic, assign) CGRect candidateRectInRoot;
@end

@implementation MOUIMobileAccessibilityElement

- (void)accessibilityElementDidBecomeFocused {
  dispatch_mobile_accessibility(self.elementId, 1, @"");
}

- (BOOL)accessibilityActivate {
  return dispatch_mobile_accessibility(self.elementId, 0, @"");
}

- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction {
  if (!self.supportsScroll) {
    return NO;
  }
  NSString *value = @"forward";
  if (direction == UIAccessibilityScrollDirectionUp) value = @"up";
  else if (direction == UIAccessibilityScrollDirectionDown) value = @"down";
  else if (direction == UIAccessibilityScrollDirectionLeft) value = @"left";
  else if (direction == UIAccessibilityScrollDirectionRight) value = @"right";
  return dispatch_mobile_accessibility(self.elementId, 4, value);
}

@end

@implementation MOUIMobileRootView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self != nil) {
    self.multipleTouchEnabled = YES;
    self.backgroundColor = UIColor.whiteColor;
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.mobileController handleTouches:touches phase:0 event:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.mobileController handleTouches:touches phase:1 event:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.mobileController handleTouches:touches phase:2 event:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.mobileController handleTouches:touches phase:3 event:event];
}

@end

@implementation MOUIMobileImeProxyView

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (action == @selector(copy:) || action == @selector(cut:) ||
      action == @selector(paste:)) {
    return YES;
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)copy:(id)sender {
  [self.mobileController copy:sender];
}

- (void)cut:(id)sender {
  [self.mobileController cut:sender];
}

- (void)paste:(id)sender {
  [self.mobileController paste:sender];
}

- (CGRect)firstRectForRange:(UITextRange *)range {
  (void)range;
  if (!CGRectIsEmpty(self.candidateRectInRoot) && self.superview != nil) {
    return [self convertRect:self.candidateRectInRoot fromView:self.superview];
  }
  return [super firstRectForRange:range];
}

@end

@interface MOUIMobileViewController ()
@property(nonatomic, assign) BOOL attached;
@property(nonatomic, assign) CGSize lastPixelSize;
@property(nonatomic, assign) CGFloat lastScale;
@property(nonatomic, assign) BOOL hasLastTouchPoint;
@property(nonatomic, assign) CGPoint lastTouchPoint;
@property(nonatomic, strong) CADisplayLink *displayLink;
@property(nonatomic, strong) MOUIMobileImeProxyView *imeProxy;
@property(nonatomic, assign) BOOL applyingHostUpdate;
@property(nonatomic, assign) BOOL imeCompositionActive;
@property(nonatomic, copy) NSString *committedText;
@end

@implementation MOUIMobileViewController

- (void)loadView {
  MOUIMobileRootView *rootView =
      [[MOUIMobileRootView alloc] initWithFrame:UIScreen.mainScreen.bounds];
  rootView.mobileController = self;
  self.view = rootView;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  ensure_moonbit_runtime();
  self.committedText = @"";
  self.imeProxy =
      [[MOUIMobileImeProxyView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
  self.imeProxy.mobileController = self;
  self.imeProxy.delegate = self;
  self.imeProxy.backgroundColor = UIColor.clearColor;
  self.imeProxy.textColor = UIColor.clearColor;
  self.imeProxy.tintColor = UIColor.clearColor;
  self.imeProxy.alpha = 0.02;
  self.imeProxy.autocorrectionType = UITextAutocorrectionTypeDefault;
  self.imeProxy.spellCheckingType = UITextSpellCheckingTypeDefault;
  self.imeProxy.accessibilityElementsHidden = YES;
  [self.view addSubview:self.imeProxy];
  [NSNotificationCenter.defaultCenter
      addObserver:self
         selector:@selector(handleDidEnterBackgroundNotification:)
             name:UISceneDidEnterBackgroundNotification
           object:nil];
  [NSNotificationCenter.defaultCenter
      addObserver:self
         selector:@selector(handleWillEnterForegroundNotification:)
             name:UISceneWillEnterForegroundNotification
           object:nil];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self attachOrResizeIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self attachOrResizeIfNeeded];
}

- (BOOL)prefersStatusBarHidden {
#if MOUI_MOBILE_FULLSCREEN
  return YES;
#else
  return NO;
#endif
}

- (BOOL)prefersHomeIndicatorAutoHidden {
#if MOUI_MOBILE_FULLSCREEN
  return YES;
#else
  return NO;
#endif
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
#if MOUI_MOBILE_FULLSCREEN
  return UIRectEdgeAll;
#else
  return UIRectEdgeNone;
#endif
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [self detachMobileRuntime];
}

- (void)handleDidEnterBackgroundNotification:(NSNotification *)notification {
  (void)notification;
  [self detachMobileRuntime];
}

- (void)handleWillEnterForegroundNotification:(NSNotification *)notification {
  (void)notification;
  [self attachOrResizeIfNeeded];
}

- (CGFloat)currentScale {
  CGFloat scale = self.view.window.screen.scale;
  if (scale <= 0.0) {
    scale = UIScreen.mainScreen.scale;
  }
  return scale > 0.0 ? scale : 1.0;
}

- (CGSize)currentPixelSizeWithScale:(CGFloat)scale {
  CGSize boundsSize = self.view.bounds.size;
  int32_t width = (int32_t)llround(MAX(1.0, boundsSize.width * scale));
  int32_t height = (int32_t)llround(MAX(1.0, boundsSize.height * scale));
  return CGSizeMake((CGFloat)width, (CGFloat)height);
}

- (void)attachOrResizeIfNeeded {
  ensure_moonbit_runtime();
  CGFloat scale = [self currentScale];
  CGSize pixelSize = [self currentPixelSizeWithScale:scale];
  int32_t width = (int32_t)pixelSize.width;
  int32_t height = (int32_t)pixelSize.height;
  if (width <= 0 || height <= 0) {
    return;
  }

  if (!self.attached) {
    uint64_t handle = (uint64_t)(__bridge void *)self.view;
    self.attached = MOUI_MOBILE_ATTACH_VIEW(handle, width, height, scale) != 0;
    self.lastPixelSize = pixelSize;
    self.lastScale = scale;
    NSLog(@"moui-mobile lifecycle attach app=%s width=%d height=%d attached=%d", MOUI_MOBILE_APP_ID, width, height, self.attached);
  } else if (!CGSizeEqualToSize(pixelSize, self.lastPixelSize) ||
             fabs(self.lastScale - scale) > 0.0001) {
    MOUI_MOBILE_RESIZE(width, height, scale);
    self.lastPixelSize = pixelSize;
    self.lastScale = scale;
    NSLog(@"moui-mobile resize app=%s width=%d height=%d", MOUI_MOBILE_APP_ID, width, height);
  }

  if (self.attached) {
    if (self.displayLink == nil) {
      self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                    selector:@selector(handleDisplayLink:)];
      [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop
                              forMode:NSRunLoopCommonModes];
    }
  }
}

- (void)handleDisplayLink:(CADisplayLink *)displayLink {
  if (self.attached) {
    MOUI_MOBILE_FRAME_TICK(displayLink.timestamp * 1000.0);
    [self processHostUpdates];
  }
}

- (void)processHostUpdates {
  NSString *encoded = nsstring_from_moonbit(moui_mobile_take_host_updates_json());
  if (encoded.length == 0 || [encoded isEqualToString:@"[]"]) {
    return;
  }
  NSData *data = [encoded dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSArray *updates = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (![updates isKindOfClass:NSArray.class]) {
    NSLog(@"moui-mobile invalid host update: %@", error);
    return;
  }
  for (NSDictionary *update in updates) {
    NSString *kind = update[@"kind"];
    if ([kind isEqualToString:@"ime"]) {
      [self applyImePayload:update[@"payload"]];
    } else if ([kind isEqualToString:@"clipboard"]) {
      [self applyClipboardUpdate:update];
    } else if ([kind isEqualToString:@"semantics"]) {
      [self applySemanticsPayload:update[@"payload"]];
    } else if ([kind isEqualToString:@"diagnostic"]) {
      NSLog(@"%@", update[@"payload"] ?: @"moui-mobile diagnostic");
    }
  }
}

- (void)applyImePayload:(NSDictionary *)payload {
  if (![payload isKindOfClass:NSDictionary.class]) return;
  NSLog(@"moui-mobile service ime state enabled=%d", [payload[@"enabled"] boolValue]);
  BOOL enabled = [payload[@"enabled"] boolValue];
  NSString *text = [payload[@"text"] isKindOfClass:NSString.class]
      ? payload[@"text"] : @"";
  NSInteger caret = [payload[@"caret"] integerValue];
  NSInteger start = caret;
  NSInteger end = caret;
  NSDictionary *selection = [payload[@"selection"] isKindOfClass:NSDictionary.class]
      ? payload[@"selection"] : nil;
  if (selection != nil) {
    start = [selection[@"start"] integerValue];
    end = [selection[@"end"] integerValue];
  }
  start = MAX(0, MIN((NSInteger)text.length, start));
  end = MAX(0, MIN((NSInteger)text.length, end));
  self.applyingHostUpdate = YES;
  self.committedText = text;
  self.imeProxy.text = text;
  self.imeProxy.selectedRange = NSMakeRange(MIN(start, end), labs(end - start));
  NSDictionary *anchor = [payload[@"candidate_anchor"] isKindOfClass:NSDictionary.class]
      ? payload[@"candidate_anchor"] : nil;
  NSDictionary *origin = [anchor[@"origin"] isKindOfClass:NSDictionary.class]
      ? anchor[@"origin"] : nil;
  NSDictionary *size = [anchor[@"size"] isKindOfClass:NSDictionary.class]
      ? anchor[@"size"] : nil;
  if (origin != nil && size != nil) {
    self.imeProxy.candidateRectInRoot = CGRectMake(
        [origin[@"x"] doubleValue],
        [origin[@"y"] doubleValue],
        MAX(1.0, [size[@"width"] doubleValue]),
        MAX(1.0, [size[@"height"] doubleValue]));
  }
  NSDictionary *field = [payload[@"frame"] isKindOfClass:NSDictionary.class]
      ? payload[@"frame"] : nil;
  NSDictionary *fieldOrigin = [field[@"origin"] isKindOfClass:NSDictionary.class]
      ? field[@"origin"] : nil;
  NSDictionary *fieldSize = [field[@"size"] isKindOfClass:NSDictionary.class]
      ? field[@"size"] : nil;
  if (fieldOrigin != nil && fieldSize != nil) {
    self.imeProxy.frame = CGRectMake(
        [fieldOrigin[@"x"] doubleValue],
        [fieldOrigin[@"y"] doubleValue],
        MAX(1.0, [fieldSize[@"width"] doubleValue]),
        MAX(1.0, [fieldSize[@"height"] doubleValue]));
  }
  self.imeProxy.userInteractionEnabled = enabled;
  self.applyingHostUpdate = NO;
  if (enabled) {
    [self.imeProxy becomeFirstResponder];
  } else {
    self.imeCompositionActive = NO;
    [self.imeProxy resignFirstResponder];
  }
}

- (void)applyClipboardUpdate:(NSDictionary *)update {
  int32_t requestId = [update[@"id"] intValue];
  NSDictionary *payload = [update[@"payload"] isKindOfClass:NSDictionary.class]
      ? update[@"payload"] : nil;
  NSString *operation = payload[@"operation"];
  UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
  if ([operation isEqualToString:@"read-text"]) {
    complete_mobile_clipboard(requestId, 1, pasteboard.string ?: @"", nil);
  } else if ([operation isEqualToString:@"write-text"]) {
    pasteboard.string = payload[@"text"] ?: @"";
    complete_mobile_clipboard(requestId, 3, @"", nil);
  } else if ([operation isEqualToString:@"read-image"]) {
    NSData *image = [pasteboard dataForPasteboardType:@"public.png"];
    if (image == nil) image = [pasteboard dataForPasteboardType:@"public.jpeg"];
    complete_mobile_clipboard(
        requestId,
        image != nil ? 2 : 0,
        image != nil ? @"" : @"clipboard image is unavailable",
        image);
  } else if ([operation isEqualToString:@"write-image"]) {
    NSArray *values = [payload[@"bytes"] isKindOfClass:NSArray.class]
        ? payload[@"bytes"] : @[];
    NSMutableData *image = [NSMutableData dataWithLength:values.count];
    uint8_t *bytes = reinterpret_cast<uint8_t *>(image.mutableBytes);
    for (NSUInteger index = 0; index < values.count; index++) {
      bytes[index] = (uint8_t)[values[index] unsignedIntValue];
    }
    NSString *mime = payload[@"mime"] ?: @"image/png";
    NSString *type = [mime containsString:@"jpeg"] ? @"public.jpeg" : @"public.png";
    [pasteboard setData:image forPasteboardType:type];
    complete_mobile_clipboard(requestId, 3, @"", nil);
  }
  NSLog(@"moui-mobile service clipboard complete operation=%@", operation ?: @"unknown");
}

- (void)applySemanticsPayload:(NSDictionary *)payload {
  NSArray *nodes = [payload[@"nodes"] isKindOfClass:NSArray.class]
      ? payload[@"nodes"] : @[];
  NSMutableArray *elements = [NSMutableArray arrayWithCapacity:nodes.count];
  for (NSDictionary *node in nodes) {
    MOUIMobileAccessibilityElement *element =
        [[MOUIMobileAccessibilityElement alloc] initWithAccessibilityContainer:self.view];
    element.elementId = [node[@"element_id"] intValue];
    element.accessibilityLabel = node[@"label"] ?: @"";
    element.accessibilityValue = node[@"value"] ?: @"";
    element.accessibilityHint = node[@"description"] ?: @"";
    NSString *role = node[@"role"] ?: @"None";
    UIAccessibilityTraits traits = UIAccessibilityTraitNone;
    if ([role isEqualToString:@"Button"]) traits |= UIAccessibilityTraitButton;
    if ([role isEqualToString:@"TextField"]) traits |= UIAccessibilityTraitUpdatesFrequently;
    if ([role isEqualToString:@"Text"]) traits |= UIAccessibilityTraitStaticText;
    NSDictionary *state = [node[@"state"] isKindOfClass:NSDictionary.class]
        ? node[@"state"] : @{};
    if ([state[@"disabled"] boolValue]) traits |= UIAccessibilityTraitNotEnabled;
    if ([state[@"selected"] boolValue]) traits |= UIAccessibilityTraitSelected;
    element.accessibilityTraits = traits;
    NSArray *actions = [node[@"actions"] isKindOfClass:NSArray.class]
        ? node[@"actions"] : @[];
    element.supportsScroll = [actions containsObject:@"Scroll"];
    NSDictionary *frame = node[@"frame"];
    NSDictionary *origin = frame[@"origin"];
    NSDictionary *size = frame[@"size"];
    element.accessibilityFrameInContainerSpace = CGRectMake(
        [origin[@"x"] doubleValue],
        [origin[@"y"] doubleValue],
        [size[@"width"] doubleValue],
        [size[@"height"] doubleValue]);
    [elements addObject:element];
  }
  self.view.accessibilityElements = elements;
  UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
  NSLog(@"moui-mobile service accessibility tree nodes=%lu", (unsigned long)elements.count);
}

- (void)textViewDidChange:(UITextView *)textView {
  if (self.applyingHostUpdate) return;
  UITextRange *marked = textView.markedTextRange;
  if (marked != nil) {
    if (!self.imeCompositionActive) {
      dispatch_mobile_text(3, @"", 0, 0);
      self.imeCompositionActive = YES;
    }
    NSString *composition = [textView textInRange:marked] ?: @"";
    dispatch_mobile_text(4, composition, composition.length, composition.length);
  } else {
    dispatch_mobile_text(1, textView.text ?: @"", 0, self.committedText.length);
    self.committedText = textView.text ?: @"";
    if (self.imeCompositionActive) {
      dispatch_mobile_text(5, @"", 0, 0);
      self.imeCompositionActive = NO;
    }
  }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  if (self.applyingHostUpdate || textView.markedTextRange != nil) return;
  dispatch_mobile_text(
      2,
      @"",
      textView.selectedRange.location,
      NSMaxRange(textView.selectedRange));
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (action == @selector(copy:) || action == @selector(cut:) ||
      action == @selector(paste:)) {
    return YES;
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)copy:(id)sender {
  (void)sender;
  moui_mobile_dispatch_command(0);
}

- (void)cut:(id)sender {
  (void)sender;
  moui_mobile_dispatch_command(1);
}

- (void)paste:(id)sender {
  (void)sender;
  moui_mobile_dispatch_command(2);
}

- (void)detachMobileRuntime {
  [self.displayLink invalidate];
  self.displayLink = nil;
  if (self.attached) {
    MOUI_MOBILE_DETACH_VIEW();
    self.attached = NO;
    NSLog(@"moui-mobile lifecycle detach app=%s", MOUI_MOBILE_APP_ID);
  }
}

- (void)handleTouches:(NSSet<UITouch *> *)touches
                phase:(int32_t)phase
                event:(UIEvent *)event {
  (void)event;
  if (!self.attached) {
    return;
  }
  UITouch *touch = touches.anyObject;
  if (touch == nil) {
    return;
  }
  CGFloat scale = [self currentScale];
  CGPoint point = [touch locationInView:self.view];
#if MOUI_MOBILE_ENABLE_SCROLL
  if (phase == 0) {
    self.hasLastTouchPoint = YES;
    self.lastTouchPoint = point;
    MOUI_MOBILE_DISPATCH_SCROLL(point.x * scale, point.y * scale, 0.0, 0.0, 0);
  } else if (phase == 1 && self.hasLastTouchPoint) {
    CGFloat deltaX = point.x - self.lastTouchPoint.x;
    CGFloat deltaY = point.y - self.lastTouchPoint.y;
    self.lastTouchPoint = point;
    MOUI_MOBILE_DISPATCH_SCROLL(
        point.x * scale,
        point.y * scale,
        deltaX * scale,
        deltaY * scale,
        1);
    NSLog(@"moui-mobile input scroll app=%s dx=%f dy=%f", MOUI_MOBILE_APP_ID, deltaX * scale, deltaY * scale);
  } else if (phase == 2 || phase == 3) {
    MOUI_MOBILE_DISPATCH_SCROLL(
        point.x * scale,
        point.y * scale,
        0.0,
        0.0,
        phase == 2 ? 2 : 3);
    self.hasLastTouchPoint = NO;
  }
#endif
  MOUI_MOBILE_DISPATCH_POINTER(
      phase,
      point.x * scale,
      point.y * scale,
      touch.timestamp * 1000.0);
  NSLog(@"moui-mobile input pointer app=%s phase=%d x=%f y=%f", MOUI_MOBILE_APP_ID, phase, point.x * scale, point.y * scale);
}

@end

@interface MOUIMobileAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation MOUIMobileAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
  (void)application;
  (void)launchOptions;
  ensure_moonbit_runtime();
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = [[MOUIMobileViewController alloc] init];
  [self.window makeKeyAndVisible];
  return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
  (void)application;
  MOUIMobileViewController *controller =
      (MOUIMobileViewController *)self.window.rootViewController;
  [controller detachMobileRuntime];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  (void)application;
  MOUIMobileViewController *controller =
      (MOUIMobileViewController *)self.window.rootViewController;
  [controller detachMobileRuntime];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  (void)application;
  MOUIMobileViewController *controller =
      (MOUIMobileViewController *)self.window.rootViewController;
  [controller attachOrResizeIfNeeded];
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(
        argc,
        argv,
        nil,
        NSStringFromClass([MOUIMobileAppDelegate class]));
  }
}
