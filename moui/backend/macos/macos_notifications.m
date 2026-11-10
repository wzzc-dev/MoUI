#import <AppKit/AppKit.h>
#import <UserNotifications/UserNotifications.h>
#import <moonbit.h>
#import <stdint.h>

// Native result codes shared with `dispatch_macos_platform_channel`.
enum {
  MOUI_MACOS_NOTIFICATION_OK = 1,
  MOUI_MACOS_NOTIFICATION_FAILED = 0,
  MOUI_MACOS_NOTIFICATION_UNAVAILABLE = -1,
  MOUI_MACOS_NOTIFICATION_DENIED = -2,
  MOUI_MACOS_NOTIFICATION_PENDING = 2,
};

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

@interface MouiNotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation MouiNotificationDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions))completionHandler {
  (void)center;
  (void)notification;
  // Foreground apps otherwise suppress banners; the platform service should
  // behave like the notification center while the app is active.
  completionHandler(UNNotificationPresentationOptionBanner |
                    UNNotificationPresentationOptionList |
                    UNNotificationPresentationOptionSound);
}
@end

static MouiNotificationDelegate *moui_notification_delegate = nil;

// `UNUserNotificationCenter` raises for processes without a bundle proxy, so
// raw `moon run` binaries must get an explicit unavailable result instead of
// crashing. `moui run` and `moui package` launch from an app bundle.
static UNUserNotificationCenter *moui_notification_center(void) {
  if ([NSBundle mainBundle].bundleIdentifier.length == 0) {
    return nil;
  }
  @try {
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
    if (center == nil) {
      return nil;
    }
    if (moui_notification_delegate == nil) {
      moui_notification_delegate = [[MouiNotificationDelegate alloc] init];
    }
    center.delegate = moui_notification_delegate;
    return center;
  } @catch (__unused NSException *exception) {
    return nil;
  }
}

static BOOL moui_notification_authorization_status(
    UNUserNotificationCenter *center,
    UNAuthorizationStatus *result) {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block UNAuthorizationStatus status = UNAuthorizationStatusNotDetermined;
  [center getNotificationSettingsWithCompletionHandler:^(
              UNNotificationSettings *settings) {
    status = settings.authorizationStatus;
    dispatch_semaphore_signal(semaphore);
  }];
  if (dispatch_semaphore_wait(
          semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) != 0) {
    return NO;
  }
  *result = status;
  return YES;
}

static BOOL moui_notification_is_authorized(UNAuthorizationStatus status) {
  switch (status) {
  case UNAuthorizationStatusAuthorized:
  case UNAuthorizationStatusProvisional:
    return YES;
  default:
    return NO;
  }
}

static void moui_notification_request_authorization(
    UNUserNotificationCenter *center) {
  [center
      requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                      UNAuthorizationOptionSound |
                                      UNAuthorizationOptionBadge)
                    completionHandler:^(__unused BOOL granted,
                                        __unused NSError *error) {
                      // The next permission query or notification send reads
                      // the settled status; no callback bridge is needed.
                    }];
}

int32_t moui_macos_notification_send(moonbit_bytes_t identifier,
                                     moonbit_bytes_t title,
                                     moonbit_bytes_t body) {
  @autoreleasepool {
    UNUserNotificationCenter *center = moui_notification_center();
    if (center == nil) {
      return MOUI_MACOS_NOTIFICATION_UNAVAILABLE;
    }
    NSString *notification_id = moui_notification_string(identifier);
    if (notification_id.length == 0) {
      return MOUI_MACOS_NOTIFICATION_FAILED;
    }
    UNAuthorizationStatus status;
    if (!moui_notification_authorization_status(center, &status)) {
      return MOUI_MACOS_NOTIFICATION_FAILED;
    }
    if (status == UNAuthorizationStatusNotDetermined) {
      moui_notification_request_authorization(center);
      return MOUI_MACOS_NOTIFICATION_PENDING;
    }
    if (!moui_notification_is_authorized(status)) {
      return MOUI_MACOS_NOTIFICATION_DENIED;
    }
    UNMutableNotificationContent *content =
        [[UNMutableNotificationContent alloc] init];
    content.title = moui_notification_string(title);
    content.body = moui_notification_string(body);
    content.sound = [UNNotificationSound defaultSound];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:notification_id
                                             content:content
                                             trigger:nil];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSError *add_error = nil;
    [center addNotificationRequest:request
             withCompletionHandler:^(NSError *error) {
               add_error = error;
               dispatch_semaphore_signal(semaphore);
             }];
    if (dispatch_semaphore_wait(
            semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) !=
        0) {
      return MOUI_MACOS_NOTIFICATION_FAILED;
    }
    return add_error == nil ? MOUI_MACOS_NOTIFICATION_OK
                            : MOUI_MACOS_NOTIFICATION_FAILED;
  }
}

int32_t moui_macos_notification_cancel(moonbit_bytes_t identifier) {
  @autoreleasepool {
    UNUserNotificationCenter *center = moui_notification_center();
    if (center == nil) {
      return MOUI_MACOS_NOTIFICATION_UNAVAILABLE;
    }
    NSString *notification_id = moui_notification_string(identifier);
    if (notification_id.length == 0) {
      return MOUI_MACOS_NOTIFICATION_FAILED;
    }
    NSArray<NSString *> *identifiers = @[ notification_id ];
    [center removeDeliveredNotificationsWithIdentifiers:identifiers];
    [center removePendingNotificationRequestsWithIdentifiers:identifiers];
    return MOUI_MACOS_NOTIFICATION_OK;
  }
}

int32_t moui_macos_permission_request(moonbit_bytes_t kind) {
  @autoreleasepool {
    NSString *value = moui_notification_string(kind);
    // Notification authorization is the only macOS permission implemented in
    // v1. Camera, microphone, location, photos, and files stay restricted.
    if ([value caseInsensitiveCompare:@"notifications"] != NSOrderedSame &&
        [value caseInsensitiveCompare:@"notification"] != NSOrderedSame) {
      return MOUI_MACOS_NOTIFICATION_PENDING;
    }
    UNUserNotificationCenter *center = moui_notification_center();
    if (center == nil) {
      return MOUI_MACOS_NOTIFICATION_UNAVAILABLE;
    }
    UNAuthorizationStatus status;
    if (!moui_notification_authorization_status(center, &status)) {
      return MOUI_MACOS_NOTIFICATION_PENDING;
    }
    if (status == UNAuthorizationStatusNotDetermined) {
      moui_notification_request_authorization(center);
      return MOUI_MACOS_NOTIFICATION_PENDING;
    }
    return moui_notification_is_authorized(status)
               ? MOUI_MACOS_NOTIFICATION_OK
               : MOUI_MACOS_NOTIFICATION_FAILED;
  }
}
