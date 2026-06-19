///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_containing(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(text)
  })
}

///|
fn has_image_fit(
  commands : Array[@core.DrawCommand],
  fit : @core.ImageFit,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawImage({ fit: image_fit, .. }) &&
    image_fit == fit
  })
}

///|
fn text_within(
  commands : Array[@core.DrawCommand],
  text : String,
  size : @moui.Size,
) -> Bool {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text &&
          frame.origin.x >= 0.0 &&
          frame.origin.y >= 0.0 &&
          frame.origin.x + frame.size.width <= size.width &&
          frame.origin.y + frame.size.height <= size.height {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn text_color(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Color? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, color, .. }) =>
        if value == text {
          return Some(color)
        }
      _ => ()
    }
  }
  None
}

///|
fn has_text_color(
  commands : Array[@core.DrawCommand],
  text : String,
  color : @core.Color,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::DrawText({ text: value, color: text_color, .. }) &&
    value == text &&
    text_color == color
  })
}

///|
fn @app.ShowcaseModel::runtime(
  self : @app.ShowcaseModel,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program=self.program(), width~, height~)
}

///|
fn @app.ShowcaseModel::runtime_with_route_host(
  self : @app.ShowcaseModel,
  route_host : @app.ShowcaseRouteHost,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=self.program_with_route_host(route_host),
    width~,
    height~,
  )
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_last_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard last_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @runtime.AppRuntime, frame : @core.Rect) -> Unit {
  let position = @moui.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  click_point(runtime, position)
}

///|
fn host_click_frame(
  driver : @host.HostRuntimeDriver,
  frame : @core.Rect,
) -> Unit {
  let position = @moui.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    ignore(
      driver.dispatch(
        @host.HostEvent::Pointer(@core.PointerEvent::new(position~, phase~)),
      ),
    )
  }
}

///|
fn click_point(runtime : @runtime.AppRuntime, position : @moui.Point) -> Unit {
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    runtime.dispatch_event(
      @core.AppEvent::Pointer(@core.PointerEvent::new(position~, phase~)),
    )
  }
}

///|
/// Drive the host redraw loop until in-flight animations settle (no further
/// redraw requested). Button hover/press transitions keep requesting frames
/// for a few ticks; this drains them so a test can assert a stable state.
fn settle_redraw(driver : @host.HostRuntimeDriver) -> Unit {
  // Button transitions use the theme's fast_ms (120ms) at 16ms/frame, so ~8
  // frames suffice; cap at 32 to avoid an infinite loop if a control never
  // stops reporting `animating`. Each iteration advances the clock by one
  // frame, forces a paint (so `active_animations` is recomputed), and checks
  // whether the runtime still wants another frame.
  let mut frames = 0
  while frames < 32 {
    driver.begin_redraw()
    ignore(driver.draw_commands())
    driver.finish_redraw()
    let result = driver.event_result()
    if !result.needs_redraw && !result.redraw_requested {
      return
    }
    frames = frames + 1
  }
}

///|
fn last_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  let mut frame : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame: next, .. }) =>
        if value == text {
          frame = Some(next)
        }
      _ => ()
    }
  }
  frame
}

///|
fn smallest_rounded_brush_containing(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
) -> @core.Rect? {
  let mut candidate : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect_contains_rect(rect, frame) {
          candidate = match candidate {
            Some(existing) =>
              if rect_area(rect) < rect_area(existing) {
                Some(rect)
              } else {
                Some(existing)
              }
            None => Some(rect)
          }
        }
      _ => ()
    }
  }
  candidate
}

///|
fn rect_contains_rect(container : @core.Rect, child : @core.Rect) -> Bool {
  child.origin.x >= container.origin.x &&
  child.origin.y >= container.origin.y &&
  child.origin.x + child.size.width <= container.origin.x + container.size.width &&
  child.origin.y + child.size.height <=
  container.origin.y + container.size.height
}

///|
fn rect_area(rect : @core.Rect) -> Double {
  rect.size.width * rect.size.height
}

///|
fn rects_overlap(a : @core.Rect, b : @core.Rect) -> Bool {
  let a_right = a.origin.x + a.size.width
  let b_right = b.origin.x + b.size.width
  let a_bottom = a.origin.y + a.size.height
  let b_bottom = b.origin.y + b.size.height
  a.origin.x < b_right &&
  a_right > b.origin.x &&
  a.origin.y < b_bottom &&
  a_bottom > b.origin.y
}

///|
fn layout_tile_marker_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRect({ rect, radius }, _) =>
        if rect.size.width == 4.0 && rect.size.height == 22.0 && radius == 2.0 {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn has_sidebar_scrollbar(commands : Array[@core.DrawCommand]) -> Bool {
  sidebar_scrollbar_frame(commands) is Some(_)
}

///|
fn sidebar_scrollbar_frame(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width == 4.0 && rect.size.height >= 32.0 {
          return Some(rect)
        }
      _ => ()
    }
  }
  None
}

///|
