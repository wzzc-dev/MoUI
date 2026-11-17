///|
pub fn scaffold_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::unavailable()
}

///|
pub fn scaffold_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor~ : Double = 1.0,
) -> @window_input.SurfaceState {
  @window_input.SurfaceState::new(
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=logical_width, height=logical_height),
      scale_factor~,
    ),
    owns_surface=false,
    can_reconfigure=false,
  )
}

///|
pub fn scaffold_input_host() -> @window_input.InputState {
  @window_input.InputState::new(
    focused=false,
    contract=@host.HostInputContract::new(
      capabilities=@host.HostInputCapabilities::none(),
      coordinates=@host.HostCoordinatePolicy::logical(
        description="Linux input is emitted by the Wayland backend; the scaffold host exposes a no-input contract for tests.",
      ),
    ),
  )
}

///|
pub fn linux_client_decorated_commands(
  commands : Array[@core.DrawCommand],
  title~ : String,
  metrics~ : @core.SurfaceMetrics,
  decorations~ : LinuxClientDecorationState,
) -> Array[@core.DrawCommand] {
  linux_client_decorated_commands_with_clear_color(
    commands,
    title~,
    metrics~,
    decorations~,
    clear_color=linux_first_clear_color(commands),
  )
}

///|
fn linux_client_decorated_commands_with_clear_color(
  commands : Array[@core.DrawCommand],
  title~ : String,
  metrics~ : @core.SurfaceMetrics,
  decorations~ : LinuxClientDecorationState,
  clear_color~ : @core.Color,
) -> Array[@core.DrawCommand] {
  if !decorations.active {
    commands
  } else {
    let titlebar = decorations.titlebar_height
    let width = metrics.logical_size.width
    let height = metrics.logical_size.height
    let output : Array[@core.DrawCommand] = []
    output.push(Clear(clear_color))
    output.push(
      FillRect(
        @core.Rect::new(x=0.0, y=0.0, width~, height=titlebar),
        linux_titlebar_background_color(),
      ),
    )
    output.push(
      StrokeRect(
        @core.Rect::new(x=0.0, y=titlebar - 1.0, width~, height=1.0),
        linux_titlebar_border_color(),
        1.0,
      ),
    )
    output.push(
      DrawText(
        @core.TextRun::new(
          text=title,
          frame=@core.Rect::new(
            x=14.0,
            y=5.0,
            width=(width - 150.0).max(24.0),
            height=22.0,
          ),
          font=@core.FontSpec::new(size=14.0, weight=700),
          color=linux_titlebar_text_color(),
          align=TextStart,
        ),
      ),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=2,
      color=linux_titlebar_minimize_color(),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=1,
      color=linux_titlebar_maximize_color(),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=0,
      color=linux_titlebar_close_color(),
    )
    let content_height = (height - titlebar).max(1.0)
    output.push(
      PushClip(
        @core.Rect::new(x=0.0, y=titlebar, width~, height=content_height),
      ),
    )
    output.push(
      PushTransform(@core.Transform2D::translation(dx=0.0, dy=titlebar)),
    )
    for command in commands {
      match command {
        Clear(_) => ()
        _ => output.push(command)
      }
    }
    output.push(PopTransform)
    output.push(PopClip)
    output
  }
}

///|
pub fn linux_surface_metrics_for_content(
  metrics : @core.SurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @core.SurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(
        width=metrics.logical_size.width,
        height=metrics.logical_size.height + logical_titlebar,
      ),
      physical_size=@core.Size::new(
        width=metrics.physical_size.width,
        height=metrics.physical_size.height + physical_titlebar,
      ),
      scale_factor=metrics.scale_factor,
    )
  }
}

///|
pub fn linux_content_metrics_for_surface(
  metrics : @core.SurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @core.SurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(
        width=metrics.logical_size.width,
        height=(metrics.logical_size.height - logical_titlebar).max(1.0),
      ),
      physical_size=@core.Size::new(
        width=metrics.physical_size.width,
        height=(metrics.physical_size.height - physical_titlebar).max(1.0),
      ),
      scale_factor=metrics.scale_factor,
    )
  }
}

///|
fn linux_request_surface_for_content(
  window : @window_linux.Window,
  metrics : @core.SurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> Unit {
  let surface_metrics = linux_surface_metrics_for_content(metrics, decorations)
  ignore(
    window.request_surface_size(
      @window_input.host_metrics_to_dpi_size(surface_metrics),
    ),
  )
}

///|
fn linux_window_surface_metrics(
  window : @window_linux.Window,
) -> @core.SurfaceMetrics {
  @window_input.surface_metrics_from_physical(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
}

///|
fn linux_first_clear_color(commands : Array[@core.DrawCommand]) -> @core.Color {
  let mut clear = @core.Color::white()
  let mut found = false
  for command in commands {
    if !found {
      match command {
        Clear(color) => {
          clear = color
          found = true
        }
        _ => ()
      }
    }
  }
  clear
}

///|
fn linux_titlebar_background_color() -> @core.Color {
  @core.Color::rgba(r=0.96, g=0.97, b=0.98)
}

///|
fn linux_titlebar_border_color() -> @core.Color {
  @core.Color::rgba(r=0.80, g=0.83, b=0.88)
}

///|
fn linux_titlebar_text_color() -> @core.Color {
  @core.Color::rgba(r=0.06, g=0.07, b=0.09)
}

///|
fn linux_titlebar_close_color() -> @core.Color {
  @core.Color::rgba(r=0.88, g=0.35, b=0.35)
}

///|
fn linux_titlebar_maximize_color() -> @core.Color {
  @core.Color::rgba(r=0.31, g=0.72, b=0.42)
}

///|
fn linux_titlebar_minimize_color() -> @core.Color {
  @core.Color::rgba(r=0.90, g=0.72, b=0.30)
}

///|
fn append_linux_titlebar_button(
  commands : Array[@core.DrawCommand],
  width~ : Double,
  index_from_right~ : Int32,
  color~ : @core.Color,
) -> Unit {
  let slot = linux_titlebar_button_slot_rect(width, index_from_right)
  let size = 12.0
  let left = slot.origin.x + (28.0 - size) / 2.0
  commands.push(
    FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=left, y=10.0, width=size, height=size),
        radius=6.0,
      ),
      color,
    ),
  )
}

