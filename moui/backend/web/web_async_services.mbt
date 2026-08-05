///|
enum WebAsyncHostServiceKind {
  ClipboardReadText
  ClipboardReadImage
  ClipboardWriteImage
  FileDialogOpenFile
  FileDialogSaveFile
  FileDialogPickDirectory
  TextFileReadText
  TextFileWriteText
} derive(Eq, Debug, ToJson)

///|
struct WebAsyncHostServiceRequest {
  id : @host.HostServiceRequestId
  kind : WebAsyncHostServiceKind
  title : String
  filters : Array[String]
  default_name : String
  path : String
  text : String
} derive(Eq, Debug, ToJson)

///|
priv struct WebTextFileCacheEntry {
  path : String
  text : String
}

///|
priv struct WebTextFileWriteEntry {
  request_id : Int
  path : String
  text : String
}

///|
priv struct WebTextFileReadEntry {
  request_id : Int
  path : String
}

///|
let web_active_async_queue : Ref[@window_host.ServiceAsyncQueue?] = Ref(None)

///|
let web_shared_async_queue : @window_host.ServiceAsyncQueue = @window_host.ServiceAsyncQueue::new()

///|
let web_text_file_cache : Ref[Array[WebTextFileCacheEntry]] = Ref([])

///|
let web_text_file_writes : Ref[Array[WebTextFileWriteEntry]] = Ref([])

///|
let web_text_file_reads : Ref[Array[WebTextFileReadEntry]] = Ref([])

///|
fn WebAsyncHostServiceKind::browser_code(self : WebAsyncHostServiceKind) -> Int {
  match self {
    ClipboardReadText => -1
    ClipboardReadImage => -4
    ClipboardWriteImage => -5
    FileDialogOpenFile => 0
    FileDialogSaveFile => 1
    FileDialogPickDirectory => 2
    TextFileReadText => -3
    TextFileWriteText => -2
  }
}

///|
fn WebAsyncHostServiceRequest::from_pending(
  pending : @host.HostPendingServiceRequest,
) -> WebAsyncHostServiceRequest? {
  match pending.request {
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::ClipboardReadText,
        title: "",
        filters: [],
        default_name: "",
        path: "",
        text: "",
      })
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadImage) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::ClipboardReadImage,
        title: "",
        filters: [],
        default_name: "",
        path: "",
        text: "",
      })
    @host.HostServiceRequest::Clipboard(
      @host.HostClipboardRequest::WriteImage(_mime, bytes)
    ) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::ClipboardWriteImage,
        title: "",
        filters: [],
        default_name: "",
        path: "",
        text: @base64.encode(bytes[:]),
      })
    @host.HostServiceRequest::FileDialog(options) =>
      Some({
        id: pending.id,
        kind: match options.kind {
          @host.HostFileDialogKind::OpenFile =>
            WebAsyncHostServiceKind::FileDialogOpenFile
          @host.HostFileDialogKind::SaveFile =>
            WebAsyncHostServiceKind::FileDialogSaveFile
          @host.HostFileDialogKind::PickDirectory =>
            WebAsyncHostServiceKind::FileDialogPickDirectory
        },
        title: options.title,
        filters: options.filters,
        default_name: match options.default_name {
          Some(name) => name
          None => ""
        },
        path: "",
        text: "",
      })
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path)
    ) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::TextFileReadText,
        title: "",
        filters: [],
        default_name: "",
        path,
        text: "",
      })
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::WriteText(path, text)
    ) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::TextFileWriteText,
        title: "",
        filters: [],
        default_name: "",
        path,
        text,
      })
    _ => None
  }
}

///|
fn drain_web_async_host_service_requests(
  queue : @window_host.ServiceAsyncQueue,
) -> Array[WebAsyncHostServiceRequest] {
  let requests : Array[WebAsyncHostServiceRequest] = []
  for pending in queue.drain_pending() {
    match WebAsyncHostServiceRequest::from_pending(pending) {
      Some(request) => requests.push(request)
      None =>
        ignore(queue.reject(pending.id, pending.request.unavailable_message()))
    }
  }
  requests
}

