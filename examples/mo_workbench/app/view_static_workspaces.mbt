// Placeholder surfaces for the Work / Design tabs. These are UI shells only;
// their backend workflows are not wired yet. They render a centered headline
// so the three-tab shell is fully navigable while the real surfaces mature.

///|
/// Centered headline block used by the placeholder tab surfaces.
fn tab_placeholder_surface(
  title : String,
  subtitle : String,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        workspace_headline(title, subtitle, theme, (width - 96.0).max(280.0)),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
      justify=@views.MainAlign::Center,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=48.0,
  )
}

///|
/// Work tab placeholder: a task board will live here once the board layout +
/// backend are ready.
fn work_tab_placeholder_view(
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  tab_placeholder_surface(
    "Work",
    "任务看板即将推出 · 此处将展示任务进度与编排视图",
    theme,
    width,
    height,
  )
}

///|
/// Design tab placeholder: a component / preview gallery will live here once
/// the design surface is ready.
fn design_tab_placeholder_view(
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  tab_placeholder_surface(
    "Design",
    "设计预览即将推出 · 此处将展示组件预览与设计稿",
    theme,
    width,
    height,
  )
}

///|
/// A title + subtitle headline block, reused by the placeholder surfaces and
/// any future tab content.
fn workspace_headline(
  title : String,
  subtitle : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      @views.text(title, role=@views.TextRole::Title, theme~, width~),
      @views.text(subtitle, role=@views.TextRole::Caption, theme~, width~).foreground(
        theme.palette.muted,
      ),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Center,
  )
}
