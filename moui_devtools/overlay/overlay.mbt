///|
pub fn snapshot_overlay(
  snapshot : @runtime.InspectorSnapshot,
  theme? : @core.Theme = @views.default_theme(),
  max_lines? : Int = 12,
) -> @core.View[Unit] {
  let lines = @devtools.inspector_report_text(snapshot)
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let views : Array[@core.View[Unit]] = []
  let count = if max_lines < lines.length() {
    max_lines.max(1)
  } else {
    lines.length()
  }
  for index in 0..<count {
    views.push(
      @views.text(
        lines[index],
        role=if index == 0 { Body } else { Caption },
        theme~,
        width=720.0,
        height=22.0,
      ),
    )
  }
  @views.padding(
    @views.column(views, spacing=2.0).frame(
      width=744.0,
      height=count.to_double() * 24.0,
    ),
    12.0,
  )
}

///|
/// Compact Agent Inspector overlay used by reference applications and manual
/// presentation smokes. The full report remains available as JSON for CI.
pub fn agent_inspector_overlay(
  report : @devtools.AgentInspectorReport,
  theme? : @core.Theme = @views.default_theme(),
  max_lines? : Int = 10,
) -> @core.View[Unit] {
  let lines = @devtools.agent_inspector_report_text(report)
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let count = if max_lines < lines.length() {
    max_lines.max(1)
  } else {
    lines.length()
  }
  let views : Array[@core.View[Unit]] = []
  for index in 0..<count {
    views.push(
      @views.text(
        lines[index],
        role=if index == 0 { Body } else { Caption },
        theme~,
        width=720.0,
        height=22.0,
      ),
    )
  }
  @views.padding(
    @views.column(views, spacing=2.0).frame(
      width=744.0,
      height=count.to_double() * 24.0,
    ),
    12.0,
  )
}

///|
/// Render one of the eight Inspector workspaces without coupling the overlay
/// to a particular window or transport.
pub fn agent_inspector_workspace_overlay(
  report : @devtools.AgentInspectorReport,
  workspace : @devtools.AgentInspectorWorkspace,
  theme? : @core.Theme = @views.default_theme(),
) -> @core.View[Unit] {
  @views.padding(
    @views.text(
      @devtools.agent_inspector_workspace_text(report, workspace),
      role=@views.TextRole::Body,
      theme~,
      width=744.0,
      height=30.0,
    ),
    12.0,
  )
}
