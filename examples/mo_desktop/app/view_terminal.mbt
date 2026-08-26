// Mo Terminal: a playful fake shell. Commands run against the desktop model
// (help/apps/date/echo/open …) so the terminal can actually drive apps while
// staying a typed TEA component.

///|
fn terminal_body(
  model : DesktopModel,
  metrics : WindowMetrics,
  _palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let body_height = metrics.height - 40.0
  let input_height = 46.0
  // Terminal surface: near-black plate with green phosphor text, independent
  // of the desktop palette so it reads like a real console in both modes.
  let surface = rgba8(16, 20, 26)
  let text_color = rgba8(158, 226, 158)
  let visible = if model.terminal_lines.length() > 12 {
    model.terminal_lines.length() - 12
  } else {
    0
  }
  let rows : Array[@moui.View[Msg]] = []
  for index, line in model.terminal_lines {
    if index >= visible {
      rows.push(
        @views.text(
          line,
          role=@views.TextRole::Caption,
          width=metrics.width - 32.0,
          height=22.0,
        )
        .font(@text.FontSpec::new(size=12.0, weight=430))
        .foreground(
          if line.has_prefix("mo> ") {
            @graphics.Color::white()
          } else if line.has_prefix("Launching") {
            rgba8(122, 200, 255)
          } else if line.has_suffix("command not found") ||
            line.has_prefix("open: unknown app") {
            rgba8(255, 150, 140)
          } else {
            text_color
          },
        ),
      )
    }
  }
  let transcript = @views.column(
      rows,
      spacing=2.0,
      align=@views.CrossAlign::Start,
    )
    .frame(width=metrics.width - 24.0, height=body_height - input_height - 16.0)
    .clip()
  let input_row = @views.row(
    [
      @views.text("mo>", role=@views.TextRole::Caption, width=28.0, height=30.0)
      .font(@text.FontSpec::new(size=12.5, weight=600))
      .foreground(text_color),
      @views.text_field(
        model.terminal_input,
        on_input=value => TerminalInputChanged(value),
        on_submit=Some(RunTerminalCommand),
        placeholder="type help",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=metrics.width - 220.0,
        height=32.0,
      ).accessibility_label("Terminal command input"),
      @views.button(
        "Run",
        on_click=RunTerminalCommand,
        variant=@views.ButtonVariant::Tonal,
        theme~,
        width=72.0,
        height=30.0,
      ),
      @views.button(
        "Clear",
        on_click=ClearTerminal,
        icon=Some(@views.IconName::Close),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=76.0,
        height=30.0,
      ),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  ).frame(width=metrics.width - 24.0, height=input_height)
  let shell = @views.container(
    @views.padding_edges(transcript, left=12.0, right=12.0, top=8.0, bottom=8.0),
    width=metrics.width,
    height=body_height - input_height,
    background=surface,
    corner_radius=0.0,
    padding=0.0,
  )
  @views.column([shell, input_row], spacing=6.0, align=@views.CrossAlign::Start)
}
