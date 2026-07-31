// Local helpers for data/: thin row/column/overlay wrappers over the
// shared @common implementations, plus the data-local empty_state.


fn[Msg] row(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = @style.MainAlign::Start,
  align? : @style.CrossAlign = @style.CrossAlign::Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=@core.Axis::Horizontal,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

///|
fn[Msg] column(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = @style.MainAlign::Start,
  align? : @style.CrossAlign = @style.CrossAlign::Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=@core.Axis::Vertical,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

///|
fn[Msg] overlay(
  base : @core.View[Msg],
  overlay : @core.View[Msg],
) -> @core.View[Msg] {
  @common.stack_layout(children=[base, overlay])
}

// === Empty state (simplified local version) ===

///|
fn[Msg] empty_state(
  title : String,
  message : String,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  @container.container(
    column(
      [
        @text.text(
          title,
          role=@style.TextRole::Control,
          theme~,
          width=280.0,
          height=28.0,
        ),
        @text.text(
          message,
          role=@style.TextRole::Caption,
          theme~,
          width=280.0,
          height=42.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@style.CrossAlign::Start,
    ),
    width=320.0,
    height=100.0,
    theme~,
    padding=16.0,
  ).semantics_role(@core.SemanticsRole::Group)
}
