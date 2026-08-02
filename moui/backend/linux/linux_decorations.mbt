///|
pub fn scaffold_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::unavailable()
}

///|
pub fn scaffold_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.SurfaceHostState {
  @host.SurfaceHostState::new(
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=logical_width, height=logical_height),
      scale_factor~,
    ),
    owns_surface=false,
    can_reconfigure=false,
  )
}

///|
pub fn scaffold_input_host() -> @host.InputHostState {
  @host.InputHostState::new(
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
  metrics~ : @host.HostSurfaceMetrics,
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
  metrics~ : @host.HostSurfaceMetrics,
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
    output.push(@core.DrawCommand::Clear(clear_color))
    output.push(
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width~, height=titlebar),
        linux_titlebar_background_color(),
      ),
    )
    output.push(
      @core.DrawCommand::StrokeRect(
        @core.Rect::new(x=0.0, y=titlebar - 1.0, width~, height=1.0),
        linux_titlebar_border_color(),
        1.0,
      ),
    )
    output.push(
      @core.DrawCommand::DrawText(
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
          align=@core.TextAlign::TextStart,
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
      @core.DrawCommand::PushClip(
        @core.Rect::new(x=0.0, y=titlebar, width~, height=content_height),
      ),
    )
    output.push(
      @core.DrawCommand::PushTransform(
        @core.Transform2D::translation(dx=0.0, dy=titlebar),
      ),
    )
    for command in commands {
      match command {
        @core.DrawCommand::Clear(_) => ()
        _ => output.push(command)
      }
    }
    output.push(@core.DrawCommand::PopTransform)
    output.push(@core.DrawCommand::PopClip)
    output
  }
}

///|
pub fn linux_surface_metrics_for_content(
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @host.HostSurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @host.HostSurfaceMetrics::new(
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
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @host.HostSurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @host.HostSurfaceMetrics::new(
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
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> Unit {
  let surface_metrics = linux_surface_metrics_for_content(metrics, decorations)
  ignore(
    window.request_surface_size(@host.host_metrics_to_dpi_size(surface_metrics)),
  )
}

///|
fn linux_window_surface_metrics(
  window : @window_linux.Window,
) -> @host.HostSurfaceMetrics {
  @host.surface_metrics_from_physical(
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
        @core.DrawCommand::Clear(color) => {
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
  index_from_right~ : Int,
  color~ : @core.Color,
) -> Unit {
  let slot = 28.0
  let gap = 8.0
  let size = 12.0
  let left = width -
    gap -
    (index_from_right + 1).to_double() * slot -
    index_from_right.to_double() * gap +
    (slot - size) / 2.0
  commands.push(
    @core.DrawCommand::FillRoundedRect(
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
