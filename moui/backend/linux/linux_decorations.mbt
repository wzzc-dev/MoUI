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
  policy~ : LinuxTitlebarPolicy = LinuxTitlebarPolicy::default(),
  hover~ : LinuxTitlebarButton? = None,
  pressed~ : LinuxTitlebarButton? = None,
  maximized~ : Bool = false,
) -> Array[@core.DrawCommand] {
  linux_client_decorated_commands_with_clear_color(
    commands,
    title~,
    metrics~,
    decorations~,
    clear_color=linux_first_clear_color(commands),
    policy~,
    hover~,
    pressed~,
    maximized~,
  )
}

///|
/// Resolve the visual state of one button from the tracked hover/press.
fn linux_titlebar_button_state(
  hover~ : LinuxTitlebarButton?,
  pressed~ : LinuxTitlebarButton?,
  button~ : LinuxTitlebarButton,
) -> LinuxTitlebarButtonState {
  if pressed is Some(pressed_button) && pressed_button == button {
    Pressed
  } else if hover is Some(hover_button) && hover_button == button {
    Hover
  } else {
    Idle
  }
}

///|
fn linux_client_decorated_commands_with_clear_color(
  commands : Array[@core.DrawCommand],
  title~ : String,
  metrics~ : @core.SurfaceMetrics,
  decorations~ : LinuxClientDecorationState,
  clear_color~ : @core.Color,
  policy~ : LinuxTitlebarPolicy = LinuxTitlebarPolicy::default(),
  hover~ : LinuxTitlebarButton? = None,
  pressed~ : LinuxTitlebarButton? = None,
  maximized~ : Bool = false,
) -> Array[@core.DrawCommand] {
  if !decorations.active {
    commands
  } else {
    let titlebar = decorations.titlebar_height
    let palette = linux_titlebar_palette(decorations.scheme)
    let width = metrics.logical_size.width
    let height = metrics.logical_size.height
    let output : Array[@core.DrawCommand] = []
    output.push(Clear(clear_color))
    output.push(
      FillRect(
        @core.Rect::new(x=0.0, y=0.0, width~, height=titlebar),
        palette.background,
      ),
    )
    output.push(
      StrokeRect(
        @core.Rect::new(x=0.0, y=titlebar - 1.0, width~, height=1.0),
        palette.border,
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
          color=palette.title,
          align=TextStart,
        ),
      ),
    )
    append_linux_titlebar_button(
      output,
      width~,
      titlebar_height=titlebar,
      index_from_right=2,
      button=Minimize,
      maximized~,
      state=linux_titlebar_button_state(hover~, pressed~, button=Minimize),
      policy~,
      palette~,
    )
    append_linux_titlebar_button(
      output,
      width~,
      titlebar_height=titlebar,
      index_from_right=1,
      button=Maximize,
      maximized~,
      state=linux_titlebar_button_state(hover~, pressed~, button=Maximize),
      policy~,
      palette~,
    )
    append_linux_titlebar_button(
      output,
      width~,
      titlebar_height=titlebar,
      index_from_right=0,
      button=Close,
      maximized~,
      state=linux_titlebar_button_state(hover~, pressed~, button=Close),
      policy~,
      palette~,
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

///|
/// Colors for the CSD titlebar, one palette per system color scheme.
pub(all) struct LinuxTitlebarPalette {
  background : @core.Color
  border : @core.Color
  title : @core.Color
  glyph : @core.Color
  close : @core.Color
  minimize : @core.Color
  maximize : @core.Color
  hover_ring : @core.Color
}

///|
fn linux_titlebar_palette(scheme : @core.ColorScheme) -> LinuxTitlebarPalette {
  match scheme {
    Dark =>
      {
        background: @core.Color::rgba(r=0.18, g=0.18, b=0.20),
        border: @core.Color::rgba(r=0.30, g=0.31, b=0.34),
        title: @core.Color::rgba(r=0.94, g=0.94, b=0.96),
        glyph: @core.Color::rgba(r=0.10, g=0.10, b=0.12),
        close: @core.Color::rgba(r=0.90, g=0.37, b=0.37),
        minimize: @core.Color::rgba(r=0.91, g=0.73, b=0.32),
        maximize: @core.Color::rgba(r=0.33, g=0.74, b=0.44),
        hover_ring: @core.Color::rgba(r=0.95, g=0.95, b=0.97),
      }
    Light =>
      {
        background: @core.Color::rgba(r=0.96, g=0.97, b=0.98),
        border: @core.Color::rgba(r=0.80, g=0.83, b=0.88),
        title: @core.Color::rgba(r=0.06, g=0.07, b=0.09),
        glyph: @core.Color::rgba(r=1.0, g=1.0, b=1.0),
        close: @core.Color::rgba(r=0.88, g=0.35, b=0.35),
        minimize: @core.Color::rgba(r=0.90, g=0.72, b=0.30),
        maximize: @core.Color::rgba(r=0.31, g=0.72, b=0.42),
        hover_ring: @core.Color::rgba(r=1.0, g=1.0, b=1.0),
      }
  }
}

///|
fn linux_titlebar_button_color(
  palette~ : LinuxTitlebarPalette,
  button~ : LinuxTitlebarButton,
) -> @core.Color {
  match button {
    Close => palette.close
    Minimize => palette.minimize
    Maximize => palette.maximize
  }
}

///|
/// Push the glyph of one titlebar button as vector commands.
///
/// `dot` is the glyph circle's rect; every glyph is drawn inside it from
/// strokes and fills, so the buttons follow the theme palette without any
/// bitmap assets. `maximized` switches the maximize button to its restore
/// glyph (overlapping squares), the Windows behavior app users expect.
fn append_linux_titlebar_glyph(
  commands : Array[@core.DrawCommand],
  dot~ : @core.Rect,
  button~ : LinuxTitlebarButton,
  maximized~ : Bool,
  palette~ : LinuxTitlebarPalette,
) -> Unit {
  let glyph = @core.Color::rgba(
    r=palette.glyph.r,
    g=palette.glyph.g,
    b=palette.glyph.b,
    a=0.9,
  )
  let brush = @core.Brush::Solid(glyph)
  let stroke = 1.6
  let inset = 3.2
  let cx = dot.origin.x + dot.size.width / 2.0
  let cy = dot.origin.y + dot.size.height / 2.0
  match button {
    Minimize => {
      let bar_width = dot.size.width - inset * 2.0
      commands.push(
        FillRect(
          @core.Rect::new(
            x=dot.origin.x + inset,
            y=cy - 0.8,
            width=bar_width,
            height=1.6,
          ),
          glyph,
        ),
      )
    }
    Maximize =>
      if maximized {
        // Restore: two overlapping square outlines.
        let side = dot.size.width - inset * 2.0 - 2.0
        let offset = 2.4
        let back_x = cx - side / 2.0 + offset
        let back_y = cy - side / 2.0 - offset
        commands.push(
          StrokeRect(
            @core.Rect::new(x=back_x, y=back_y, width=side, height=side),
            glyph,
            stroke,
          ),
        )
        let front_x = cx - side / 2.0 - offset / 2.0
        let front_y = cy - side / 2.0 + offset / 2.0
        commands.push(
          StrokeRect(
            @core.Rect::new(x=front_x, y=front_y, width=side, height=side),
            glyph,
            stroke,
          ),
        )
      } else {
        let side = dot.size.width - inset * 2.0
        commands.push(
          StrokeRect(
            @core.Rect::new(
              x=cx - side / 2.0,
              y=cy - side / 2.0,
              width=side,
              height=side,
            ),
            glyph,
            stroke,
          ),
        )
      }
    Close => {
      let arm = dot.size.width / 2.0 - inset
      commands.push(
        DrawPath(
          @core.PathSpec::new(
            verbs=[
              MoveTo(@core.Point::new(x=cx - arm, y=cy - arm)),
              LineTo(@core.Point::new(x=cx + arm, y=cy + arm)),
              MoveTo(@core.Point::new(x=cx + arm, y=cy - arm)),
              LineTo(@core.Point::new(x=cx - arm, y=cy + arm)),
            ],
            stroke=Some(brush),
            stroke_width=stroke,
          ),
        ),
      )
    }
  }
}

///|
/// Paint one titlebar button: the colored dot plus its glyph, with hover and
/// pressed feedback drawn from the palette.
fn append_linux_titlebar_button(
  commands : Array[@core.DrawCommand],
  width~ : Double,
  titlebar_height~ : Double,
  index_from_right~ : Int32,
  button~ : LinuxTitlebarButton,
  maximized~ : Bool,
  state~ : LinuxTitlebarButtonState,
  policy~ : LinuxTitlebarPolicy,
  palette~ : LinuxTitlebarPalette,
) -> Unit {
  let slot = linux_titlebar_button_slot_rect(
    width,
    titlebar_height,
    index_from_right,
    policy~,
  )
  let dot_size = policy.dot_size
  let dot = @core.Rect::new(
    x=slot.origin.x + (slot.size.width - dot_size) / 2.0,
    y=(titlebar_height - dot_size) / 2.0,
    width=dot_size,
    height=dot_size,
  )
  let color = linux_titlebar_button_color(palette~, button~)
  let dot = match state {
    // Pressed dots shrink slightly toward the pointer's press point.
    Pressed =>
      @core.Rect::new(
        x=dot.origin.x + 1.0,
        y=dot.origin.y + 1.0,
        width=dot_size - 2.0,
        height=dot_size - 2.0,
      )
    _ => dot
  }
  let drawn_size = dot.size.width
  let drawn_radius = drawn_size / 2.0
  commands.push(
    FillRoundedRect(
      @core.RoundedRect::new(rect=dot, radius=drawn_radius),
      @core.Color::rgba(r=color.r, g=color.g, b=color.b, a=1.0),
    ),
  )
  if state is Hover {
    commands.push(
      StrokeRoundedRect(
        @core.RoundedRect::new(
          rect=@core.Rect::new(
            x=dot.origin.x - 1.5,
            y=dot.origin.y - 1.5,
            width=drawn_size + 3.0,
            height=drawn_size + 3.0,
          ),
          radius=drawn_radius + 1.5,
        ),
        palette.hover_ring,
        1.2,
      ),
    )
  }
  append_linux_titlebar_glyph(commands, dot~, button~, maximized~, palette~)
}

///|
fn linux_client_decoration_state(
  window : @window_linux.Window,
  scheme~ : @core.ColorScheme = @core.ColorScheme::Light,
) -> LinuxClientDecorationState {
  LinuxClientDecorationState::new(
    active=window.uses_client_decorations(),
    scheme~,
  )
}

///|

///|
/// Layout metrics and placement for the CSD titlebar buttons.
///
/// Pure data on purpose: painting, hit testing, and the insets API all derive
/// from one policy instance, so the visible buttons and the clickable area can
/// never drift apart (issue #24).
pub(all) struct LinuxTitlebarPolicy {
  /// Clickable square per button; the whole slot reacts, not just the dot.
  slot_size : Double
  /// Space between adjacent slots.
  gap : Double
  /// Space between the right window edge and the first slot.
  edge_margin : Double
  /// Glyph circle diameter inside the slot.
  dot_size : Double
}

///|
pub fn LinuxTitlebarPolicy::default() -> LinuxTitlebarPolicy {
  { slot_size: 28.0, gap: 8.0, edge_margin: 8.0, dot_size: 12.0, }
}

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
/// Visual state of one titlebar button, driven by pointer tracking.
#derive(Eq, Debug)
pub(all) enum LinuxTitlebarButtonState {
  Idle
  Hover
  Pressed
}

///|
pub extend LinuxTitlebarButtonState with Debug::{to_repr}

///|
pub extend LinuxTitlebarButtonState with Eq::{not_equal, equal}

///|
/// The slot rectangle of a titlebar button, in content-surface logical
/// coordinates.
///
/// Painting and hit testing must agree, so both read this: the visible dot is
/// centered in a policy-sized slot, but the whole slot is clickable (an OS
/// control that only responds to the glyph is a discoverability regression).
pub fn linux_titlebar_button_slot_rect(
  window_width : Double,
  titlebar_height : Double,
  index_from_right : Int32,
  policy~ : LinuxTitlebarPolicy = LinuxTitlebarPolicy::default(),
) -> @core.Rect {
  let left = window_width -
    policy.edge_margin -
    (index_from_right + 1).to_double() * policy.slot_size -
    index_from_right.to_double() * policy.gap
  @core.Rect::new(x=left, y=0.0, width=policy.slot_size, height=titlebar_height)
}

///|
/// Which titlebar button contains `point`, if any. Slots are ordered from the
/// right: close, maximize, minimize.
pub fn linux_titlebar_button_at(
  window_width : Double,
  titlebar_height : Double,
  point : @core.Point,
  policy~ : LinuxTitlebarPolicy = LinuxTitlebarPolicy::default(),
) -> LinuxTitlebarButton? {
  if point.y < 0.0 || point.y >= titlebar_height {
    return None
  }
  let candidates : Array[(Int32, LinuxTitlebarButton)] = [
    (0, LinuxTitlebarButton::Close),
    (1, LinuxTitlebarButton::Maximize),
    (2, LinuxTitlebarButton::Minimize),
  ]
  for candidate in candidates {
    let (index, button) = candidate
    let slot = linux_titlebar_button_slot_rect(
      window_width,
      titlebar_height,
      index,
      policy~,
    )
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
      match
        linux_titlebar_button_at(
          content_width,
          decorations.titlebar_height,
          position,
        ) {
        Some(button) => Press(button)
        None => Drag
      }
    Up =>
      match
        (
          linux_titlebar_button_at(
            content_width,
            decorations.titlebar_height,
            position,
          ),
          pressed_button,
        ) {
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
