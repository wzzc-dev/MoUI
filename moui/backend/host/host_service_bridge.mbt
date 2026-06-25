///|
pub(all) enum HostClipboardRequest {
  ReadText
  WriteText(String)
  ReadImage
  WriteImage(String, Bytes)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostFileDialogKind {
  OpenFile
  SaveFile
  PickDirectory
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFileDialogOptions {
  kind : HostFileDialogKind
  title : String
  filters : Array[String]
  default_name : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostTextFileRequest {
  ReadText(String)
  WriteText(String, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostBinaryFileRequest {
  ReadBytes(String)
  WriteBytes(String, Bytes)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostDirectoryEntry {
  name : String
  path : String
  is_directory : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn HostDirectoryEntry::new(
  name~ : String,
  path~ : String,
  is_directory? : Bool = false,
) -> HostDirectoryEntry {
  { name, path, is_directory }
}

///|
pub(all) struct HostBinaryFileDiagnostic {
  path : String
  byte_length : Int
  operation : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceRequest {
  Clipboard(HostClipboardRequest)
  ShowMenu(Array[@core.ActionCommand])
  FileDialog(HostFileDialogOptions)
  TextFile(HostTextFileRequest)
  BinaryFile(HostBinaryFileRequest)
  OpenUrl(String)
  QuerySystemTheme
  ListDirectory(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceResponse {
  Unavailable(String)
  Pending(HostServiceRequestId)
  ClipboardText(String)
  ClipboardWritten
  ClipboardImage(Bytes)
  MenuAction(@core.ActionCommand)
  MenuCommand(@core.CommandIntent)
  FileDialogSelection(Array[String])
  TextFileContent(String, String)
  TextFileWritten(String)
  BinaryFileContent(String, Bytes)
  BinaryFileWritten(String)
  UrlOpened
  SystemTheme(@core.ColorScheme)
  DirectoryListing(String, Array[HostDirectoryEntry])
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceKind {
  ClipboardService
  MenuService
  FileDialogService
  TextFileService
  BinaryFileService
  OpenUrlService
  SystemThemeService
  DirectoryListingService
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceHandler {
  kind : HostServiceKind
  handle : (HostServiceRequest) -> HostServiceResponse
}

///|
pub(all) struct HostServiceBridge {
  capabilities : HostServiceCapabilities
  handle : (HostServiceRequest) -> HostServiceResponse
  mut services : Array[HostServiceHandler]
  channels : PlatformChannelRegistry
}

///|
pub fn HostFileDialogOptions::new(
  kind~ : HostFileDialogKind,
  title? : String = "",
  filters? : Array[String] = [],
  default_name? : String? = None,
) -> HostFileDialogOptions {
  { kind, title, filters, default_name }
}

///|
pub fn HostBinaryFileRequest::diagnostic(
  self : HostBinaryFileRequest,
) -> HostBinaryFileDiagnostic {
  match self {
    ReadBytes(path) => { path, byte_length: 0, operation: "read-bytes" }
    WriteBytes(path, bytes) =>
      { path, byte_length: bytes.length(), operation: "write-bytes" }
  }
}

///|
pub fn HostServiceResponse::binary_file_diagnostic(
  self : HostServiceResponse,
) -> HostBinaryFileDiagnostic? {
  match self {
    BinaryFileContent(path, bytes) =>
      Some({ path, byte_length: bytes.length(), operation: "read-bytes" })
    BinaryFileWritten(path) =>
      Some({ path, byte_length: 0, operation: "write-bytes" })
    _ => None
  }
}

///|
pub fn HostServiceBridge::new(
  capabilities~ : HostServiceCapabilities,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceBridge {
  {
    capabilities,
    handle,
    services: [],
    channels: PlatformChannelRegistry::new(),
  }
}

///|
pub fn HostServiceBridge::unavailable() -> HostServiceBridge {
  HostServiceBridge::new(capabilities=HostServiceCapabilities::none(), handle=request => {
    HostServiceResponse::Unavailable(request.unavailable_message())
  })
}

///|
pub fn HostServiceBridge::dispatch(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse {
  if self.can_handle(request) {
    match self.dispatch_registered_service(request) {
      Some(response) => response
      None => (self.handle)(request)
    }
  } else {
    HostServiceResponse::Unavailable(request.unavailable_message())
  }
}

///|
pub fn HostServiceBridge::query_system_theme(
  self : HostServiceBridge,
) -> @core.ColorScheme? {
  match self.dispatch(HostServiceRequest::QuerySystemTheme) {
    HostServiceResponse::SystemTheme(scheme) => Some(scheme)
    _ => None
  }
}

///|
pub fn HostServiceBridge::environment_with_system_theme(
  self : HostServiceBridge,
  environment : @core.Environment,
) -> @core.Environment {
  match self.query_system_theme() {
    Some(scheme) => environment.with_system_scheme(scheme)
    None => environment
  }
}

///|
pub fn HostServiceBridge::can_handle(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> Bool {
  match request {
    Clipboard(_) => self.capabilities.clipboard
    ShowMenu(_) => self.capabilities.menus
    FileDialog(_) => self.capabilities.file_dialogs
    TextFile(_) => self.capabilities.file_access
    BinaryFile(_) => self.capabilities.file_access
    OpenUrl(_) => self.capabilities.open_url
    QuerySystemTheme => self.capabilities.system_theme
    ListDirectory(_) => self.capabilities.file_access
  }
}

///|
pub fn HostServiceRequest::unavailable_message(
  self : HostServiceRequest,
) -> String {
  match self {
    Clipboard(_) => "clipboard service is unavailable"
    ShowMenu(_) => "menu service is unavailable"
    FileDialog(_) => "file dialog service is unavailable"
    TextFile(_) => "text file service is unavailable"
    BinaryFile(_) => "binary file service is unavailable"
    OpenUrl(_) => "open URL service is unavailable"
    QuerySystemTheme => "system theme service is unavailable"
    ListDirectory(_) => "directory listing service is unavailable"
  }
}

///|
pub fn HostServiceRequest::kind(self : HostServiceRequest) -> HostServiceKind {
  match self {
    Clipboard(_) => ClipboardService
    ShowMenu(_) => MenuService
    FileDialog(_) => FileDialogService
    TextFile(_) => TextFileService
    BinaryFile(_) => BinaryFileService
    OpenUrl(_) => OpenUrlService
    QuerySystemTheme => SystemThemeService
    ListDirectory(_) => DirectoryListingService
  }
}

///|
pub fn HostServiceHandler::new(
  kind~ : HostServiceKind,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceHandler {
  { kind, handle }
}

///|
pub fn HostServiceBridge::register_service(
  self : HostServiceBridge,
  handler : HostServiceHandler,
) -> Unit {
  self.services = self.services.filter(existing => existing.kind != handler.kind)
  self.services.push(handler)
}

///|
pub fn HostServiceBridge::dispatch_registered_service(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse? {
  let kind = request.kind()
  for handler in self.services {
    if handler.kind == kind {
      return Some((handler.handle)(request))
    }
  }
  None
}
