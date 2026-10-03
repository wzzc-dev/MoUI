///|
pub using @common {view_declaration, view_exact_channel, type PaintContext}

///|
/// Pure drawing view with no child layout.
/// Corresponds to Flutter `CustomPainter` and SwiftUI `Canvas`.
///
/// The `measure` callback determines the view size.
/// The `draw` callback receives a `PaintContext` and the allocated frame rect.
/// Users call `@views.fill_rounded_rect(ctx, ...)`, `@views.push_clip(ctx, ...)`,
/// etc. instead of constructing `DrawCommand` variants directly.
///
/// The `Canvas` carries only the immutable `measure` and `draw` closures
/// (plus an optional semantics label). It is the dedicated concrete node for
/// this callback-driven API; ordinary built-in controls use their own named
/// `ViewNode` implementations rather than going through `canvas`.
priv struct Canvas {
  measure : (@core.Constraints) -> @core.Size // declaration-exempt: consumed only by the Uncacheable layout channel
  draw : (PaintContext, @core.Rect) -> Unit // declaration-exempt: consumed only by the Uncacheable paint channel
  semantics_label : String
}

///|
impl @core.ViewNode for Canvas with fn identity(_self) {
  @core.ViewIdentity::new(kind="Canvas")
}

///|
impl @core.ViewNode for Canvas with fn declaration(self) {
  view_declaration(
    layout=Uncacheable,
    paint=Uncacheable,
    semantics=view_exact_channel(
      @core.DeclarationKey::string(self.semantics_label),
    ),
  )
}

///|
impl @core.ViewNode for Canvas with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=(self.measure)(ctx.constraints))
}

///|
impl @core.ViewNode for Canvas with fn paint(self, ctx) {
  let pctx = PaintContext::new()
  (self.draw)(pctx, ctx.frame)
  @core.ViewPaintPlan::commands(PaintContext::finish(pctx))
}

///|
impl @core.ViewNode for Canvas with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=if self.semantics_label == "" { Transparent } else { Boundary },
    role=Group,
    label=self.semantics_label,
    value=self.semantics_label,
  )
}

///|
/// Like `canvas`, but the draw callback also receives the runtime paint clock
/// (`now_ms`) and the paint plan is marked animating so the host keeps
/// requesting frames. Use this for looping motion that should not depend on a
/// app-facing `TimerSource` subscription.
///
/// `draw` args: paint context, allocated frame, `now_ms` (0.0 until the first
/// `FrameTick` arrives).
priv struct AnimatedCanvas {
  measure : (@core.Constraints) -> @core.Size // declaration-exempt: consumed only by the Uncacheable layout channel
  draw : (PaintContext, @core.Rect, Double) -> Unit // declaration-exempt: consumed only by the Uncacheable paint channel
  semantics_label : String
}

///|
impl @core.ViewNode for AnimatedCanvas with fn identity(_self) {
  @core.ViewIdentity::new(kind="AnimatedCanvas")
}

///|
impl @core.ViewNode for AnimatedCanvas with fn declaration(self) {
  view_declaration(
    layout=Uncacheable,
    paint=Uncacheable,
    semantics=view_exact_channel(
      @core.DeclarationKey::string(self.semantics_label),
    ),
  )
}

///|
impl @core.ViewNode for AnimatedCanvas with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=(self.measure)(ctx.constraints))
}

///|
impl @core.ViewNode for AnimatedCanvas with fn paint(self, ctx) {
  let pctx = PaintContext::new()
  (self.draw)(pctx, ctx.frame, ctx.now_ms)
  // Always report animating so the first paint bootstraps the redraw loop
  // even while `now_ms` is still 0.0 (clock starts on FrameTick).
  @core.ViewPaintPlan::animating_commands(PaintContext::finish(pctx))
}

///|
impl @core.ViewNode for AnimatedCanvas with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=if self.semantics_label == "" { Transparent } else { Boundary },
    role=Group,
    label=self.semantics_label,
    value=self.semantics_label,
  )
}

///|
pub fn[Msg] canvas(
  measure~ : (@core.Constraints) -> @core.Size,
  draw~ : (PaintContext, @core.Rect) -> Unit,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::from_node(Canvas::{ measure, draw, semantics_label, })
}

///|
/// Canvas variant whose `measure` also receives the **layout context**, so the
/// callback can reach `ctx.text_system` and measure text.
///
/// Why this exists: a canvas that must place things *inside a text run* — the
/// MoUI Studio blocks editor draws reporter slots (rounded holes) between the
/// literal segments of a block label — cannot do it with the plain `canvas`,
/// whose `measure` only sees `Constraints`. The text system lives on
/// `ViewLayoutContext`, and `PaintContext` (the draw callback's argument)
/// deliberately carries only draw commands, so measurement is impossible at
/// paint time. Measuring in layout and stashing the result is the supported
/// path (the same one built-in controls like `button` use).
///
/// The view is otherwise identical: same node kind, same uncacheable channels.
pub fn[Msg] measured_canvas(
  measure~ : (@core.Constraints, @core.TextSystem) -> @core.Size,
  draw~ : (PaintContext, @core.Rect) -> Unit,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::from_node(
    MeasuredCanvas::{ measure, draw, semantics_label, },
  )
}

///|
/// See `measured_canvas`: the only difference from `Canvas` is that `measure`
/// additionally receives the layout context's text system.
priv struct MeasuredCanvas {
  measure : (@core.Constraints, @core.TextSystem) -> @core.Size // declaration-exempt: consumed only by the Uncacheable layout channel
  draw : (PaintContext, @core.Rect) -> Unit // declaration-exempt: consumed only by the Uncacheable paint channel
  semantics_label : String
}

///|
impl @core.ViewNode for MeasuredCanvas with fn identity(_self) {
  @core.ViewIdentity::new(kind="MeasuredCanvas")
}

///|
impl @core.ViewNode for MeasuredCanvas with fn declaration(self) {
  view_declaration(
    layout=Uncacheable,
    paint=Uncacheable,
    semantics=view_exact_channel(
      @core.DeclarationKey::string(self.semantics_label),
    ),
  )
}

///|
impl @core.ViewNode for MeasuredCanvas with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=(self.measure)(ctx.constraints, ctx.text_system),
  )
}

///|
impl @core.ViewNode for MeasuredCanvas with fn paint(self, ctx) {
  let pctx = PaintContext::new()
  (self.draw)(pctx, ctx.frame)
  @core.ViewPaintPlan::commands(PaintContext::finish(pctx))
}

///|
pub fn[Msg] animated_canvas(
  measure~ : (@core.Constraints) -> @core.Size,
  draw~ : (PaintContext, @core.Rect, Double) -> Unit,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::from_node(AnimatedCanvas::{ measure, draw, semantics_label, })
}
