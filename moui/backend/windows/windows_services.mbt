///|
pub fn windows_service_bridge(
  system_theme? : @core.ColorScheme = windows_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_windows_clipboard,
  open_url? : (String) -> Bool = dispatch_windows_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_windows_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = dispatch_windows_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = dispatch_windows_binary_file,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_windows_menu,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
      menus=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(clipboard_request) =>
          clipboard(clipboard_request)
        @host.HostServiceRequest::OpenUrl(url) =>
          if open_url(url) {
            @host.HostServiceResponse::UrlOpened
          } else {
            @host.HostServiceResponse::Unavailable("open URL failed")
          }
        @host.HostServiceRequest::FileDialog(options) =>
          @host.HostServiceResponse::FileDialogSelection(file_dialog(options))
        @host.HostServiceRequest::TextFile(text_file_request) =>
          text_file(text_file_request)
        @host.HostServiceRequest::BinaryFile(binary_file_request) =>
          binary_file(binary_file_request)
        @host.HostServiceRequest::ShowMenu(commands) =>
          menu_command_response(commands, menu(commands))
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(system_theme)
        @host.HostServiceRequest::ListDirectory(_) =>
          @host.HostServiceResponse::Unavailable(
            "directory listing service is unavailable",
          )
        @host.HostServiceRequest::PlatformChannel(_) =>
          @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}
