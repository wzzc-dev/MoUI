///|
/// Permission categories are intentionally platform-neutral. A host may map
/// them to native prompts, browser permissions, or an unavailable result.
pub(all) enum PermissionKind {
  Notifications
  Camera
  Microphone
  Location
  Photos
  Files
} derive(Eq, Hash, Debug, ToJson)

///|
pub(all) enum PermissionStatus {
  Granted
  Denied
  Restricted
} derive(Eq, Debug, ToJson)

///|
/// Host lifecycle events describe whether the application is visible to the
/// user. Window focus remains a window/input concern and is not represented
/// here.
pub(all) enum AppLifecycleEvent {
  Foreground
  Background
} derive(Eq, Debug, ToJson)

///|
priv struct AppLifecycleHandler {
  token : Int
  handle : (AppLifecycleEvent) -> Unit
}

///|
/// Push source populated by a platform composition root. An absent source on
/// `PlatformServices` means the host does not expose app lifecycle events.
pub struct AppLifecycleSource {
  priv mut next_token : Int
  priv mut handlers : Array[AppLifecycleHandler]
}

///|
pub fn AppLifecycleSource::new() -> AppLifecycleSource {
  { next_token: 1, handlers: [] }
}

///|
pub fn AppLifecycleSource::publish(
  self : AppLifecycleSource,
  event : AppLifecycleEvent,
) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
  }
  handlers.length()
}

///|
pub fn AppLifecycleSource::active_handler_count(
  self : AppLifecycleSource,
) -> Int {
  self.handlers.length()
}

///|
pub fn[Msg] AppLifecycleSource::subscription(
  self : AppLifecycleSource,
  map~ : (AppLifecycleEvent) -> Msg,
  key? : String = "app:lifecycle",
  label? : String = "App lifecycle",
) -> @core.Subscription[Msg] {
  @core.Subscription::listen(key~, label~, kind="app-lifecycle", start=dispatch => {
    let token = self.next_token
    self.next_token = self.next_token + 1
    self.handlers.push({ token, handle: event => dispatch(map(event)) })
    Some(() => {
      self.handlers = self.handlers.filter(handler => handler.token != token)
    })
  })
}

///|
pub fn NotificationRequest::new(
  id~ : String,
  title~ : String,
  body~ : String,
) -> NotificationRequest {
  { id, title, body }
}

///|
pub fn TrayItem::new(
  id~ : String,
  label~ : String,
  tooltip? : String = "",
) -> TrayItem {
  { id, label, tooltip }
}

///|
pub fn ShareRequest::new(
  title~ : String,
  text~ : String,
  url? : String? = None,
) -> ShareRequest {
  { title, text, url }
}

///|
pub fn PrintRequest::new(
  title~ : String,
  text~ : String,
  mime_type? : String = "text/plain",
) -> PrintRequest {
  { title, text, mime_type }
}

///|
pub fn ProtocolRegistration::new(
  scheme~ : String,
  handler~ : String,
) -> ProtocolRegistration {
  { scheme, handler }
}

///|
pub fn FileAssociation::new(
  extension~ : String,
  mime_type~ : String,
  handler~ : String,
) -> FileAssociation {
  { extension, mime_type, handler }
}

