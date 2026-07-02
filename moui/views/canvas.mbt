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
