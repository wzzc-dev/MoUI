#import <AppKit/AppKit.h>
#import <stdint.h>

// DEV bundles created by `moui run macos` carry no icon catalog entry. Report
// that state so the backend can apply the embedded Moonbud icon instead of
// leaving a generic Dock tile.
int32_t moui_macos_application_bundle_has_icon(void) {
  @autoreleasepool {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *icon = [bundle objectForInfoDictionaryKey:@"CFBundleIconFile"];
    if (icon.length == 0) {
      icon = [bundle objectForInfoDictionaryKey:@"CFBundleIconName"];
    }
    return icon.length > 0 ? 1 : 0;
  }
}
