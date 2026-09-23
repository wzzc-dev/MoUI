// Local helpers for data/: package-local layout pieces not shared
// with other view sub-packages (row/column live in @style).

///|

// === Empty state (simplified local version) ===

///|
fn[Msg] empty_state(
  title : String,
  message : String,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  @container.container(
    @layout.column(
      [
        @text.text(title, role=Control, theme~, width=280.0, height=28.0),
        @text.text(message, role=Caption, theme~, width=280.0, height=42.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=Start,
    ),
    width=320.0,
    height=100.0,
    theme~,
    padding=16.0,
  ).semantics_role(Group)
}
