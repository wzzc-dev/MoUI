///|
pub fn program(
  wallpaper_source? : String = "examples/mo_desktop/web_wasm/assets/tahoe-day.jpg",
) -> @moui.Program[DesktopModel, Msg] {
  @moui.Program::simple_with_environment(
    init=DesktopModel::new(wallpaper_source~),
    update~,
    view~,
  )
}
