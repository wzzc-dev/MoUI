///|
test "website initial render includes bilingual homepage sections" {
  let runtime = test_program_runtime(width=1180.0, height=760.0)
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
  assert_true(
    has_text(commands, "git clone git@github.com:moui-mbt/moui_example.git"),
  )
  assert_false(has_text(commands, "Release Readiness / 发布准备"))
  assert_false(
    has_text(commands, "$ moon build website/web_wasm --target wasm-gc"),
  )
}

///|
test "website theme toggle updates visible icon" {
  let runtime = test_program_runtime(width=1180.0, height=760.0)
  assert_true(has_text(runtime.draw_commands(), "☾"))
  click_text(runtime, "☾")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "☀"))
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
  let runtime = Model::new().test_runtime_with_services(
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
test "website showcases page renders all screenshot assets" {
  let commands = Model::new()
    .update(OpenShowcases)
    .test_runtime(width=1180.0, height=1800.0)
    .draw_commands()
  let showcase_titles = [
    "Showcase", "iOS Component Gallery", "HarmonyOS Component Gallery", "Markdown Editor",
    "Mo Workbench", "Excel Viewer", "WebView Demo", "Android Component Gallery",
  ]
  for title in showcase_titles {
    assert_true(has_text(commands, title))
  }
  let screenshot_sources = [
    "assets/screenshots/showcase.png", "assets/screenshots/ios-componentgallery.png",
    "assets/screenshots/harmonyos-componentgallery.png", "assets/screenshots/markdown_editor.png",
    "assets/screenshots/mo_workbench.png", "assets/screenshots/excel.png", "assets/screenshots/webview.png",
    "assets/screenshots/android-componentgallery.jpg",
  ]
  for source in screenshot_sources {
    assert_true(has_image_source(commands, source))
  }
}

///|
test "website docs portal loads runtime markdown through host text service" {
  let requested_paths : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => {
          requested_paths.push(path)
          @host.HostServiceResponse::TextFileContent(
            path, "# Runtime Docs\n\nMoUI fetches **Markdown** at runtime.\n\n- One source file\n\n```moonbit\nfn main {}\n```",
          )
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let runtime = Model::new().test_runtime_with_services(
    @host.HostAppServices::new(bridge~),
    width=1180.0,
    height=760.0,
  )
  click_text(runtime, "Docs")
  let commands = runtime.draw_commands()
  inspect(requested_paths.length(), content="1")
  inspect(requested_paths[0], content="docs/moui-readme.md")
  assert_true(has_text(commands, "MoUI Markdown Docs"))
  assert_true(has_text(commands, "Runtime Docs"))
  assert_true(has_text(commands, "MoUI fetches Markdown at runtime."))
  assert_true(has_text(commands, "fn main {}"))
  assert_true(
    has_text_align(commands, "MoUI Markdown Docs", @core.TextAlign::TextStart),
  )
  assert_true(
    has_text_align(commands, "Runtime Docs", @core.TextAlign::TextStart),
  )
  assert_true(
    has_text_align(
      commands,
      "MoUI fetches Markdown at runtime.",
      @core.TextAlign::TextStart,
    ),
  )
  assert_true(
    has_text_align(commands, "fn main {}", @core.TextAlign::TextStart),
  )
  click_text(runtime, "Development")
  inspect(requested_paths.length(), content="2")
  inspect(requested_paths[1], content="docs/development.md")
}

///|
test "website docs completion ignores stale request id for selected markdown" {
  let path = "docs/architecture.md"
  let current_id = @host.HostServiceRequestId::new(2)
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    selected_doc_slug: "architecture",
    doc_state: DocLoading(current_id, path),
  }
  let stale : @host.HostCompletedServiceResponse = {
    id: @host.HostServiceRequestId::new(1),
    request: @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path),
    ),
    response: @host.HostServiceResponse::TextFileContent(
      path, "# Stale\n\nOld response",
    ),
  }
  let unchanged = model.update(HostDocsCompleted(stale))
  match unchanged.doc_state {
    DocLoading(id, loading_path) => {
      inspect(id.value, content="2")
      inspect(loading_path, content="docs/architecture.md")
    }
    _ => fail("expected stale completion to keep current loading state")
  }
  let fresh : @host.HostCompletedServiceResponse = {
    id: current_id,
    request: @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path),
    ),
    response: @host.HostServiceResponse::TextFileContent(
      path, "# Fresh\n\nLatest response",
    ),
  }
  match unchanged.update(HostDocsCompleted(fresh)).doc_state {
    DocLoaded(loaded_path, document) => {
      inspect(loaded_path, content="docs/architecture.md")
      inspect(document.title, content="Fresh")
    }
    _ => fail("expected current completion to load markdown")
  }
}

