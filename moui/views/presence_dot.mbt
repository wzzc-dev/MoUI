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
/// A small status dot (Fluent 2 PresenceBadge) used to indicate availability.
/// Renders as a filled circle in the status color with a contrasting border so
/// it stays legible when overlaid on an avatar. Overlay it on an avatar with
/// `avatar(...).overlay(alignment=BottomRight, presence_dot(...))`.
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
  let total = size + border_width * 2.0
  custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width=total, height=total))
    },
    paint=(ctx, frame) => {
      let dot_rect = @core.Rect::new(
        x=frame.origin.x + (frame.size.width - size) / 2.0,
        y=frame.origin.y + (frame.size.height - size) / 2.0,
        width=size,
        height=size,
      )
      let dot = @core.RoundedRect::new(rect=dot_rect, radius=size / 2.0)
      let border_rect = @core.Rect::new(
        x=dot_rect.origin.x - border_width,
        y=dot_rect.origin.y - border_width,
        width=size + border_width * 2.0,
        height=size + border_width * 2.0,
      )
      let border = @core.RoundedRect::new(
        rect=border_rect,
        radius=(size + border_width * 2.0) / 2.0,
      )
      // Border ring first so the dot sits on top.
      fill_rounded_rect(ctx, border, @core.Brush::solid(border_color))
      fill_rounded_rect(ctx, dot, @core.Brush::solid(status_color))
    },
  ).semantics_role(@core.SemanticsRole::Group)
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
