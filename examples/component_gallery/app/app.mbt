///|
pub fn program(
  active_platform~ : PlatformId,
  session_runtime? : SessionRuntimeInfo,
) -> @moui.Program[ComponentGalleryModel, ComponentGalleryMsg] {
  @moui.Program::simple_with_environment(
    init=ComponentGalleryModel::new(active_platform~, session_runtime?),
    update~,
    view~,
  )
}
