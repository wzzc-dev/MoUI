///|
test "website initial render includes bilingual homepage sections" {
  let runtime = runtime(width=1180.0, height=760.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "MoUI"))
  assert_true(has_text(commands, "MoonBit GUI Framework"))
  assert_true(
    has_text(commands, "Typed, declarative UI for web and native hosts."),
  )
  assert_true(
    has_text(
      commands, "Model, Msg, update, view. One app surface, several render routes.",
    ),
  )
  assert_true(
    has_text(
      commands, "用 MoonBit 写一次应用逻辑，让 Web 与原生宿主共享同一套界面模型。",
    ),
  )
  assert_true(has_text(commands, "Source"))
  assert_true(has_text(commands, "Counter"))
  assert_true(has_text(commands, "Live Counter"))
  assert_true(has_text(commands, "Why use MoUI with MoonBit?"))
  assert_true(has_text(commands, "Built with MoUI"))
  assert_true(has_text(commands, "Markdown Editor"))
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "Quick Start / 快速开始"))
  assert_true(has_text(commands, "快速开始方式"))
  assert_true(has_text(commands, "正在开发中"))
  assert_false(has_text(commands, "Release Readiness / 发布准备"))
  assert_false(
    has_text(commands, "$ moon build website/web_wasm --target wasm-gc"),
  )
}

///|
test "website dark toggle updates visible state text" {
  let runtime = runtime(width=1180.0, height=760.0)
  assert_true(has_text(runtime.draw_commands(), "Dark / 深色"))
  click_text(runtime, "Dark / 深色")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Light / 浅色"))
}

///|
test "website hero CTA buttons open repository URL" {
  let opened_urls : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(open_url=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::OpenUrl(url) => {
          opened_urls.push(url)
          @host.HostServiceResponse::UrlOpened
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let runtime = Model::new().runtime_with_services(
    @host.HostAppServices::new(bridge~),
    width=1180.0,
    height=760.0,
  )
  click_text(runtime, "Get Started")
  click_text(runtime, "GitHub")
  inspect(opened_urls.length(), content="2")
  inspect(opened_urls[0], content="https://github.com/wzzc-dev/MoUI")
  inspect(opened_urls[1], content="https://github.com/wzzc-dev/MoUI")
}

///|
test "website hero code snippet is compact and visible" {
  let runtime = runtime(width=1180.0, height=760.0)
  click_first_text(runtime, "Source")
  let commands = runtime.draw_commands()
  assert_true(has_text_color_different(commands, "enum", "count"))
  assert_true(has_text_color_different(commands, "Msg", "count"))
  assert_true(has_text_color_different(commands, "button", "count"))
  assert_true(has_text_color_different(commands, "\"Reset\"", "count"))
  assert_true(has_text(commands, "15"))
}

///|
test "website hero switches between source and live counter" {
  let runtime = runtime(width=1180.0, height=760.0)
  assert_true(has_text(runtime.draw_commands(), "Live Counter"))
  assert_true(has_text(runtime.draw_commands(), "0"))
  click_text(runtime, "+")
  assert_true(has_text(runtime.draw_commands(), "1"))
  click_text(runtime, "Reset")
  assert_true(has_text(runtime.draw_commands(), "0"))
  click_first_text(runtime, "Source")
  let source = runtime.draw_commands()
  assert_true(has_text_color_different(source, "view", "count"))
  assert_true(has_text_color_different(source, "@core", "count"))
  assert_true(has_text_color_different(source, "View", "count"))
}

///|
test "website shows visible main scrollbar and moves thumb" {
  let size = @core.Size::new(width=1180.0, height=760.0)
  let initial = runtime(width=size.width, height=size.height).draw_commands()
  guard website_scrollbar_thumb_frame(initial, size) is Some(before) else {
    fail("expected visible website scrollbar thumb")
  }
  let scrolled = Model::new()
    .update(ScrollBodyTo(620.0))
    .runtime(width=size.width, height=size.height)
    .draw_commands()
  guard website_scrollbar_thumb_frame(scrolled, size) is Some(after) else {
    fail("expected moved website scrollbar thumb")
  }
  assert_true(after.origin.y > before.origin.y)
}

///|
test "website hero and product signal remain visible on desktop and compact sizes" {
  let desktop_size = @core.Size::new(width=1180.0, height=760.0)
  let desktop = runtime(width=desktop_size.width, height=desktop_size.height).draw_commands()
  assert_true(text_within(desktop, "MoUI", desktop_size))
  assert_true(text_within(desktop, "MoonBit GUI Framework", desktop_size))
  assert_true(
    text_within(
      desktop, "Typed, declarative UI for web and native hosts.", desktop_size,
    ),
  )
  assert_true(
    text_within(
      desktop, "Model, Msg, update, view. One app surface, several render routes.",
      desktop_size,
    ),
  )
  assert_true(text_within(desktop, "App surface", desktop_size))
  assert_true(text_within(desktop, "Live Counter", desktop_size))
  let compact_size = @core.Size::new(width=390.0, height=720.0)
  let compact = runtime(width=compact_size.width, height=compact_size.height).draw_commands()
  assert_true(text_within(compact, "MoUI", compact_size))
  assert_true(text_within(compact, "Live Counter", compact_size))
  assert_true(
    text_within(compact, "Typed UI for web and native hosts.", compact_size),
  )
  assert_true(text_within(compact, "App surface", compact_size))
}

///|
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard last_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame")
  }
  click_frame(runtime, frame)
}

///|
fn click_first_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @core.AppRuntime, frame : @core.Rect) -> Unit {
  let point = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn last_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  let mut result = None
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          result = Some(frame)
        }
      _ => ()
    }
  }
  result
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_color_different(
  commands : Array[@core.DrawCommand],
  highlighted : String,
  plain : String,
) -> Bool {
  let highlighted_colors : Array[@core.Color] = []
  let plain_colors : Array[@core.Color] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, color, .. }) =>
        if value == highlighted {
          highlighted_colors.push(color)
        } else if value == plain {
          plain_colors.push(color)
        }
      _ => ()
    }
  }
  for highlighted_color in highlighted_colors {
    for plain_color in plain_colors {
      if highlighted_color != plain_color {
        return true
      }
    }
  }
  false
}

///|
fn website_scrollbar_thumb_frame(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> @core.Rect? {
  let candidates : Array[@core.Rect] = []
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.origin.x > size.width - 18.0 &&
          rect.size.width <= 6.0 &&
          rect.size.height >= 36.0 {
          candidates.push(rect)
        }
      _ => ()
    }
  }
  if candidates.length() < 2 {
    None
  } else {
    Some(candidates[candidates.length() - 1])
  }
}

///|
fn text_within(
  commands : Array[@core.DrawCommand],
  text : String,
  size : @core.Size,
) -> Bool {
  guard text_frame(commands, text) is Some(frame) else { return false }
  frame.origin.x >= 0.0 &&
  frame.origin.y >= 0.0 &&
  frame.origin.x + frame.size.width <= size.width &&
  frame.origin.y + frame.size.height <= size.height
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
