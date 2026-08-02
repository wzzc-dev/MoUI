///|
/// Shared host-renderer bridge preflight fragment for the mobile skia
/// providers (android/ios/harmonyos). Replaces three identical private
/// copies; the fragment documents the `HostWindowRenderer` bridge surface.
pub fn skia_host_renderer_bridge_preflight_mobile() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
/// Shared host-renderer bridge preflight fragment for the desktop skia
/// providers (macos/linux/windows). Replaces three identical private
/// copies; the desktop fragment additionally names the async image loader.
pub fn skia_host_renderer_bridge_preflight_desktop() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_async_image_loader; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}
