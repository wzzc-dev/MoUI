///|
/// Pure drawing view with no child layout.
/// Corresponds to Flutter `CustomPainter` and SwiftUI `Canvas`.
///
/// The `measure` callback determines the view size.
/// The `draw` callback receives a `PaintContext` and the allocated frame rect.
/// Users call `@views.fill_rounded_rect(ctx, ...)`, `@views.push_clip(ctx, ...)`,
/// etc. instead of constructing `DrawCommand` variants directly.
pub fn[Msg] canvas(
  measure~ : (@core.Constraints) -> @core.Size,
  draw~ : (PaintContext, @core.Rect) -> Unit,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  custom_control(
    measure=ctx => @core.ViewLayoutResult::new(size=measure(ctx.constraints)),
    paint=ctx => {
      let pctx = PaintContext::new()
      draw(pctx, ctx.frame)
      @core.ViewPaintPlan::commands(PaintContext::finish(pctx))
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Group,
        label=semantics_label,
        value=semantics_label,
      )
    },
  )
}

///|
/// Like `canvas`, but the draw callback also receives the runtime paint clock
/// (`now_ms`) and the paint plan is marked animating so the host keeps
/// requesting frames. Use this for looping motion that should not depend on a
/// `HostTimerSource` subscription.
///
/// `draw` args: paint context, allocated frame, `now_ms` (0.0 until the first
/// `FrameTick` arrives).
pub fn[Msg] animated_canvas(
  measure~ : (@core.Constraints) -> @core.Size,
  draw~ : (PaintContext, @core.Rect, Double) -> Unit,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  custom_control(
    kind="AnimatedCanvas",
    measure=ctx => @core.ViewLayoutResult::new(size=measure(ctx.constraints)),
    paint=ctx => {
      let pctx = PaintContext::new()
      draw(pctx, ctx.frame, ctx.now_ms)
      // Always report animating so the first paint bootstraps the redraw loop
      // even while `now_ms` is still 0.0 (clock starts on FrameTick).
      @core.ViewPaintPlan::animating_commands(PaintContext::finish(pctx))
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Group,
        label=semantics_label,
        value=semantics_label,
      )
    },
  )
}
