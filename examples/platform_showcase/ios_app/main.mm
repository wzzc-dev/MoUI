#import <UIKit/UIKit.h>

#include <math.h>
#include <stdint.h>
#include <mutex>

namespace {

std::once_flag g_moonbit_init_once;

extern "C" void moonbit_runtime_init(int argc, char **argv);
extern "C" void moonbit_init(void);

extern "C" int32_t platform_showcase_ios_attach_view(uint64_t view_handle,
                                                     int32_t width,
                                                     int32_t height,
                                                     double scale_factor);
extern "C" int32_t platform_showcase_ios_resize(int32_t width,
                                                int32_t height,
                                                double scale_factor);
extern "C" int32_t platform_showcase_ios_dispatch_pointer(int32_t phase,
                                                          double x,
                                                          double y,
                                                          double time_ms);
extern "C" int32_t platform_showcase_ios_dispatch_scroll(double x,
                                                         double y,
                                                         double delta_x,
                                                         double delta_y,
                                                         int32_t phase);
extern "C" int32_t platform_showcase_ios_render_frame(void);
extern "C" void platform_showcase_ios_detach_view(void);

void ensure_moonbit_runtime() {
  std::call_once(g_moonbit_init_once, [] {
    static char app_name[] = "moui-platform-showcase-ios";
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
  });
}

}  // namespace

@class MOUIPlatformShowcaseViewController;

@interface MOUIPlatformShowcaseRootView : UIView
@property(nonatomic, weak) MOUIPlatformShowcaseViewController *showcaseController;
@end

@interface MOUIPlatformShowcaseViewController : UIViewController
- (void)handleTouches:(NSSet<UITouch *> *)touches
                phase:(int32_t)phase
                event:(UIEvent *)event;
- (void)detachGallery;
@end

@implementation MOUIPlatformShowcaseRootView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self != nil) {
    self.multipleTouchEnabled = YES;
    self.backgroundColor = UIColor.whiteColor;
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.showcaseController handleTouches:touches phase:0 event:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.showcaseController handleTouches:touches phase:1 event:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.showcaseController handleTouches:touches phase:2 event:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.showcaseController handleTouches:touches phase:3 event:event];
}

@end

@interface MOUIPlatformShowcaseViewController ()
@property(nonatomic, assign) BOOL attached;
@property(nonatomic, assign) CGSize lastPixelSize;
@property(nonatomic, assign) CGFloat lastScale;
@property(nonatomic, assign) BOOL hasLastTouchPoint;
@property(nonatomic, assign) CGPoint lastTouchPoint;
@end

@implementation MOUIPlatformShowcaseViewController

- (void)loadView {
  MOUIPlatformShowcaseRootView *rootView =
      [[MOUIPlatformShowcaseRootView alloc] initWithFrame:UIScreen.mainScreen.bounds];
  rootView.showcaseController = self;
  self.view = rootView;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  ensure_moonbit_runtime();
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self attachOrResizeIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self attachOrResizeIfNeeded];
  platform_showcase_ios_render_frame();
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
  return YES;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
  return UIRectEdgeAll;
}

- (void)dealloc {
  [self detachGallery];
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
    self.attached = platform_showcase_ios_attach_view(handle, width, height, scale) != 0;
    self.lastPixelSize = pixelSize;
    self.lastScale = scale;
  } else if (!CGSizeEqualToSize(pixelSize, self.lastPixelSize) ||
             fabs(self.lastScale - scale) > 0.0001) {
    platform_showcase_ios_resize(width, height, scale);
    self.lastPixelSize = pixelSize;
    self.lastScale = scale;
  }

  if (self.attached) {
    platform_showcase_ios_render_frame();
  }
}

- (void)detachGallery {
  if (self.attached) {
    platform_showcase_ios_detach_view();
    self.attached = NO;
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
  if (phase == 0) {
    self.hasLastTouchPoint = YES;
    self.lastTouchPoint = point;
    platform_showcase_ios_dispatch_scroll(
        point.x * scale,
        point.y * scale,
        0.0,
        0.0,
        0);
  } else if (phase == 1 && self.hasLastTouchPoint) {
    CGFloat deltaX = point.x - self.lastTouchPoint.x;
    CGFloat deltaY = point.y - self.lastTouchPoint.y;
    self.lastTouchPoint = point;
    platform_showcase_ios_dispatch_scroll(
        point.x * scale,
        point.y * scale,
        deltaX * scale,
        deltaY * scale,
        1);
  } else if (phase == 2 || phase == 3) {
    platform_showcase_ios_dispatch_scroll(
        point.x * scale,
        point.y * scale,
        0.0,
        0.0,
        phase == 2 ? 2 : 3);
    self.hasLastTouchPoint = NO;
  }
  platform_showcase_ios_dispatch_pointer(
      phase,
      point.x * scale,
      point.y * scale,
      touch.timestamp * 1000.0);
  platform_showcase_ios_render_frame();
}

@end

@interface MOUIPlatformShowcaseAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation MOUIPlatformShowcaseAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
  (void)application;
  (void)launchOptions;
  ensure_moonbit_runtime();
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = [[MOUIPlatformShowcaseViewController alloc] init];
  [self.window makeKeyAndVisible];
  return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
  (void)application;
  MOUIPlatformShowcaseViewController *controller =
      (MOUIPlatformShowcaseViewController *)self.window.rootViewController;
  [controller detachGallery];
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(
        argc,
        argv,
        nil,
        NSStringFromClass([MOUIPlatformShowcaseAppDelegate class]));
  }
}