///|
fn dispatch_web_async_host_service_request(
  request : WebAsyncHostServiceRequest,
) -> Unit {
  match request.kind {
    ClipboardReadText => web_async_clipboard_read_text(request.id.value)
    ClipboardReadImage => web_async_clipboard_read_image(request.id.value)
    ClipboardWriteImage =>
      ignore(
        web_complete_async_clipboard_write_image(
          request.id.value,
          web_clipboard_write_image(web_host_string(request.text)),
        ),
      )
    FileDialogOpenFile | FileDialogSaveFile | FileDialogPickDirectory =>
      web_async_file_dialog_open(
        request.id.value,
        request.kind.browser_code(),
        web_host_string(request.title),
        web_host_string(request.filters.join("\n")),
        web_host_string(request.default_name),
      )
    TextFileReadText =>
      web_async_text_file_read(request.id.value, web_host_string(request.path))
    TextFileWriteText =>
      web_async_text_file_write(
        request.id.value,
        web_host_string(request.path),
        web_host_string(request.text),
      )
  }
}

///|
fn set_web_async_host_service_queue(
  queue : @window_host.ServiceAsyncQueue?,
) -> Unit {
  web_active_async_queue.val = queue
}

///|
fn web_async_host_service_queue() -> @window_host.ServiceAsyncQueue {
  web_shared_async_queue
}

///|
fn web_complete_async_clipboard_read_text(
  request_id : Int,
  ok : Bool,
  text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        queue.complete(id, @host.HostServiceResponse::ClipboardText(text))
      } else {
        queue.reject(
          id,
          web_async_failure_reason(text, "clipboard read is unavailable on Web"),
        )
      }
    }
    None => false
  }
}

//|

///|
fn web_complete_async_clipboard_read_image_text(
  request_id : Int,
  ok : Bool,
  base64_png : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok && base64_png != "" {
        queue.complete(
          id,
          @host.HostServiceResponse::ClipboardImage(
            @base64.decode(base64_png, ignore_whitespace=false) catch {
              _ => return queue.reject(id, "clipboard image decode failed")
            },
          ),
        )
      } else {
        queue.reject(
          id,
          web_async_failure_reason(
            base64_png, "clipboard image read is unavailable on Web",
          ),
        )
      }
    }
    None => false
  }
}

//|

///|
fn web_complete_async_clipboard_write_image(
  request_id : Int,
  ok : Bool,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        queue.complete(id, @host.HostServiceResponse::ClipboardWritten)
      } else {
        queue.reject(id, "clipboard image write failed on Web")
      }
    }
    None => false
  }
}

///|
fn web_complete_async_text_file_read_text(
  request_id : Int,
  ok : Bool,
  text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        match web_take_text_file_read(request_id) {
          Some(entry) => {
            web_cache_text_file(entry.path, text)
            queue.complete(
              id,
              @host.HostServiceResponse::TextFileContent(entry.path, text),
            )
          }
          None =>
            queue.reject(
              id, "text file read request is no longer pending on Web",
            )
        }
      } else {
        ignore(web_take_text_file_read(request_id))
        queue.reject(
          id,
          web_async_failure_reason(
            text, "text file reading is unavailable on Web",
          ),
        )
      }
    }
    None => false
  }
}

///|
fn web_complete_async_text_file_write_text(
  request_id : Int,
  ok : Bool,
  text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        let path = match web_take_text_file_write(request_id) {
          Some(entry) => {
            web_cache_text_file(entry.path, entry.text)
            entry.path
          }
          None => text
        }
        queue.complete(id, @host.HostServiceResponse::TextFileWritten(path))
      } else {
        ignore(web_take_text_file_write(request_id))
        queue.reject(
          id,
          web_async_failure_reason(
            text, "text file writing is unavailable on Web",
          ),
        )
      }
    }
    None => false
  }
}

