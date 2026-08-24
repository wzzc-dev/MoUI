///|
fn ExcelApp::view(self : ExcelApp) -> @moui.View[ExcelMsg] {
  let model = self.model
  let theme = @views.light_theme()
  let shell = @views.column(
    [
      build_toolbar(model, theme),
      @views.divider(theme~),
      build_formula_bar(model, theme),
      @views.divider(theme~),
      build_grid(model, theme),
      @views.divider(theme~),
      build_sheet_tabs(model, theme),
      @views.divider(theme~),
      build_status_bar(model, theme),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  let base = @views.container(
    shell,
    width=shell_width,
    height=shell_height,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=0.0,
  )
  if model.context_menu_visible {
    @views.stack([
      base,
      @views.align(
        build_more_menu_overlay(theme),
        alignment=@geometry.Alignment::new(x=1.0, y=0.0),
      ),
    ])
  } else {
    base
  }
}
