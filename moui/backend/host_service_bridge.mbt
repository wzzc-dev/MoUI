///|
pub(all) enum HostClipboardRequest {
  ReadText
  WriteText(String)
  ReadImage
  WriteImage(String, Bytes)
} derive(Eq, Debug, ToJson)

///|
pub extend HostClipboardRequest with Debug::{to_repr}

///|
pub extend HostClipboardRequest with Eq::{not_equal, equal}

///|
pub extend HostClipboardRequest with ToJson::{to_json}

///|
pub(all) enum HostFileDialogKind {
  OpenFile
  SaveFile
  PickDirectory
} derive(Eq, Debug, ToJson)

///|
pub extend HostFileDialogKind with Debug::{to_repr}

///|
pub extend HostFileDialogKind with Eq::{not_equal, equal}

///|
pub extend HostFileDialogKind with ToJson::{to_json}

///|
pub(all) struct HostFileDialogOptions {
  kind : HostFileDialogKind
  title : String
  filters : Array[String]
  default_name : String?
} derive(Eq, Debug, ToJson)

///|
pub extend HostFileDialogOptions with Debug::{to_repr}

///|
pub extend HostFileDialogOptions with Eq::{not_equal, equal}

///|
pub extend HostFileDialogOptions with ToJson::{to_json}

///|
pub(all) enum HostTextFileRequest {
  ReadText(String)
  WriteText(String, String)
} derive(Eq, Debug, ToJson)

///|
pub extend HostTextFileRequest with Debug::{to_repr}

///|
pub extend HostTextFileRequest with Eq::{not_equal, equal}

///|
pub extend HostTextFileRequest with ToJson::{to_json}

///|
pub(all) enum HostBinaryFileRequest {
  ReadBytes(String)
  WriteBytes(String, Bytes)
} derive(Eq, Debug, ToJson)

///|
pub extend HostBinaryFileRequest with Debug::{to_repr}

///|
pub extend HostBinaryFileRequest with Eq::{not_equal, equal}

///|
pub extend HostBinaryFileRequest with ToJson::{to_json}

///|
pub(all) enum HostSettingsRequest {
  Read(String)
  Write(String, String)
  Remove(String)
} derive(Eq, Debug, ToJson)

///|
pub extend HostSettingsRequest with Debug::{to_repr}

///|
pub extend HostSettingsRequest with Eq::{not_equal, equal}

///|
pub extend HostSettingsRequest with ToJson::{to_json}

