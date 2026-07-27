///|
/// Presence indicator status. Maps to Fluent 2 `PresenceBadge` statuses:
/// Available (green), Away (yellow), Busy (red), Offline (gray).
pub(all) enum PresenceStatus {
  Available
  Away
  Busy
  Offline
  Unknown
} derive(Eq, Debug, ToJson)

///|
pub fn PresenceStatus::label(self : PresenceStatus) -> String {
  match self {
    Available => "available"
    Away => "away"
    Busy => "busy"
    Offline => "offline"
    Unknown => "unknown"
  }
}

///|
/// Concrete view node for the `presence_dot` control.
///
/// A small status dot (Fluent 2 PresenceBadge) used to indicate availability.
/// Renders as a filled circle in the status color with a contrasting border so
/// it stays legible when overlaid on an avatar. Overlay it on an avatar with
/// `avatar(...).overlay(alignment=BottomRight, presence_dot(...))`.
///
/// The node carries only immutable declaration data: dot size, status color,
/// border color, and border width.
priv struct PresenceDot {
  size : Double
  status_color : @core.Color
  border_color : @core.Color
  border_width : Double
}

///|
impl @core.ViewNode for PresenceDot with fn identity(_self) {
  @core.ViewIdentity::new(kind="PresenceDot")
}

///|
impl @core.ViewNode for PresenceDot with fn declaration(self) {
  view_declaration(
    layout=view_exact_channel(
      view_record_key("PresenceDot.layout", [
        ("size", @core.DeclarationKey::double(self.size)),
        ("border_width", @core.DeclarationKey::double(self.border_width)),
      ]),
    ),
    paint=view_exact_channel(
      view_record_key("PresenceDot.paint", [
        ("size", @core.DeclarationKey::double(self.size)),
        ("status_color", view_color_key(self.status_color)),
        ("border_color", view_color_key(self.border_color)),
        ("border_width", @core.DeclarationKey::double(self.border_width)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for PresenceDot with fn layout(self, ctx) {
  let total = self.size + self.border_width * 2.0
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=total, height=total)),
  )
}

///|
impl @core.ViewNode for PresenceDot with fn paint(self, ctx) {
  let frame = ctx.frame
  let dot_rect = @core.Rect::new(
    x=frame.origin.x + (frame.size.width - self.size) / 2.0,
    y=frame.origin.y + (frame.size.height - self.size) / 2.0,
    width=self.size,
    height=self.size,
  )
  let dot = @core.RoundedRect::new(rect=dot_rect, radius=self.size / 2.0)
  let border_rect = @core.Rect::new(
    x=dot_rect.origin.x - self.border_width,
    y=dot_rect.origin.y - self.border_width,
    width=self.size + self.border_width * 2.0,
    height=self.size + self.border_width * 2.0,
  )
  let border = @core.RoundedRect::new(
    rect=border_rect,
    radius=(self.size + self.border_width * 2.0) / 2.0,
  )
  // Border ring first so the dot sits on top.
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::FillRoundedRectBrush(
      border,
      @core.Brush::solid(self.border_color),
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      dot,
      @core.Brush::solid(self.status_color),
    ),
  ])
}

///|
impl @core.ViewNode for PresenceDot with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Group,
    label="PresenceDot",
  )
}

///|
pub fn[Msg] presence_dot(
  status : PresenceStatus,
  size? : Double = 10.0,
  theme? : @core.Theme,
  on_surface? : @core.Color,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let status_color = presence_status_color(status, resolved_theme)
  // The border separates the dot from the host surface (avatar background).
  let border_color = on_surface.unwrap_or(resolved_theme.palette.background)
  let border_width = max_view_double(1.5, size * 0.15)
  @core.View::from_node(PresenceDot::{
    size,
    status_color,
    border_color,
    border_width,
  })
}

///|
fn presence_status_color(
  status : PresenceStatus,
  theme : @core.Theme,
) -> @core.Color {
  match status {
    Available => theme.palette.success
    Away => theme.palette.warning
    Busy => theme.palette.danger
    Offline => theme.palette.muted
    Unknown => theme.palette.muted
  }
}
