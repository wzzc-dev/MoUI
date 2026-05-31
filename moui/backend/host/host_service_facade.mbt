///|
pub struct HostAppServices {
  bridge : HostServiceBridge
  async_queue : HostServiceAsyncQueue?
}

///|
pub fn HostAppServices::new(
  bridge~ : HostServiceBridge,
  async_queue? : HostServiceAsyncQueue? = None,
) -> HostAppServices {
  { bridge, async_queue }
}

///|
pub fn HostAppServices::unavailable() -> HostAppServices {
  HostAppServices::new(bridge=HostServiceBridge::unavailable())
}

///|
pub fn HostAppServices::capabilities(
  self : HostAppServices,
) -> HostServiceCapabilities {
  self.bridge.capabilities
}

///|
pub fn HostAppServices::dispatch(
  self : HostAppServices,
  request : HostServiceRequest,
) -> HostServiceResponse {
  self.bridge.dispatch(request)
}

///|
pub fn HostAppServices::read_clipboard_text(
  self : HostAppServices,
) -> HostServiceResponse {
  self.dispatch(HostServiceRequest::Clipboard(HostClipboardRequest::ReadText))
}

///|
pub fn HostAppServices::write_clipboard_text(
  self : HostAppServices,
  text : String,
) -> HostServiceResponse {
  self.dispatch(
    HostServiceRequest::Clipboard(HostClipboardRequest::WriteText(text)),
  )
}

///|
pub fn HostAppServices::file_dialog(
  self : HostAppServices,
  options : HostFileDialogOptions,
) -> HostServiceResponse {
  self.dispatch(HostServiceRequest::FileDialog(options))
}

///|
pub fn HostAppServices::open_file(
  self : HostAppServices,
  title? : String = "",
  filters? : Array[String] = [],
) -> HostServiceResponse {
  self.file_dialog(
    HostFileDialogOptions::new(
      kind=HostFileDialogKind::OpenFile,
      title~,
      filters~,
    ),
  )
}

///|
pub fn HostAppServices::save_file(
  self : HostAppServices,
  title? : String = "",
  default_name? : String? = None,
  filters? : Array[String] = [],
) -> HostServiceResponse {
  self.file_dialog(
    HostFileDialogOptions::new(
      kind=HostFileDialogKind::SaveFile,
      title~,
      filters~,
      default_name~,
    ),
  )
}

///|
pub fn HostAppServices::pick_directory(
  self : HostAppServices,
  title? : String = "",
) -> HostServiceResponse {
  self.file_dialog(
    HostFileDialogOptions::new(kind=HostFileDialogKind::PickDirectory, title~),
  )
}

///|
pub fn HostAppServices::open_url(
  self : HostAppServices,
  url : String,
) -> HostServiceResponse {
  self.dispatch(HostServiceRequest::OpenUrl(url))
}

///|
pub fn HostAppServices::request_system_theme(
  self : HostAppServices,
) -> HostServiceResponse {
  self.dispatch(HostServiceRequest::QuerySystemTheme)
}

///|
pub fn HostAppServices::system_theme(
  self : HostAppServices,
) -> @core.ColorScheme? {
  match self.request_system_theme() {
    HostServiceResponse::SystemTheme(scheme) => Some(scheme)
    _ => None
  }
}

///|
pub fn HostAppServices::show_context_menu(
  self : HostAppServices,
  commands : Array[@core.ActionCommand],
) -> HostServiceResponse {
  self.dispatch(HostServiceRequest::ShowMenu(commands))
}

///|
pub fn HostAppServices::has_async_queue(self : HostAppServices) -> Bool {
  self.async_queue is Some(_)
}

///|
pub fn HostAppServices::pending_count(self : HostAppServices) -> Int {
  match self.async_queue {
    Some(queue) => queue.pending_count()
    None => 0
  }
}

///|
pub fn HostAppServices::in_flight_count(self : HostAppServices) -> Int {
  match self.async_queue {
    Some(queue) => queue.in_flight_count()
    None => 0
  }
}

///|
pub fn HostAppServices::completed_count(self : HostAppServices) -> Int {
  match self.async_queue {
    Some(queue) => queue.completed_count()
    None => 0
  }
}

///|
pub fn HostAppServices::outstanding_count(self : HostAppServices) -> Int {
  match self.async_queue {
    Some(queue) => queue.outstanding_count()
    None => 0
  }
}

///|
pub fn HostAppServices::drain_pending(
  self : HostAppServices,
) -> Array[HostPendingServiceRequest] {
  match self.async_queue {
    Some(queue) => queue.drain_pending()
    None => []
  }
}

///|
pub fn HostAppServices::complete(
  self : HostAppServices,
  id : HostServiceRequestId,
  response : HostServiceResponse,
) -> Bool {
  match self.async_queue {
    Some(queue) => queue.complete(id, response)
    None => false
  }
}

///|
pub fn HostAppServices::reject(
  self : HostAppServices,
  id : HostServiceRequestId,
  reason : String,
) -> Bool {
  match self.async_queue {
    Some(queue) => queue.reject(id, reason)
    None => false
  }
}

///|
pub fn HostAppServices::on_completed(
  self : HostAppServices,
  id : HostServiceRequestId,
  handle : (HostCompletedServiceResponse) -> Unit,
) -> Bool {
  match self.async_queue {
    Some(queue) => queue.on_completed(id, handle)
    None => false
  }
}

///|
pub fn HostAppServices::take_completed(
  self : HostAppServices,
  id : HostServiceRequestId,
) -> HostCompletedServiceResponse? {
  match self.async_queue {
    Some(queue) => queue.take_completed(id)
    None => None
  }
}

///|
pub fn HostAppServices::drain_completed(
  self : HostAppServices,
) -> Array[HostCompletedServiceResponse] {
  match self.async_queue {
    Some(queue) => queue.drain_completed()
    None => []
  }
}
