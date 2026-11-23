///|
/// White-box coverage for the focus ring's `:focus-visible` switch: a focused
/// element only paints its primary ring while the host says the keyboard owns
/// the interaction, and the ring slot stays allocated so the child never jumps.

///|
fn focus_ring_draw(view : @core.View[Unit]) -> Array[@core.DrawCommand] {
  let program : @core.Program[Int32, Unit] = @core.Program::new_with_environment(
    init=() => (0, @core.Effect::none()),
    update=(current, _) => (current, @core.Effect::none()),
    view=(_, _) => view,
  )
  @runtime.new_program_with_dimensions(program~, width=200.0, height=120.0).draw_commands()
}

///|
fn focus_ring_has_lit_ring(
  commands : Array[@core.DrawCommand],
  color : @core.Color,
) -> Bool {
  for command in commands {
    let hit = match command {
      @core.DrawCommand::StrokeRoundedRect(_, stroke, _) => stroke == color
      @core.DrawCommand::StrokeRoundedRectBrush(
        _,
        @core.Brush::Solid(stroke),
        _,
      ) => stroke == color
      @core.DrawCommand::StrokeRect(_, stroke, _) => stroke == color
      _ => false
    }
    if hit {
      return true
    }
  }
  false
}

///|
test "focus ring lights only when focus is visible" {
  let theme = @common.views_ambient_theme(None)
  let child : @core.View[Unit] = @container.empty()
  let keyboard = focus_ring(child, focused=true, theme~)
  assert_true(
    focus_ring_has_lit_ring(focus_ring_draw(keyboard), theme.palette.primary),
    msg="keyboard focus paints the primary ring",
  )
  // Pointer focus: still focused, but the halo must not follow the cursor.
  let pointer = focus_ring(child, focused=true, theme~, focus_visible=false)
  assert_false(
    focus_ring_has_lit_ring(focus_ring_draw(pointer), theme.palette.primary),
    msg="pointer focus leaves no lit ring",
  )
  // Unfocused keeps the faint outline affordance in both modalities.
  let idle = focus_ring(child, focused=false, theme~)
  assert_false(
    focus_ring_has_lit_ring(focus_ring_draw(idle), theme.palette.primary),
    msg="idle ring is the faint outline, not the primary one",
  )
}

///|
test "ring slot only changes width between modalities" {
  let theme = @common.views_ambient_theme(None)
  let child : @core.View[Unit] = @container.empty()
  let lit = focus_ring(child, focused=true, theme~)
  let hidden = focus_ring(child, focused=true, theme~, focus_visible=false)
  // The lit ring is the 2pt primary stroke; hiding it leaves the same 1pt slot
  // the idle state uses, so the child's box stays put when modality flips.
  assert_true(
    focus_ring_stroke_widths(focus_ring_draw(lit)).contains(2.0),
    msg="lit ring is 2pt",
  )
  assert_true(
    focus_ring_stroke_widths(focus_ring_draw(hidden)).contains(1.0),
    msg="hidden ring keeps the 1pt slot",
  )
  assert_false(
    focus_ring_stroke_widths(focus_ring_draw(hidden)).contains(2.0),
    msg="hidden ring is never 2pt",
  )
}

///|
fn focus_ring_stroke_widths(
  commands : Array[@core.DrawCommand],
) -> Array[Double] {
  let widths : Array[Double] = []
  for command in commands {
    match command {
      @core.DrawCommand::StrokeRoundedRect(_, _, width) => widths.push(width)
      @core.DrawCommand::StrokeRoundedRectBrush(_, _, width) =>
        widths.push(width)
      @core.DrawCommand::StrokeRect(_, _, width) => widths.push(width)
      _ => ()
    }
  }
  widths
}