///|
pub struct HostDirectoryEntry {
  priv name : String
  priv path : String
  priv is_directory : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend HostDirectoryEntry with Debug::{to_repr}

///|
pub extend HostDirectoryEntry with Eq::{not_equal, equal}

///|
pub extend HostDirectoryEntry with ToJson::{to_json}

///|
pub fn HostDirectoryEntry::new(
  name~ : String,
  path~ : String,
  is_directory? : Bool = false,
) -> HostDirectoryEntry {
  { name, path, is_directory, }
}

///|
pub fn HostDirectoryEntry::name(self : HostDirectoryEntry) -> String {
  self.name
}

///|
pub fn HostDirectoryEntry::path(self : HostDirectoryEntry) -> String {
  self.path
}

///|
pub fn HostDirectoryEntry::is_directory(self : HostDirectoryEntry) -> Bool {
  self.is_directory
}

///|
pub struct HostBinaryFileDiagnostic {
  priv path : String
  priv byte_length : Int
  priv operation : String
} derive(Eq, Debug, ToJson)

///|
pub extend HostBinaryFileDiagnostic with Debug::{to_repr}

///|
pub extend HostBinaryFileDiagnostic with Eq::{not_equal, equal}

///|
pub extend HostBinaryFileDiagnostic with ToJson::{to_json}

///|
pub(all) enum HostServiceRequest {
  Clipboard(HostClipboardRequest)
  ShowMenu(Array[@core.ActionCommand])
  /// Install a host application menu bar (L2). Context menus stay on
  /// `ShowMenu`. Platforms without a native app menu return `Unavailable`.
  SetApplicationMenu(Array[HostApplicationMenu])
  FileDialog(HostFileDialogOptions)
  TextFile(HostTextFileRequest)
  BinaryFile(HostBinaryFileRequest)
  OpenUrl(String)
  QuerySystemTheme
  Settings(HostSettingsRequest)
  ListDirectory(String)
  /// 删除一个文件(资源管理器 M0-6b)。复用 `file_access` 能力掩码:
  /// native 可达,web 无文件系统 → 能力判定直接显式不可用。
  DeleteFile(String)
  PlatformChannel(PlatformChannelRequest)
} derive(Eq, Debug, ToJson)

///|
pub extend HostServiceRequest with Debug::{to_repr}

///|
pub extend HostServiceRequest with Eq::{not_equal, equal}

///|
pub extend HostServiceRequest with ToJson::{to_json}

///|
pub(all) enum HostApplicationMenuPlacement {
  MenuBar
  ApplicationMenu
} derive(Eq, Debug, ToJson)

///|
pub extend HostApplicationMenuPlacement with Debug::{to_repr}

///|
pub extend HostApplicationMenuPlacement with Eq::{not_equal, equal}

///|
pub extend HostApplicationMenuPlacement with ToJson::{to_json}

///|
/// One application menu group. `MenuBar` creates a top-level menu; hosts with
/// a standard application menu may place `ApplicationMenu` items there.
pub(all) struct HostApplicationMenu {
  title : String
  items : Array[HostApplicationMenuItem]
  placement : HostApplicationMenuPlacement
} derive(Eq, Debug, ToJson)

///|
pub extend HostApplicationMenu with Debug::{to_repr}

///|
pub extend HostApplicationMenu with Eq::{not_equal, equal}

///|
pub extend HostApplicationMenu with ToJson::{to_json}

///|
/// One item in a host application menu bar.
///
/// Use `separator=true` for dividers; other fields are ignored for separators.
/// `action_id` is host-defined and is delivered to the platform action handler
/// when the item is chosen. Keyboard accelerators use `key_equivalent` plus
/// `key_modifier_mask` (platform bit masks; see platform notes).
pub(all) struct HostApplicationMenuItem {
  title : String
  action_id : Int
  key_equivalent : String
  key_modifier_mask : Int
  separator : Bool
  enabled : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend HostApplicationMenuItem with Debug::{to_repr}

///|
pub extend HostApplicationMenuItem with Eq::{not_equal, equal}

///|
pub extend HostApplicationMenuItem with ToJson::{to_json}

///|
pub fn HostApplicationMenu::new(
  title~ : String,
  items~ : Array[HostApplicationMenuItem],
  placement? : HostApplicationMenuPlacement = MenuBar,
) -> HostApplicationMenu {
  { title, items, placement, }
}

///|
pub fn HostApplicationMenuItem::new(
  title~ : String,
  action_id~ : Int,
  key_equivalent? : String = "",
  key_modifier_mask? : Int = 0,
  separator? : Bool = false,
  enabled? : Bool = true,
) -> HostApplicationMenuItem {
  { title, action_id, key_equivalent, key_modifier_mask, separator, enabled, }
}

///|
pub fn HostApplicationMenuItem::separator() -> HostApplicationMenuItem {
  HostApplicationMenuItem::new(
    title="",
    action_id=0,
    key_equivalent="",
    key_modifier_mask=-1,
    separator=true,
    enabled=false,
  )
}

///|
pub(all) enum HostServiceResponse {
  Unavailable(String)
  Pending(HostServiceRequestId)
  ClipboardText(String)
  ClipboardWritten
  ClipboardImage(Bytes)
  MenuAction(@core.ActionCommand)
  MenuCommand(@core.CommandIntent)
  ApplicationMenuInstalled
  FileDialogSelection(Array[String])
  TextFileContent(String, String)
  TextFileWritten(String)
  BinaryFileContent(String, Bytes)
  BinaryFileWritten(String)
  UrlOpened
  SystemTheme(@core.ColorScheme)
  SettingValue(String?)
  SettingWritten
  SettingRemoved
  DirectoryListing(String, Array[HostDirectoryEntry])
  FileDeleted(String)
  PlatformChannel(PlatformChannelResponse)
} derive(Eq, Debug, ToJson)

///|
pub extend HostServiceResponse with Debug::{to_repr}

///|
pub extend HostServiceResponse with Eq::{not_equal, equal}

///|
pub extend HostServiceResponse with ToJson::{to_json}

///|
pub(all) enum HostServiceKind {
  ClipboardService
  MenuService
  FileDialogService
  TextFileService
  BinaryFileService
  OpenUrlService
  SystemThemeService
  SettingsService
  DirectoryListingService
  FileDeleteService
  PlatformChannelService
} derive(Eq, Debug, ToJson)

///|
pub extend HostServiceKind with Debug::{to_repr}

///|
pub extend HostServiceKind with Eq::{not_equal, equal}

///|
pub extend HostServiceKind with ToJson::{to_json}

///|
pub struct HostServiceBridge {
  priv capabilities : HostServiceCapabilities
  priv handle : (HostServiceRequest) -> HostServiceResponse
}

///|
pub fn HostFileDialogOptions::new(
  kind~ : HostFileDialogKind,
  title? : String = "",
  filters? : Array[String] = [],
  default_name? : String? = None,
) -> HostFileDialogOptions {
  { kind, title, filters, default_name, }
}

///|
pub fn HostBinaryFileRequest::diagnostic(
  self : HostBinaryFileRequest,
) -> HostBinaryFileDiagnostic {
  match self {
    ReadBytes(path) => { path, byte_length: 0, operation: "read-bytes", }
    WriteBytes(path, bytes) =>
      { path, byte_length: bytes.length(), operation: "write-bytes", }
  }
}

///|
pub fn HostBinaryFileDiagnostic::path(
  self : HostBinaryFileDiagnostic,
) -> String {
  self.path
}

///|
pub fn HostBinaryFileDiagnostic::byte_length(
  self : HostBinaryFileDiagnostic,
) -> Int {
  self.byte_length
}

///|
pub fn HostBinaryFileDiagnostic::operation(
  self : HostBinaryFileDiagnostic,
) -> String {
  self.operation
}

///|
pub fn HostServiceResponse::binary_file_diagnostic(
  self : HostServiceResponse,
) -> HostBinaryFileDiagnostic? {
  match self {
    BinaryFileContent(path, bytes) =>
      Some({ path, byte_length: bytes.length(), operation: "read-bytes", })
    BinaryFileWritten(path) =>
      Some({ path, byte_length: 0, operation: "write-bytes", })
    _ => None
  }
}

///|
pub fn HostServiceBridge::new(
  capabilities~ : HostServiceCapabilities,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceBridge {
  { capabilities, handle, }
}

///|
pub fn HostServiceBridge::unavailable() -> HostServiceBridge {
  HostServiceBridge::new(capabilities=HostServiceCapabilities::none(), handle=request => {
    Unavailable(request.unavailable_message())
  })
}

///|
pub fn HostServiceBridge::capabilities(
  self : HostServiceBridge,
) -> HostServiceCapabilities {
  self.capabilities
}

///|
pub fn HostServiceBridge::dispatch(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse {
  if self.can_handle(request) {
    (self.handle)(request)
  } else {
    Unavailable(request.unavailable_message())
  }
}

///|
pub fn HostServiceBridge::query_system_theme(
  self : HostServiceBridge,
) -> @core.ColorScheme? {
  match self.dispatch(QuerySystemTheme) {
    SystemTheme(scheme) => Some(scheme)
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
    SetApplicationMenu(_) => self.capabilities.menus
    FileDialog(_) => self.capabilities.file_dialogs
    TextFile(_) => self.capabilities.file_access
    BinaryFile(_) => self.capabilities.file_access
    OpenUrl(_) => self.capabilities.open_url
    QuerySystemTheme => self.capabilities.system_theme
    Settings(_) => self.capabilities.settings
    ListDirectory(_) => self.capabilities.file_access
    DeleteFile(_) => self.capabilities.file_access
    PlatformChannel(_) => true
  }
}

///|
pub fn HostServiceRequest::unavailable_message(
  self : HostServiceRequest,
) -> String {
  match self {
    Clipboard(_) => "clipboard service is unavailable"
    ShowMenu(_) => "menu service is unavailable"
    SetApplicationMenu(_) => "application menu bar service is unavailable"
    FileDialog(_) => "file dialog service is unavailable"
    TextFile(_) => "text file service is unavailable"
    BinaryFile(_) => "binary file service is unavailable"
    OpenUrl(_) => "open URL service is unavailable"
    QuerySystemTheme => "system theme service is unavailable"
    Settings(_) => "settings service is unavailable"
    ListDirectory(_) => "directory listing service is unavailable"
    DeleteFile(_) => "file deletion service is unavailable"
    PlatformChannel(request) =>
      "platform channel is unavailable: " + request.channel
  }
}

///|
pub fn HostServiceRequest::kind(self : HostServiceRequest) -> HostServiceKind {
  match self {
    Clipboard(_) => ClipboardService
    ShowMenu(_) => MenuService
    SetApplicationMenu(_) => MenuService
    FileDialog(_) => FileDialogService
    TextFile(_) => TextFileService
    BinaryFile(_) => BinaryFileService
    OpenUrl(_) => OpenUrlService
    QuerySystemTheme => SystemThemeService
    Settings(_) => SettingsService
    ListDirectory(_) => DirectoryListingService
    DeleteFile(_) => FileDeleteService
    PlatformChannel(_) => PlatformChannelService
  }
}
