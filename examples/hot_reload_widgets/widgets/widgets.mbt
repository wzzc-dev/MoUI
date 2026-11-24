///|
/// Shared label owned by a module outside the probe app. The hot smoke edits
/// this literal to prove the watcher rebuilds on imported-package changes.
pub fn shared_badge_text() -> String {
  "shared alpha"
}

///|
/// A widget with its own paint plan: a shadow, a rounded clip, a fill and the
/// runtime animation clock. It exercises the shadow/clip/brush side of the hot
/// frame bridge without pulling in platform code.
pub struct StatusCard {
  ticks : Int32
}

///|
impl @core.ViewNode for StatusCard with fn identity(self) {
  @core.ViewIdentity::new(
    kind="HotReloadStatusCard",
    key=Some(self.ticks.to_string()),
  )
}

///|
impl @core.ViewNode for StatusCard with fn layout(self, context) {
  ignore(self)
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=220.0, height=48.0),
    ),
  )
}

///|
impl @core.ViewNode for StatusCard with fn paint(self, context) {
  ignore(self)
  let frame = context.frame
  let rounded = @core.RoundedRect::new(rect=frame, radius=10.0)
  let font = @core.FontSpec::new(size=12.0)
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=rounded,
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.22),
        offset=@core.Point::new(x=0.0, y=3.0),
        blur_radius=8.0,
        spread=0.0,
      ),
    ),
    @core.DrawCommand::PushRoundedClip(rounded),
    @core.DrawCommand::FillRoundedRect(
      rounded,
      @core.Color::rgba(r=0.96, g=0.97, b=1.0),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="clock \{context.now_ms.to_int64()}",
        frame=@core.Rect::new(
          x=frame.origin.x + 12.0,
          y=frame.origin.y + 14.0,
          width=frame.size.width - 24.0,
          height=20.0,
        ),
        font~,
        color=@core.Color::rgba(r=0.15, g=0.17, b=0.3),
      ),
    ),
    @core.DrawCommand::PopRoundedClip,
  ]
  @core.ViewPaintPlan::animating_commands(commands)
}

///|
pub fn[Msg] status_card(ticks : Int32) -> @moui.View[Msg] {
  @core.View::from_node(StatusCard::{ ticks, })
}
