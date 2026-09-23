///|
/// Platform callbacks consumed by the shared desktop service router.
/// Filesystem-backed operations default to the shared implementations below.
pub struct DesktopHostServices {
  capabilities : @host.HostServiceCapabilities
  system_theme : @core.ColorScheme
  clipboard : (@host.HostClipboardRequest) -> @host.HostServiceResponse
  open_url : (String) -> Bool
  file_dialog : (@host.HostFileDialogOptions) -> Array[String]
  text_file : (@host.HostTextFileRequest) -> @host.HostServiceResponse
  binary_file : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse
  settings : (@host.HostSettingsRequest) -> @host.HostServiceResponse
  show_menu : (Array[@core.ActionCommand]) -> @host.HostServiceResponse
  set_application_menu : (Array[@host.HostApplicationMenu]) -> @host.HostServiceResponse
  list_directory : (String) -> @host.HostServiceResponse
}

///|
pub fn DesktopHostServices::new(
  capabilities~ : @host.HostServiceCapabilities,
  system_theme~ : @core.ColorScheme,
  clipboard~ : (@host.HostClipboardRequest) -> @host.HostServiceResponse,
  open_url~ : (String) -> Bool,
  file_dialog~ : (@host.HostFileDialogOptions) -> Array[String],
  settings~ : (@host.HostSettingsRequest) -> @host.HostServiceResponse,
  show_menu~ : (Array[@core.ActionCommand]) -> @host.HostServiceResponse,
  set_application_menu? : (Array[@host.HostApplicationMenu]) -> @host.HostServiceResponse = _ => {
    Unavailable("application menu bar service is unavailable")
  },
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_binary_file,
  list_directory? : (String) -> @host.HostServiceResponse = @host_services_native.dispatch_list_directory,
) -> DesktopHostServices {
  {
    capabilities,
    system_theme,
    clipboard,
    open_url,
    file_dialog,
    text_file,
    binary_file,
    settings,
    show_menu,
    set_application_menu,
    list_directory,
  }
}

///|
pub fn DesktopHostServices::bridge(
  self : DesktopHostServices,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(capabilities=self.capabilities, handle=request => {
    match request {
      Clipboard(value) => (self.clipboard)(value)
      ShowMenu(commands) => (self.show_menu)(commands)
      SetApplicationMenu(menus) => (self.set_application_menu)(menus)
      FileDialog(options) => FileDialogSelection((self.file_dialog)(options))
      TextFile(value) => (self.text_file)(value)
      BinaryFile(value) => (self.binary_file)(value)
      OpenUrl(url) =>
        if (self.open_url)(url) {
          UrlOpened
        } else {
          Unavailable("open URL failed")
        }
      QuerySystemTheme => SystemTheme(self.system_theme)
      Settings(value) => (self.settings)(value)
      ListDirectory(path) => (self.list_directory)(path)
      PlatformChannel(_) => Unavailable(request.unavailable_message())
    }
  })
}
