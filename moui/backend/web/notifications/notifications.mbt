///|
/// Browser `PlatformChannel` dispatch for the operations the Web host owns.
/// Permission is reported as granted/denied/restricted from the current
/// `Notification.permission`; a pending prompt stays restricted until the app
/// retries after the user responds.
///
/// This package is imported by Web composition roots, not by the neutral
/// `moui/backend/web` host package, so package tests do not link the
/// `window_web` host imports.
pub fn platform_channel(
  request : @host.PlatformChannelRequest,
) -> @host.PlatformChannelResponse {
  if request.channel != "moui.platform" {
    return Unavailable("platform channel is unavailable: " + request.channel)
  }
  match request.operation {
    "notification.send" => {
      let parsed = @json.parse(request.payload) catch {
        _ => return Error("notification.send payload is not valid JSON")
      }
      let fields = match parsed {
        Object(fields) => fields
        _ => return Error("notification.send payload must be an object")
      }
      let id = match fields.get("id") {
        Some(String(value)) => value
        _ => return Error("notification.send payload is missing id")
      }
      let title = match fields.get("title") {
        Some(String(value)) => value
        _ => return Error("notification.send payload is missing title")
      }
      let body = match fields.get("body") {
        Some(String(value)) => value
        _ => ""
      }
      if @window_web.web_notification_send(id, title, body) {
        Ok("")
      } else {
        Error(
          "browser notification was not shown; permission may be pending or denied",
        )
      }
    }
    "notification.cancel" => {
      let parsed = @json.parse(request.payload) catch {
        _ => return Error("notification.cancel payload is not valid JSON")
      }
      let id = match parsed {
        String(value) => value
        _ => return Error("notification.cancel payload must be a string")
      }
      if @window_web.web_notification_cancel(id) {
        Ok("")
      } else {
        Error("browser notification was not found")
      }
    }
    "permission.request" => {
      let parsed = @json.parse(request.payload) catch {
        _ => return Error("permission.request payload is not valid JSON")
      }
      let kind = match parsed {
        String(value) => value
        _ => return Error("permission.request payload must be a string")
      }
      let notification_kind = kind.to_lower() == "notifications" ||
        kind.to_lower() == "notification"
      if notification_kind {
        match @window_web.web_notification_permission() {
          1 => Ok("granted")
          0 => Ok("denied")
          _ => Ok("restricted")
        }
      } else {
        Ok("restricted")
      }
    }
    _ =>
      Unavailable(
        "Web platform channel operation is not implemented: " +
        request.operation,
      )
  }
}