///|
fn web_complete_async_file_open_text_values(
  request_id : Int,
  ok : Bool,
  path : String,
  text : String,
) -> Bool {
  if ok {
    if path != "" {
      web_cache_text_file(path, text)
    }
    web_complete_async_file_dialog_selection_text(request_id, true, path)
  } else {
    web_complete_async_file_dialog_selection_text(
      request_id,
      false,
      web_async_failure_reason(text, path),
    )
  }
}

///|
fn web_complete_async_file_dialog_selection_text(
  request_id : Int,
  ok : Bool,
  selection_text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        queue.complete(
          id,
          @host.HostServiceResponse::FileDialogSelection(
            decode_web_file_dialog_selection(selection_text),
          ),
        )
      } else {
        queue.reject(
          id,
          web_async_failure_reason(
            selection_text, "file dialog is unavailable on Web",
          ),
        )
      }
    }
    None => false
  }
}

///|
pub fn web_complete_async_clipboard_read(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_clipboard_read_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

//|

///|
pub fn web_complete_async_clipboard_read_image(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_clipboard_read_image_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
pub fn web_complete_async_file_dialog(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_file_dialog_selection_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
pub fn web_complete_async_file_open_text(
  request_id : Int,
  ok : Bool,
  path_id : Int,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_file_open_text_values(
      request_id,
      ok,
      web_host_string_from_id(path_id),
      web_host_string_from_id(text_id),
    ),
  )
}

///|
pub fn web_complete_async_text_file_read(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_text_file_read_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
pub fn web_complete_async_text_file_write(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_text_file_write_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
fn decode_web_file_dialog_selection(text : String) -> Array[String] {
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = path_view.to_owned()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}

///|
fn web_remember_text_file_read(request_id : Int, path : String) -> Unit {
  let entries : Array[WebTextFileReadEntry] = []
  for entry in web_text_file_reads.val {
    if entry.request_id != request_id {
      entries.push(entry)
    }
  }
  entries.push({ request_id, path })
  web_text_file_reads.val = entries
}

///|
fn web_take_text_file_read(request_id : Int) -> WebTextFileReadEntry? {
  let entries : Array[WebTextFileReadEntry] = []
  let mut found : WebTextFileReadEntry? = None
  for entry in web_text_file_reads.val {
    if found is None && entry.request_id == request_id {
      found = Some(entry)
    } else {
      entries.push(entry)
    }
  }
  web_text_file_reads.val = entries
  found
}

///|
fn web_remember_text_file_write(
  request_id : Int,
  path : String,
  text : String,
) -> Unit {
  let entries : Array[WebTextFileWriteEntry] = []
  for entry in web_text_file_writes.val {
    if entry.request_id != request_id {
      entries.push(entry)
    }
  }
  entries.push({ request_id, path, text })
  web_text_file_writes.val = entries
}

///|
fn web_take_text_file_write(request_id : Int) -> WebTextFileWriteEntry? {
  let entries : Array[WebTextFileWriteEntry] = []
  let mut found : WebTextFileWriteEntry? = None
  for entry in web_text_file_writes.val {
    if found is None && entry.request_id == request_id {
      found = Some(entry)
    } else {
      entries.push(entry)
    }
  }
  web_text_file_writes.val = entries
  found
}

///|
fn web_cache_text_file(path : String, text : String) -> Unit {
  let entries : Array[WebTextFileCacheEntry] = []
  for entry in web_text_file_cache.val {
    if entry.path != path {
      entries.push(entry)
    }
  }
  entries.push({ path, text })
  web_text_file_cache.val = entries
}

///|
fn web_cached_text_file(path : String) -> String? {
  for entry in web_text_file_cache.val {
    if entry.path == path {
      return Some(entry.text)
    }
  }
  None
}

///|
fn web_async_failure_reason(message : String, fallback : String) -> String {
  if message == "" {
    fallback
  } else {
    message
  }
}