///|
test "website hero code snippet is compact and visible" {
  let runtime = test_program_runtime(width=1180.0, height=760.0)
  let commands = runtime.draw_commands()
  assert_true(has_text_color_different(commands, "enum", "count"))
  assert_true(has_text_color_different(commands, "Msg", "count"))
  assert_true(has_text_color_different(commands, "button", "count"))
  assert_true(has_text_color_different(commands, "\"Reset\"", "count"))
  assert_true(has_text(commands, "15"))
  guard text_frame(commands, "01") is Some(first_line) else {
    fail("expected first source line")
  }
  guard text_frame(commands, "15") is Some(last_line) else {
    fail("expected last source line")
  }
  assert_true(last_line.origin.y > first_line.origin.y + 185.0)
}

///|
test "website hero shows source and live counter side by side" {
  let runtime = test_program_runtime(width=1180.0, height=760.0)
  let initial = runtime.draw_commands()
  guard text_frame(initial, "Source") is Some(source_title) else {
    fail("expected source title")
  }
  guard text_frame(initial, "Counter") is Some(counter_title) else {
    fail("expected counter title")
  }
  assert_true(source_title.origin.x < counter_title.origin.x)
  assert_true(source_title.origin.y <= counter_title.origin.y + 1.0)
  assert_true(counter_title.origin.y <= source_title.origin.y + 1.0)
  assert_true(has_text(initial, "Live Counter"))
  assert_true(has_text(initial, "0"))
  click_text(runtime, "+")
  let incremented = runtime.draw_commands()
  assert_true(has_text(incremented, "1"))
  assert_true(has_text_color_different(incremented, "view", "count"))
  assert_true(has_text_color_different(incremented, "@moui", "count"))
  assert_true(has_text_color_different(incremented, "View", "count"))
  click_text(runtime, "Reset")
  assert_true(has_text(runtime.draw_commands(), "0"))
}

///|
test "website shows visible main scrollbar and moves thumb" {
  let size = @geometry.Size::new(width=1180.0, height=760.0)
  let initial = test_program_runtime(width=size.width, height=size.height).draw_commands()
  guard website_scrollbar_thumb_frame(initial, size) is Some(before) else {
    fail("expected visible website scrollbar thumb")
  }
  let scrolled = Model::new()
    .update(ScrollBodyTo(620.0))
    .test_runtime(width=size.width, height=size.height)
    .draw_commands()
  guard website_scrollbar_thumb_frame(scrolled, size) is Some(after) else {
    fail("expected moved website scrollbar thumb")
  }
  assert_true(after.origin.y > before.origin.y)
}

///|
test "website positive wheel delta scrolls body downward" {
  let size = @geometry.Size::new(width=1180.0, height=760.0)
  let runtime = test_program_runtime(width=size.width, height=size.height)
  guard website_scrollbar_thumb_frame(runtime.draw_commands(), size)
    is Some(before) else {
    fail("expected visible website scrollbar thumb")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=size.width / 2.0, y=120.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=180.0),
      ),
    ),
  )
  guard website_scrollbar_thumb_frame(runtime.draw_commands(), size)
    is Some(after) else {
    fail("expected moved website scrollbar thumb")
  }
  assert_true(after.origin.y > before.origin.y)
}

