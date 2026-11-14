///|
fn ExcelApp::view(self : ExcelApp) -> @moui.View[ExcelMsg] {
  let model = self.model
  let theme = @views.desktop_light_theme()
  let shell = @views.column(
    [
      build_toolbar(model, theme),
      @views.divider(),
      build_formula_bar(model, theme),
      @views.divider(),
      build_grid(model, theme),
      @views.divider(),
      build_sheet_tabs(model),
      @views.divider(),
      build_status_bar(model, theme),
    ],
    spacing=0.0,
    align=Stretch,
  )
  let base = @views.container(
    shell,
    width=shell_width,
    height=shell_height,
    variant=Base,
    padding=0.0,
  )
  let root = if model.context_menu_visible {
    @views.stack([
      base,
      @views.align(
        build_more_menu_overlay(),
        alignment=@geometry.Alignment::new(x=1.0, y=0.0),
      ),
    ])
  } else {
    base
  }
  root.theme(theme)
}
