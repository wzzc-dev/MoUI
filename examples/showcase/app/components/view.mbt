///|
using @views {
  badge,
  button,
  card,
  checkbox,
  choice_item,
  column,
  container,
  picker,
  picker_item,
  progress_status,
  responsive_grid,
  row,
  scroll_view,
  spacer,
  stat_card,
  status_badge,
  segmented_control,
  text,
  text_field,
}

///|
/// Hosted body for the unified Showcase shell (no local chrome).
pub fn view_body(
  model : ComponentGalleryModel,
  env : @moui.ViewEnvironment,
  width? : Double = 0.0,
) -> @moui.View[ComponentGalleryMsg] {
  let theme = @views.light_theme()
  let viewport = env.viewport_size()
  let page_width = if width > 0.0 {
    width
  } else {
    responsive_page_width(model.active_platform, viewport.width)
  }
  let compact = page_width < 820.0
  component_body(model, model.active_item, theme, page_width, compact)
}

///|
/// Standalone package program uses a minimal full-page wrapper for tests.
pub fn view(
  model : ComponentGalleryModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[ComponentGalleryMsg] {
  let theme = @views.light_theme()
  let viewport = env.viewport_size()
  let page_width = responsive_page_width(model.active_platform, viewport.width)
  let page_height = viewport.height.max(1.0)
  container(
    scroll_view(
      view_body(model, env, width=page_width),
      width=page_width,
      height=page_height,
      state=Some(model.content_scroll),
    ),
    width=page_width,
    height=page_height,
    background=theme.palette.background,
    padding=16.0,
    theme~,
  )
}

///|
fn responsive_page_width(
  platform : PlatformId,
  viewport_width : Double,
) -> Double {
  match platform {
    PlatformId::Android | PlatformId::IOS | PlatformId::HarmonyOS =>
      viewport_width.max(320.0)
    _ => viewport_width.max(360.0).min(1180.0)
  }
}
