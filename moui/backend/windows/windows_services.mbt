///|
pub fn windows_service_bridge(
  system_theme? : @core.ColorScheme = windows_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_windows_clipboard,
  open_url? : (String) -> Bool = dispatch_windows_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_windows_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_binary_file,
  settings? : (@host.HostSettingsRequest) -> @host.HostServiceResponse = dispatch_windows_settings,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_windows_menu,
  list_directory? : (String) -> @host.HostServiceResponse = @host_services_native.dispatch_list_directory,
) -> @host.HostServiceBridge {
  @host_services_desktop.DesktopHostServices::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
      menus=true,
      open_url=true,
      system_theme=true,
      settings=true,
    ),
    system_theme~,
    clipboard~,
    open_url~,
    file_dialog~,
    text_file~,
    binary_file~,
    settings~,
    show_menu=commands => {
      @host_services_desktop.menu_command_response(commands, menu(commands))
    },
    list_directory~,
  ).bridge()
}

///|
pub fn app_environment() -> @services.AppEnvironment {
  @window_host.app_environment(
    bridge=windows_service_bridge(),
    timer=Some(windows_timer_source()),
  )
}
