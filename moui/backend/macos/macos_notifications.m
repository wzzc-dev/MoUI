#import <AppKit/AppKit.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

static NSString *moui_notification_string(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    return @"";
  }
  NSString *string = [[NSString alloc] initWithBytes:(const void *)bytes
                                               length:(NSUInteger)len
                                             encoding:NSUTF8StringEncoding];
  return string != nil ? string : @"";
}

@interface MouiNotificationDelegate : NSObject <NSUserNotificationCenterDelegate>
@end

@implementation MouiNotificationDelegate
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
  (void)center;
  (void)notification;
  // Develop-time apps are usually foreground; the old API otherwise suppresses
  // banners while the app is active.
  return YES;
}
@end

static MouiNotificationDelegate *moui_notification_delegate = nil;

static void moui_ensure_notification_delegate(void) {
  if (moui_notification_delegate == nil) {
    moui_notification_delegate = [[MouiNotificationDelegate alloc] init];
  }
  [NSUserNotificationCenter defaultUserNotificationCenter].delegate =
      moui_notification_delegate;
}

int32_t moui_macos_notification_send(
    moonbit_bytes_t identifier,
    moonbit_bytes_t title,
    moonbit_bytes_t body) {
  @autoreleasepool {
    moui_ensure_notification_delegate();
    NSString *notification_id = moui_notification_string(identifier);
    if (notification_id.length == 0) {
      return 0;
    }
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.identifier = notification_id;
    notification.title = moui_notification_string(title);
    notification.informativeText = moui_notification_string(body);
    [[NSUserNotificationCenter defaultUserNotificationCenter]
        deliverNotification:notification];
  }
  return 1;
}

int32_t moui_macos_notification_cancel(moonbit_bytes_t identifier) {
  @autoreleasepool {
    NSString *notification_id = moui_notification_string(identifier);
    if (notification_id.length == 0) {
      return 0;
    }
    NSUserNotificationCenter *center =
        [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *notification in center.deliveredNotifications) {
      if ([notification.identifier isEqualToString:notification_id]) {
        [center removeDeliveredNotification:notification];
      }
    }
  }
  return 1;
}

int32_t moui_macos_permission_request(moonbit_bytes_t kind) {
  @autoreleasepool {
    NSString *value = moui_notification_string(kind);
    // macOS owns notification authorization; the deprecated
    // NSUserNotificationCenter API has no synchronous status query. Camera,
    // microphone, location, photos, and files are not implemented in v1.
    if ([value caseInsensitiveCompare:@"notifications"] == NSOrderedSame ||
        [value caseInsensitiveCompare:@"notification"] == NSOrderedSame) {
      return 1; // granted (best-effort; the system may still suppress)
    }
  }
  return 2; // restricted
}
