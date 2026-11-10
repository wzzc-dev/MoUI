///|
#borrow(identifier, title, body)
extern "C" fn macos_notification_send(
  identifier : Bytes,
  title : Bytes,
  body : Bytes,
) -> Int32 = "moui_macos_notification_send"

///|
#borrow(identifier)
extern "C" fn macos_notification_cancel(identifier : Bytes) -> Int32 = "moui_macos_notification_cancel"

///|
#borrow(kind)
extern "C" fn macos_permission_request(kind : Bytes) -> Int32 = "moui_macos_permission_request"

///|
/// macOS `PlatformChannel` dispatch for the platform services that have a
/// native implementation. Other operations stay explicitly unavailable.
pub fn dispatch_macos_platform_channel(
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
      if macos_notification_send(
          @utf8.encode(id[:], bom=false),
          @utf8.encode(title[:], bom=false),
          @utf8.encode(body[:], bom=false),
        ) !=
        0 {
        Ok("")
      } else {
        Error("macOS notification delivery failed")
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
      if macos_notification_cancel(@utf8.encode(id[:], bom=false)) != 0 {
        Ok("")
      } else {
        Error("macOS notification cancel failed")
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
      match macos_permission_request(@utf8.encode(kind[:], bom=false)) {
        1 => Ok("granted")
        2 => Ok("restricted")
        _ => Ok("denied")
      }
    }
    _ =>
      Unavailable(
        "macOS platform channel operation is not implemented: " +
        request.operation,
      )
  }
}
