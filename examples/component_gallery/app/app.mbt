///|
pub fn program(
  active_platform~ : PlatformId,
) -> @moui.Program[ComponentGalleryModel, ComponentGalleryMsg] {
  @moui.Program::simple_with_environment(
    init=ComponentGalleryModel::new(active_platform~),
    update~,
    view~,
  )
}