///|
fn linux_client_decoration_state(
  window : @window_linux.Window,
) -> LinuxClientDecorationState {
  LinuxClientDecorationState::new(active=window.uses_client_decorations())
}

///|

///|
/// One of the client-side-decoration titlebar buttons.
#derive(Eq, Debug)
pub(all) enum LinuxTitlebarButton {
  Close
  Minimize
  Maximize
}

///|
pub extend LinuxTitlebarButton with Debug::{to_repr}

///|
pub extend LinuxTitlebarButton with Eq::{not_equal, equal}

///|
/// The slot rectangle of a titlebar button, in content-surface logical
/// coordinates.
///
/// Painting and hit testing must agree, so both read this: the visible dot is
/// centered in a 28pt slot, but the whole slot is clickable (an OS control that
/// only responds to the 12pt dot is a discoverability regression).
pub fn linux_titlebar_button_slot_rect(
  window_width : Double,
  index_from_right : Int32,
) -> @core.Rect {
  let slot_width = 28.0
  let gap = 8.0
  let left = window_width -
    gap -
    (index_from_right + 1).to_double() * slot_width -
    index_from_right.to_double() * gap
  @core.Rect::new(x=left, y=0.0, width=slot_width, height=32.0)
}

///|
/// Which titlebar button contains `point`, if any. Slots are ordered from the
/// right: close, maximize, minimize.
pub fn linux_titlebar_button_at(
  window_width : Double,
  point : @core.Point,
) -> LinuxTitlebarButton? {
  if point.y < 0.0 || point.y >= 32.0 {
    return None
  }
  let candidates : Array[(Int32, LinuxTitlebarButton)] = [
    (0, LinuxTitlebarButton::Close),
    (1, LinuxTitlebarButton::Minimize),
    (2, LinuxTitlebarButton::Maximize),
  ]
  for candidate in candidates {
    let (index, button) = candidate
    let slot = linux_titlebar_button_slot_rect(window_width, index)
    if point.x >= slot.origin.x && point.x < slot.origin.x + slot.size.width {
      return Some(button)
    }
  }
  None
}

///|
/// What a pointer event inside the client-side-decoration titlebar band should
/// do.
///
/// Before this existed the whole band silently dropped pointer and scroll
/// input, so the painted buttons looked live and did nothing (issue #24). The
/// band is window chrome the framework draws, therefore the framework owns its
/// hit testing: a button press becomes a window request, a body press starts a
/// native window drag, and scroll is swallowed instead of scrolling content
/// that is not under the pointer.
#derive(Eq, Debug)
pub(all) enum LinuxTitlebarAction {
  /// Not a titlebar event: deliver it to the app content (rebased).
  Pass
  /// Consumed by the chrome; nothing reaches the app.
  Consume
  /// Start a native window move gesture.
  Drag
  /// The press landed on a button; remember it for the matching release.
  Press(LinuxTitlebarButton)
  /// The release completed a button press; issue the window request.
  Activate(LinuxTitlebarButton)
}

///|
pub extend LinuxTitlebarAction with Debug::{to_repr}

///|
pub extend LinuxTitlebarAction with Eq::{not_equal, equal}

///|
/// Classify a pointer event against the CSD titlebar band.
///
/// `position` is in surface (window) coordinates, i.e. it still includes the
/// titlebar offset. `button` is the mouse button; only the primary button
/// drives chrome, everything else passes through rebased so apps can still use
/// the band for secondary clicks.
pub fn linux_titlebar_pointer_action(
  decorations : LinuxClientDecorationState,
  content_width : Double,
  position : @core.Point,
  phase : @core.PointerPhase,
  button : Int32,
  pressed_button : LinuxTitlebarButton?,
) -> LinuxTitlebarAction {
  if !decorations.active || position.y >= decorations.titlebar_height {
    return Pass
  }
  if button != 0 && phase != Exit {
    return Consume
  }
  match phase {
    Down =>
      match linux_titlebar_button_at(content_width, position) {
        Some(button) => Press(button)
        None => Drag
      }
    Up =>
      match
        (linux_titlebar_button_at(content_width, position), pressed_button) {
        (Some(hit), Some(pressed)) =>
          if hit == pressed {
            Activate(hit)
          } else {
            Consume
          }
        (None, Some(_)) => Consume
        _ => Consume
      }
    Move | Cancel | Exit => Consume
  }
}