///|
test "website feature cards stack supporting copy below the header row" {
  let commands = test_program_runtime(width=1180.0, height=760.0).draw_commands()
  assert_feature_card_stacked(
    commands, "Predictable", "Model, Msg, update, view.", "Typed messages drive one explicit update path.",
  )
  assert_feature_card_stacked(
    commands, "Strict Types", "Opaque View[Msg] public API.", "No stringly UI protocol or Any sprawl.",
  )
  assert_feature_card_stacked(
    commands, "Modular Hosts", "Shared app, thin entrypoints.", "Web and native hosts reuse the same model.",
  )
  assert_feature_card_stacked(
    commands, "Renderer Neutral", "WGPU, Skia, WebGPU.", "Renderer capability stays out of app logic.",
  )
}

///|
test "website platform card summaries render as separate lines" {
  let commands = test_program_runtime(width=1180.0, height=760.0).draw_commands()
  assert_true(has_text(commands, "This page: shared app logic"))
  assert_true(has_text(commands, "in website/app and a thin"))
  assert_true(has_text(commands, "Web entrypoint."))
  assert_true(has_text(commands, "Layout, input, drawing,"))
  assert_true(has_text(commands, "renderer reporting, and"))
  assert_true(has_text(commands, "platform smoke paths."))
  assert_true(has_text(commands, "Source and visual editing"))
  assert_true(has_text(commands, "share one typed Markdown"))
  assert_true(has_text(commands, "application model."))
  assert_true(has_text(commands, "Native Skia dogfood surface"))
  assert_true(has_text(commands, "for workflow, evidence, and"))
  assert_true(has_text(commands, "session state."))
  assert_false(
    has_text(
      commands, "Source and visual editing share one typed Markdown application model.",
    ),
  )
}

///|
test "website hero and product signal remain visible on desktop and compact sizes" {
  let desktop_size = @geometry.Size::new(width=1180.0, height=760.0)
  let desktop = test_program_runtime(
    width=desktop_size.width,
    height=desktop_size.height,
  ).draw_commands()
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
  let compact_size = @geometry.Size::new(width=390.0, height=720.0)
  let compact = test_program_runtime(
    width=compact_size.width,
    height=compact_size.height,
  ).draw_commands()
  assert_true(text_within(compact, "MoUI", compact_size))
  assert_true(text_within(compact, "Live Counter", compact_size))
  assert_true(
    text_within(compact, "Typed UI for web and native hosts.", compact_size),
  )
  assert_true(text_within(compact, "App surface", compact_size))
}

///|
fn assert_feature_card_stacked(
  commands : Array[@core.DrawCommand],
  title_text : String,
  zh_summary_text : String,
  summary_text : String,
) -> Unit raise {
  guard text_frame(commands, title_text) is Some(title) else {
    fail("expected feature card title")
  }
  guard text_frame(commands, zh_summary_text) is Some(zh_summary) else {
    fail("expected feature card supporting copy")
  }
  guard text_frame(commands, summary_text) is Some(summary) else {
    fail("expected feature card secondary copy")
  }
  assert_true(zh_summary.origin.y > title.origin.y + 24.0)
  assert_true(summary.origin.y > zh_summary.origin.y)
  assert_true(zh_summary.origin.x < title.origin.x)
  assert_true(summary.origin.x >= zh_summary.origin.x - 1.0)
  assert_true(summary.origin.x <= zh_summary.origin.x + 1.0)
  assert_true(summary.size.width > title.size.width)
}

///|
fn Model::test_runtime(
  self : Model,
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  test_runtime(self.program(), width~, height~)
}

///|
fn Model::test_runtime_with_services(
  self : Model,
  services : @host.HostAppServices,
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  test_runtime(self.program_with_services(services), width~, height~)
}

///|
fn test_program_runtime(
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  test_runtime(program(), width~, height~)
}

///|
fn test_runtime(
  program : @moui.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard last_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @runtime.AppRuntime, frame : @core.Rect) -> Unit {
  let point = @geometry.Point::new(
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
fn has_image_source(
  commands : Array[@core.DrawCommand],
  source : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawImage({ source: value, .. }) &&
    value == source
  })
}

///|
fn has_text_align(
  commands : Array[@core.DrawCommand],
  text : String,
  align : @core.TextAlign,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::DrawText({ text: value, align: actual_align, .. }) &&
    value == text &&
    actual_align == align
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
  size : @geometry.Size,
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
  size : @geometry.Size,
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
