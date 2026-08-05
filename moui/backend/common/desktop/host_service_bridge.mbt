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
    @host.HostServiceResponse::Unavailable(
      "application menu bar service is unavailable",
    )
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
      @host.HostServiceRequest::Clipboard(value) => (self.clipboard)(value)
      @host.HostServiceRequest::ShowMenu(commands) => (self.show_menu)(commands)
      @host.HostServiceRequest::SetApplicationMenu(menus) =>
        (self.set_application_menu)(menus)
      @host.HostServiceRequest::FileDialog(options) =>
        @host.HostServiceResponse::FileDialogSelection(
          (self.file_dialog)(options),
        )
      @host.HostServiceRequest::TextFile(value) => (self.text_file)(value)
      @host.HostServiceRequest::BinaryFile(value) => (self.binary_file)(value)
      @host.HostServiceRequest::OpenUrl(url) =>
        if (self.open_url)(url) {
          @host.HostServiceResponse::UrlOpened
        } else {
          @host.HostServiceResponse::Unavailable("open URL failed")
        }
      @host.HostServiceRequest::QuerySystemTheme =>
        @host.HostServiceResponse::SystemTheme(self.system_theme)
      @host.HostServiceRequest::Settings(value) => (self.settings)(value)
      @host.HostServiceRequest::ListDirectory(path) =>
        (self.list_directory)(path)
      @host.HostServiceRequest::PlatformChannel(_) =>
        @host.HostServiceResponse::Unavailable(request.unavailable_message())
    }
  })
}