///|
pub(all) struct NotificationRequest {
  id : String
  title : String
  body : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TrayItem {
  id : String
  label : String
  tooltip : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShareRequest {
  title : String
  text : String
  url : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PrintRequest {
  title : String
  text : String
  mime_type : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProtocolRegistration {
  scheme : String
  handler : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FileAssociation {
  extension : String
  mime_type : String
  handler : String
} derive(Eq, Debug, ToJson)

///|
pub struct NotificationServices {
  notify_fn : (NotificationRequest) -> ServiceTask[Unit]
  cancel_fn : (String) -> ServiceTask[Unit]
}

///|
pub fn NotificationServices::new(
  notify? : (NotificationRequest) -> ServiceTask[Unit] = _request => {
    unavailable_task("notification:send", "notifications")
  },
  cancel? : (String) -> ServiceTask[Unit] = _id => {
    unavailable_task("notification:cancel", "notifications")
  },
) -> NotificationServices {
  { notify_fn: notify, cancel_fn: cancel }
}

///|
pub fn NotificationServices::notify(
  self : NotificationServices,
  request : NotificationRequest,
) -> ServiceTask[Unit] {
  (self.notify_fn)(request)
}

///|
pub fn NotificationServices::cancel(
  self : NotificationServices,
  id : String,
) -> ServiceTask[Unit] {
  (self.cancel_fn)(id)
}

///|
pub struct TrayServices {
  set_fn : (TrayItem) -> ServiceTask[Unit]
  remove_fn : (String) -> ServiceTask[Unit]
}

///|
pub fn TrayServices::new(
  set? : (TrayItem) -> ServiceTask[Unit] = _item => {
    unavailable_task("tray:set", "system tray")
  },
  remove? : (String) -> ServiceTask[Unit] = _id => {
    unavailable_task("tray:remove", "system tray")
  },
) -> TrayServices {
  { set_fn: set, remove_fn: remove }
}

///|
pub fn TrayServices::set(
  self : TrayServices,
  item : TrayItem,
) -> ServiceTask[Unit] {
  (self.set_fn)(item)
}

///|
pub fn TrayServices::remove(
  self : TrayServices,
  id : String,
) -> ServiceTask[Unit] {
  (self.remove_fn)(id)
}

///|
pub struct PermissionServices {
  request_fn : (PermissionKind) -> ServiceTask[PermissionStatus]
}

///|
pub fn PermissionServices::new(
  request? : (PermissionKind) -> ServiceTask[PermissionStatus] = _kind => {
    unavailable_task("permission:request", "permission prompts")
  },
) -> PermissionServices {
  { request_fn: request }
}

///|
pub fn PermissionServices::request(
  self : PermissionServices,
  kind : PermissionKind,
) -> ServiceTask[PermissionStatus] {
  (self.request_fn)(kind)
}

///|
pub struct ShareServices {
  share_fn : (ShareRequest) -> ServiceTask[Unit]
}

///|
pub fn ShareServices::new(
  share? : (ShareRequest) -> ServiceTask[Unit] = _request => {
    unavailable_task("share:open", "share sheet")
  },
) -> ShareServices {
  { share_fn: share }
}

///|
pub fn ShareServices::share(
  self : ShareServices,
  request : ShareRequest,
) -> ServiceTask[Unit] {
  (self.share_fn)(request)
}

///|
pub struct PrintServices {
  print_fn : (PrintRequest) -> ServiceTask[Unit]
}

///|
pub fn PrintServices::new(
  print? : (PrintRequest) -> ServiceTask[Unit] = _request => {
    unavailable_task("print:document", "printing")
  },
) -> PrintServices {
  { print_fn: print }
}

///|
pub fn PrintServices::print(
  self : PrintServices,
  request : PrintRequest,
) -> ServiceTask[Unit] {
  (self.print_fn)(request)
}

///|
pub struct AssociationServices {
  register_protocol_fn : (ProtocolRegistration) -> ServiceTask[Unit]
  register_file_fn : (FileAssociation) -> ServiceTask[Unit]
  unregister_fn : (String) -> ServiceTask[Unit]
}

///|
pub fn AssociationServices::new(
  register_protocol? : (ProtocolRegistration) -> ServiceTask[Unit] = _registration => {
    unavailable_task("association:protocol", "protocol associations")
  },
  register_file? : (FileAssociation) -> ServiceTask[Unit] = _association => {
    unavailable_task("association:file", "file associations")
  },
  unregister? : (String) -> ServiceTask[Unit] = _value => {
    unavailable_task("association:remove", "file/protocol associations")
  },
) -> AssociationServices {
  {
    register_protocol_fn: register_protocol,
    register_file_fn: register_file,
    unregister_fn: unregister,
  }
}

///|
pub fn AssociationServices::register_protocol(
  self : AssociationServices,
  registration : ProtocolRegistration,
) -> ServiceTask[Unit] {
  (self.register_protocol_fn)(registration)
}

///|
pub fn AssociationServices::register_file(
  self : AssociationServices,
  association : FileAssociation,
) -> ServiceTask[Unit] {
  (self.register_file_fn)(association)
}

///|
pub fn AssociationServices::unregister(
  self : AssociationServices,
  value : String,
) -> ServiceTask[Unit] {
  (self.unregister_fn)(value)
}

///|
pub struct WindowStateServices {
  read_fn : (String) -> ServiceTask[String?]
  write_fn : (String, String) -> ServiceTask[Unit]
  remove_fn : (String) -> ServiceTask[Unit]
}

///|
pub fn WindowStateServices::new(
  read? : (String) -> ServiceTask[String?] = _window_id => {
    unavailable_task("window-state:read", "window state persistence")
  },
  write? : (String, String) -> ServiceTask[Unit] = (_window_id, _snapshot) => {
    unavailable_task("window-state:write", "window state persistence")
  },
  remove? : (String) -> ServiceTask[Unit] = _window_id => {
    unavailable_task("window-state:remove", "window state persistence")
  },
) -> WindowStateServices {
  { read_fn: read, write_fn: write, remove_fn: remove }
}

///|
pub fn WindowStateServices::read(
  self : WindowStateServices,
  window_id : String,
) -> ServiceTask[String?] {
  (self.read_fn)(window_id)
}

///|
pub fn WindowStateServices::write(
  self : WindowStateServices,
  window_id : String,
  snapshot : String,
) -> ServiceTask[Unit] {
  (self.write_fn)(window_id, snapshot)
}

///|
pub fn WindowStateServices::remove(
  self : WindowStateServices,
  window_id : String,
) -> ServiceTask[Unit] {
  (self.remove_fn)(window_id)
}

///|
pub struct PlatformServices {
  notifications_value : NotificationServices
  tray_value : TrayServices
  permissions_value : PermissionServices
  sharing_value : ShareServices
  printing_value : PrintServices
  associations_value : AssociationServices
  window_state_value : WindowStateServices
  lifecycle_value : AppLifecycleSource?
}

///|
pub fn PlatformServices::new(
  notifications? : NotificationServices = NotificationServices::new(),
  tray? : TrayServices = TrayServices::new(),
  permissions? : PermissionServices = PermissionServices::new(),
  sharing? : ShareServices = ShareServices::new(),
  printing? : PrintServices = PrintServices::new(),
  associations? : AssociationServices = AssociationServices::new(),
  window_state? : WindowStateServices = WindowStateServices::new(),
  lifecycle? : AppLifecycleSource? = None,
) -> PlatformServices {
  {
    notifications_value: notifications,
    tray_value: tray,
    permissions_value: permissions,
    sharing_value: sharing,
    printing_value: printing,
    associations_value: associations,
    window_state_value: window_state,
    lifecycle_value: lifecycle,
  }
}

///|
pub fn PlatformServices::unavailable() -> PlatformServices {
  PlatformServices::new()
}

///|
pub fn PlatformServices::notifications(
  self : PlatformServices,
) -> NotificationServices {
  self.notifications_value
}

///|
pub fn PlatformServices::tray(self : PlatformServices) -> TrayServices {
  self.tray_value
}

///|
pub fn PlatformServices::permissions(
  self : PlatformServices,
) -> PermissionServices {
  self.permissions_value
}

///|
pub fn PlatformServices::sharing(self : PlatformServices) -> ShareServices {
  self.sharing_value
}

///|
pub fn PlatformServices::printing(self : PlatformServices) -> PrintServices {
  self.printing_value
}

///|
pub fn PlatformServices::associations(
  self : PlatformServices,
) -> AssociationServices {
  self.associations_value
}

///|
pub fn PlatformServices::window_state(
  self : PlatformServices,
) -> WindowStateServices {
  self.window_state_value
}

///|
pub fn PlatformServices::lifecycle(
  self : PlatformServices,
) -> AppLifecycleSource? {
  self.lifecycle_value
}
