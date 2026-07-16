///|
pub fn program(
  active_platform~ : PlatformId,
  session_runtime? : SessionRuntimeInfo,
  active_item? : ComponentGalleryItemId = ComponentGalleryItemId::Welcome,
) -> @moui.Program[ComponentGalleryModel, ComponentGalleryMsg] {
  @moui.Program::simple_with_environment(
    init=ComponentGalleryModel::new(
      active_platform~,
      session_runtime?,
      active_item~,
    ),
    update~,
    view~,
    subscriptions~,
  )
}
