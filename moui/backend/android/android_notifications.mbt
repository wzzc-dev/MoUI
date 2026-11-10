// Android notification/permission host service bindings.
//
// The native side lives in the window embedder
// (`window/modules/window/android/native_android_host.c`) and talks to the
// HostedActivity NotificationManager / requestPermissions helpers through JNI.
// Permission prompts are asynchronous, so a pending POST_NOTIFICATIONS request
// reports Restricted and the app retries after the user responds.

///|
#borrow(id, title, body)
extern "C" fn android_notification_send_bytes(
  id : Bytes,
  title : Bytes,
  body : Bytes,
) -> Int32 = "mbw_android_notification_send"

///|
#borrow(id)
extern "C" fn android_notification_cancel_bytes(id : Bytes) -> Int32 = "mbw_android_notification_cancel"

///|
#borrow(kind)
extern "C" fn android_permission_request_bytes(kind : Bytes) -> Int32 = "mbw_android_permission_request"

///|
pub fn android_notification_send(
  id : String,
  title : String,
  body : String,
) -> Bool {
  android_notification_send_bytes(
    @utf8.encode(id, bom=false),
    @utf8.encode(title, bom=false),
    @utf8.encode(body, bom=false),
  ) !=
  0
}

///|
pub fn android_notification_cancel(id : String) -> Bool {
  android_notification_cancel_bytes(@utf8.encode(id, bom=false)) != 0
}

///|
/// 1 = granted, 0 = denied, 2 = restricted/pending.
pub fn android_permission_request(kind : String) -> Int32 {
  android_permission_request_bytes(@utf8.encode(kind, bom=false))
}
