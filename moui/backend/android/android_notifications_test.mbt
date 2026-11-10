// Contract tests for the notification/permission wrappers. Host native builds
// link the empty stubs from the window package's `native_android_host.c`, so
// these pin the offline behavior; the JNI path itself is exercised on
// matching-device evidence passes.

///|
test "android notification host stubs report unavailable" {
  inspect(
    @android.android_notification_send("id", "title", "body"),
    content="false",
  )
  inspect(@android.android_notification_cancel("id"), content="false")
  inspect(@android.android_permission_request("Notifications"), content="2")
}
