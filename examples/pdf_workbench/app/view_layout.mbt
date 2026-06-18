///|
using @views {column, expanded, row, container}

///|
fn PdfWorkbenchModel::view_with_environment(
  self : PdfWorkbenchModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[PdfWorkbenchMsg] {
  self.view_for_viewport(env.viewport_size())
}

///|
fn PdfWorkbenchModel::view_for_viewport(
  self : PdfWorkbenchModel,
  viewport : @moui.Size,
) -> @moui.View[PdfWorkbenchMsg] {
  let theme = @views.light_theme()
  let metrics = pdf_workbench_layout_metrics(
    viewport,
    theme,
    reader_fullscreen=self.reader_fullscreen,
  )
  if self.reader_fullscreen {
    return container(
      pdf_workbench_page_surface(self, metrics, theme),
      width=metrics.viewport.width,
      height=metrics.viewport.height,
      variant=@views.ContainerVariant::Base,
      theme~,
      padding=theme.spacing_scale.sm,
    )
  }
  let header = pdf_workbench_toolbar(self, theme)
  let body_columns : Array[@moui.View[PdfWorkbenchMsg]] = []
  if metrics.sidebar_visible {
    body_columns.push(pdf_workbench_sidebar(self, metrics, theme))
  }
  body_columns.push(expanded(pdf_workbench_page_surface(self, metrics, theme)))
  if metrics.inspector_visible {
    body_columns.push(pdf_workbench_inspector(self, metrics, theme))
  }
  let body = row(
    body_columns,
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Start,
  )
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = [header]
  match self.status {
    Failed(_) => rows.push(pdf_workbench_failure_banner(self, metrics, theme))
    _ => ()
  }
  rows.push(body)
  rows.push(pdf_workbench_status(self, metrics, theme))
  container(
    column(
      rows,
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
priv struct PdfWorkbenchLayoutMetrics {
  viewport : @moui.Size
  inner_width : Double
  body_height : Double
  sidebar_visible : Bool
  sidebar_width : Double
  sidebar_scroll_width : Double
  page_width : Double
  preview_width : Double
  preview_height : Double
  inspector_visible : Bool
  inspector_width : Double
  inspector_scroll_width : Double
  reader_fullscreen : Bool
}

///|
fn pdf_workbench_layout_metrics(
  viewport : @moui.Size,
  theme : @moui.Theme,
  reader_fullscreen? : Bool = false,
) -> PdfWorkbenchLayoutMetrics {
  let safe_width = viewport.width.max(640.0)
  let safe_height = viewport.height.max(520.0)
  let root_padding = if reader_fullscreen {
    theme.spacing_scale.sm
  } else {
    theme.spacing_scale.lg
  }
  let spacing = theme.spacing_scale.md
  let inner_width = (safe_width - root_padding * 2.0).max(560.0)
  let inner_height = (safe_height - root_padding * 2.0).max(460.0)
  let toolbar_height = 58.0
  let status_height = 40.0
  let body_height = if reader_fullscreen {
    inner_height.max(320.0)
  } else {
    (inner_height - toolbar_height - status_height - spacing * 2.0).max(320.0)
  }
  let sidebar_visible = !reader_fullscreen && inner_width >= 860.0
  let inspector_visible = !reader_fullscreen && inner_width >= 1040.0
  let sidebar_width = if !sidebar_visible {
    0.0
  } else if inner_width >= 1500.0 {
    260.0
  } else if inner_width >= 1180.0 {
    236.0
  } else {
    212.0
  }
  let inspector_width = if !inspector_visible {
    0.0
  } else if inner_width >= 1500.0 {
    286.0
  } else if inner_width >= 1180.0 {
    260.0
  } else {
    232.0
  }
  let visible_side_columns = (if sidebar_visible { 1 } else { 0 }) +
    (if inspector_visible { 1 } else { 0 })
  let page_width = (inner_width -
  sidebar_width -
  inspector_width -
  spacing * visible_side_columns.to_double()).max(360.0)
  let panel_padding = theme.spacing_scale.md
  let compact_panel_padding = theme.spacing_scale.sm
  {
    viewport: @moui.Size::new(width=safe_width, height=safe_height),
    inner_width,
    body_height,
    sidebar_visible,
    sidebar_width,
    sidebar_scroll_width: (sidebar_width - compact_panel_padding * 2.0).max(
      160.0,
    ),
    page_width,
    preview_width: (page_width - panel_padding * 2.0).max(300.0),
    preview_height: (body_height - panel_padding * 2.0 - 42.0).max(260.0),
    inspector_visible,
    inspector_width,
    inspector_scroll_width: (inspector_width - compact_panel_padding * 2.0).max(
      180.0,
    ),
    reader_fullscreen,
  }
}

///|
fn pdf_workbench_panel_item_width(
  scroll_width : Double,
  theme : @moui.Theme,
) -> Double {
  (scroll_width - theme.spacing_scale.md).max(140.0)
}

///|
fn pdf_workbench_panel_scroll_height(
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> Double {
  (metrics.body_height - theme.spacing_scale.sm * 2.0).max(260.0)
}
