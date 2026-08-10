///|
test "website initial render includes localized English homepage sections" {
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
      commands, "Write application logic once in MoonBit and share one UI model across Web and native hosts.",
    ),
  )
  assert_true(has_text(commands, "Source"))
  assert_true(has_text(commands, "Counter"))
  assert_true(has_text(commands, "Live Counter"))
  assert_true(has_text(commands, "Why use MoUI with MoonBit?"))
  assert_true(has_text(commands, "Built with MoUI"))
  assert_true(has_text(commands, "Markdown Editor"))
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "Quick Start"))
  assert_true(has_text(commands, "From zero to a running app in three steps."))
  assert_true(has_text(commands, "Install the CLI"))
  assert_true(has_text(commands, "Create the app"))
  assert_true(has_text(commands, "Run on the host"))
  assert_true(has_text(commands, "moon install wzzc-dev/moui_cli/cmd/moui"))
  assert_true(has_text(commands, "moui new my_app"))
  assert_true(has_text(commands, "cd my_app"))
  assert_true(has_text(commands, "moon update"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "moon run macos_skia --target native"))
  assert_true(has_text(commands, "Read the Docs"))
  assert_true(has_text(commands, "Open Playground"))
  assert_false(
    has_text(commands, "git clone git@github.com:moui-mbt/moui_example.git"),
  )
  assert_false(has_text(commands, "Release Readiness / 发布准备"))
  assert_false(
    has_text(commands, "$ moon build website/web_wasm --target wasm-gc"),
  )
}

///|
test "website renders Simplified Chinese from environment locale" {
  let environment = @moui.Environment::neutral().with_locale("zh-Hans")
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1180.0,
    height=760.0,
    environment~,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "MoonBit GUI 框架"))
  assert_true(has_text(commands, "强类型声明式 UI"))
  assert_true(has_text(commands, "快速开始"))
  assert_true(has_text(commands, "阅读文档"))
}

///|
test "website selects Simplified Chinese route and catalog" {
  let requested_paths : Array[String] = []
  let applied_locales : Array[String] = []
  let pushed_routes : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => {
          requested_paths.push(path)
          @host.HostServiceResponse::TextFileContent(
            path,
            website_test_catalog().to_json().stringify(),
          )
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let route_host = WebsiteRouteHost::new(
    route_source=@services.RouteSource::new(),
    apply_locale=locale => applied_locales.push(locale),
    push_route=route => pushed_routes.push(route),
  )
  let runtime = test_runtime(
    Model::new().program_with_services(
      @backend_common_services.app_services(bridge~),
      route_host=Some(route_host),
    ),
    width=1180.0,
    height=760.0,
  )
  click_text(runtime, "中")
  inspect(requested_paths.last().unwrap(), content="docs/zh-Hans/catalog.json")
  inspect(applied_locales.last().unwrap(), content="zh-Hans")
  inspect(pushed_routes.last().unwrap(), content="home?lang=zh-Hans")
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
test "website Get Started navigates and GitHub opens repository URL" {
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
    @backend_common_services.app_services(bridge~),
    width=1180.0,
    height=760.0,
  )
  click_text(runtime, "Get Started")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text: "Quick Start", .. })
    }),
  )
  click_text(runtime, "GitHub")
  inspect(opened_urls.length(), content="1")
  inspect(opened_urls[0], content="https://github.com/wzzc-dev/MoUI")
}

///|
test "website showcases lazy grid renders visible screenshots only" {
  let commands = Model::new()
    .update(OpenShowcases)
    .test_runtime(width=1180.0, height=760.0)
    .draw_commands()
  let showcase_titles = [
    "Showcase", "iOS Showcase", "HarmonyOS Showcase", "Markdown Editor", "Mo Workbench",
    "Excel Viewer", "WebView Demo", "Android Showcase",
  ]
  let visible_titles = showcase_titles.filter(title => has_text(commands, title))
  assert_true(visible_titles.length() > 0)
  assert_true(visible_titles.length() < showcase_titles.length())
  let screenshot_sources = [
    "assets/screenshots/showcase.webp", "assets/screenshots/ios-componentgallery.webp",
    "assets/screenshots/harmonyos-componentgallery.webp", "assets/screenshots/markdown_editor.webp",
    "assets/screenshots/mo_workbench.webp", "assets/screenshots/excel.webp", "assets/screenshots/webview.webp",
    "assets/screenshots/android-componentgallery.webp",
  ]
  let visible_sources = screenshot_sources.filter(source => {
    has_image_source(commands, source)
  })
  assert_true(visible_sources.length() > 0)
  assert_true(visible_sources.length() < screenshot_sources.length())
  assert_true(has_text(commands, "Archived preview"))
  assert_true(has_text(commands, "Evidence pending"))
}

///|
test "website showcases scroll their virtual grid without a duplicate page heading" {
  let model = Model::new().update(OpenShowcases)
  let latest = Ref(model)
  let runtime = model.tracked_test_runtime(latest, width=1180.0, height=760.0)
  let commands = runtime.draw_commands()
  assert_true(exact_text_count(commands, "Showcases") == 1)
  assert_true(has_text(commands, "MoUI screenshot gallery"))
  assert_true(
    has_text(commands, "Click any screenshot to open its source on GitHub."),
  )
  let image = image_frame(commands, "assets/screenshots/showcase.webp").unwrap()
  assert_false(
    has_image_source(
      commands, "assets/screenshots/android-componentgallery.webp",
    ),
  )
  let result = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@geometry.Point::new(
        x=image.origin.x + image.size.width / 2.0,
        y=image.origin.y + image.size.height / 2.0,
      ),
      phase=@core.PointerPhase::Move,
      wheel_delta=@geometry.Point::new(x=0.0, y=-2000.0),
    ),
  )
  assert_true(result.host_flags() == 1)
  assert_true(latest.val.showcase_grid_scroll.y > 0.0)
  assert_true(
    has_image_source(
      runtime.draw_commands(),
      "assets/screenshots/android-componentgallery.webp",
    ),
  )
}

///|
test "website showcases footer links stay visible in short viewports" {
  let model = Model::new().update(OpenShowcases)
  let compact_size = @geometry.Size::new(width=390.0, height=390.0)
  let compact = model.test_runtime(width=390.0, height=390.0).draw_commands()
  let urls = website_live_demo_urls()
  for url in urls {
    assert_true(text_within(compact, url, compact_size))
  }
  let desktop_size = @geometry.Size::new(width=1180.0, height=760.0)
  let desktop = model.test_runtime(width=1180.0, height=760.0).draw_commands()
  for url in urls {
    assert_true(text_within(desktop, url, desktop_size))
  }
}

///|
test "website resets showcase grid scroll when returning to the route" {
  let model = {
    ..Model::new().update(OpenShowcases),
    showcase_grid_scroll: @geometry.Point::new(x=0.0, y=180.0),
  }
  assert_true(model.showcase_grid_scroll.y == 180.0)
  let revisited = model.update(OpenHome).update(OpenShowcases)
  assert_true(revisited.showcase_grid_scroll.y == 0.0)
}

///|
test "website showcase cards link to their owning source entrypoints" {
  let entries = website_showcase_entries()
  assert_true(
    entries.any(entry => {
      entry.slug == "showcase" &&
      entry.source_url ==
      "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/app"
    }),
  )
  assert_true(
    entries.any(entry => {
      entry.slug == "ios-componentgallery" &&
      entry.source_url ==
      "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/ios_window_hosted" &&
      entry.status_key == "showcase.status.pending"
    }),
  )
  assert_true(
    entries.any(entry => {
      entry.slug == "android-componentgallery" &&
      entry.source_url ==
      "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/android_window_hosted" &&
      entry.status_key == "showcase.status.pending"
    }),
  )
}

///|
test "website showcases footer opens live demo pages" {
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
  let runtime = Model::new()
    .update(OpenShowcases)
    .test_runtime_with_services(
      @backend_common_services.app_services(bridge~),
      width=1180.0,
      height=760.0,
    )
  let commands = runtime.draw_commands()
  let urls = website_live_demo_urls()
  inspect(urls.length(), content="3")
  for url in urls {
    assert_true(has_text(commands, url))
  }
  click_text(runtime, urls[0])
  inspect(opened_urls.length(), content="1")
  inspect(opened_urls[0], content=urls[0])
  click_text(runtime, urls[1])
  inspect(opened_urls.length(), content="2")
  inspect(opened_urls[1], content=urls[1])
  click_text(runtime, urls[2])
  inspect(opened_urls.length(), content="3")
  inspect(opened_urls[2], content=urls[2])
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
          if path == "docs/catalog.json" {
            @host.HostServiceResponse::TextFileContent(
              path,
              website_test_catalog().to_json().stringify(),
            )
          } else {
            @host.HostServiceResponse::TextFileContent(
              path, "# Runtime Docs\n\nMoUI fetches **Markdown** at runtime.\n\n- One source file\n\n[Android](android-support.md)\n\n```moonbit\nfn main {}\n```",
            )
          }
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let runtime = Model::new().test_runtime_with_services(
    @backend_common_services.app_services(bridge~),
    width=1180.0,
    height=760.0,
  )
  click_text(runtime, "Docs")
  let commands = runtime.draw_commands()
  inspect(requested_paths.length(), content="2")
  inspect(requested_paths[0], content="docs/catalog.json")
  inspect(requested_paths[1], content="docs/moui-readme.md")
  assert_true(has_text(commands, "MoUI Documentation"))
  assert_true(has_text(commands, "Runtime"))
  assert_true(has_text(commands, "Docs"))
  assert_true(has_text(commands, "MoUI"))
  assert_true(has_text(commands, "fetches"))
  assert_true(has_text(commands, "Markdown"))
  assert_true(has_text(commands, "Android"))
  assert_true(has_text_on_line(commands, "fn main {}"))
  assert_true(
    has_text_align(commands, "MoUI Documentation", @core.TextAlign::TextStart),
  )
  assert_true(
    has_text_align(commands, "Runtime Docs", @core.TextAlign::TextStart),
  )
  assert_true(has_text_align(commands, "fn", @core.TextAlign::TextStart))
}

///|
test "website desktop docs keeps navigation fixed while markdown scrolls" {
  let sections : Array[String] = []
  for index in 0..<80 {
    sections.push(
      "## Section \{index}\n\nParagraph \{index} with documentation content.",
    )
  }
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoaded(
      "docs/moui-readme.md",
      website_parse_markdown_document(
        "docs/moui-readme.md",
        "# Runtime Docs\n\n" + sections.join("\n\n"),
      ),
    ),
  }
  let latest = Ref(model)
  let runtime = model.tracked_test_runtime(latest, width=1180.0, height=760.0)
  guard text_frame(runtime.draw_commands(), "MoUI README") is Some(nav_before) else {
    fail("expected docs navigation item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=820.0, y=520.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=-420.0),
      ),
    ),
  )
  assert_true(latest.val.docs_scroll.y > 0.0)
  guard text_frame(runtime.draw_commands(), "MoUI README") is Some(nav_after) else {
    fail("expected fixed docs navigation item after scroll")
  }
  inspect(nav_after.origin.y, content=nav_before.origin.y.to_string())
}

///|
test "website desktop docs sidebar scrolls independently" {
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoaded(
      "docs/moui-readme.md",
      website_parse_markdown_document(
        "docs/moui-readme.md", "# Runtime Docs\n\nDocumentation body.",
      ),
    ),
  }
  let latest = Ref(model)
  let runtime = model.tracked_test_runtime(latest, width=1180.0, height=760.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=180.0, y=600.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=-420.0),
      ),
    ),
  )
  assert_true(latest.val.docs_body_scroll.y > 0.0)
  inspect(latest.val.docs_scroll.y, content="0")
}

///|
test "website selecting another document resets only document scroll" {
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    selected_doc_slug: "moui-readme",
    docs_body_scroll: @geometry.Point::new(x=0.0, y=180.0),
    docs_scroll: @geometry.Point::new(x=0.0, y=900.0),
  }
  let next = model.update(SelectDoc("development"))
  inspect(next.docs_scroll.y, content="0")
  inspect(next.docs_body_scroll.y, content="180")
}

///|
test "website compact docs renders and scrolls markdown" {
  let sections : Array[String] = []
  for index in 0..<48 {
    sections.push(
      "## Compact Section \{index}\n\nCompact paragraph \{index} stays readable.",
    )
  }
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoaded(
      "docs/moui-readme.md",
      website_parse_markdown_document(
        "docs/moui-readme.md",
        "# Compact Runtime Docs\n\n" + sections.join("\n\n"),
      ),
    ),
  }
  let latest = Ref(model)
  let runtime = model.tracked_test_runtime(latest, width=390.0, height=844.0)
  let before = runtime.draw_commands()
  assert_true(has_text(before, "Compact Runtime Docs"))
  assert_true(has_text(before, "Compact Section 0"))
  assert_true(has_text(before, "evidence."))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=210.0, y=720.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=-420.0),
      ),
    ),
  )
  assert_true(latest.val.docs_scroll.y > 0.0)
}

///|
test "website intermediate width collapses navigation and docs workspace" {
  let metrics = website_metrics(@geometry.Size::new(width=900.0, height=900.0))
  assert_false(metrics.compact)
  assert_true(metrics.nav_compact)
  assert_true(metrics.docs_compact)
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoaded(
      "docs/moui-readme.md",
      website_parse_markdown_document(
        "docs/moui-readme.md", "# Runtime Docs\n\nIntermediate width documentation body.",
      ),
    ),
  }
  let commands = model.test_runtime(width=900.0, height=900.0).draw_commands()
  assert_true(has_text(commands, "Menu"))
  assert_true(has_text(commands, "Search & Contents"))
  assert_true(has_text(commands, "Intermediate width documentation body."))
}

///|
test "website desktop docs navigation labels are start aligned" {
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoaded(
      "docs/moui-readme.md",
      website_parse_markdown_document(
        "docs/moui-readme.md", "# Runtime Docs\n\nDocumentation body.",
      ),
    ),
  }
  let commands = model.test_runtime(width=1180.0, height=760.0).draw_commands()
  assert_true(
    has_text_align(commands, "MoUI README", @core.TextAlign::TextStart),
  )
}

///|
test "website docs completion ignores stale app-owned token" {
  let path = "docs/architecture.md"
  let current_token = 2
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    selected_doc_slug: "architecture",
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocLoading(current_token, path),
  }
  let unchanged = model.update(
    HostDocsCompleted(
      1,
      path,
      @services.ServiceTaskResult::Success("# Stale\n\nOld response"),
    ),
  )
  match unchanged.doc_state {
    DocLoading(token, loading_path) => {
      inspect(token, content="2")
      inspect(loading_path, content="docs/architecture.md")
    }
    _ => fail("expected stale completion to keep current loading state")
  }
  match
    unchanged.update(
      HostDocsCompleted(
        current_token,
        path,
        @services.ServiceTaskResult::Success("# Fresh\n\nLatest response"),
      ),
    ).doc_state {
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
  let model = {
    ..Model::new(),
    home_scroll: @geometry.Point::new(x=0.0, y=620.0),
  }
  let scrolled = model
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
        wheel_delta=@geometry.Point::new(x=0.0, y=-180.0),
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
  assert_true(text_within(compact, "Source", compact_size))
  assert_true(
    text_within(compact, "Typed UI for web and native hosts.", compact_size),
  )
  assert_false(text_within(compact, "Live Counter", compact_size))
}

///|
test "website compact hero switches between source and counter" {
  let runtime = test_program_runtime(width=390.0, height=844.0)
  assert_true(has_text(runtime.draw_commands(), "Source"))
  click_text(runtime, "Counter")
  assert_true(has_text(runtime.draw_commands(), "Live Counter"))
}

///|
test "website catalog exposes 38 entries and all platform documents" {
  let catalog = website_parse_catalog(
    website_test_catalog().to_json().stringify(),
  ).unwrap()
  inspect(catalog.entries.length(), content="38")
  let platforms = catalog.entries.filter(entry => entry.group == "platforms")
  assert_true(platforms.any(entry => entry.slug == "platform-notes-web"))
  assert_true(platforms.any(entry => entry.slug == "platform-notes-macos"))
  assert_true(platforms.any(entry => entry.slug == "platform-notes-windows"))
  assert_true(platforms.any(entry => entry.slug == "platform-notes-linux"))
  assert_true(platforms.any(entry => entry.slug == "android-support"))
  assert_true(platforms.any(entry => entry.slug == "ios-support"))
  assert_true(platforms.any(entry => entry.slug == "harmonyos-support"))
  inspect(catalog.filtered_entries("android").length(), content="1")
}

///|
test "website unknown docs slug renders not found instead of README" {
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    selected_doc_slug: "missing-page",
    catalog_state: CatalogLoaded(website_test_catalog()),
    doc_state: DocNotFound("missing-page"),
  }
  let commands = model.test_runtime(width=1180.0, height=760.0).draw_commands()
  assert_true(has_text(commands, "Document not found"))
}

///|
test "website route host receives deep-link and anchor commands" {
  let commands : Array[WebsiteRouteCommand] = []
  let route_host = WebsiteRouteHost::new(
    route_source=@services.RouteSource::new(),
    push_route=route => commands.push(PushRoute(route)),
    scroll_to_key=(key, alignment) => commands.push(ScrollToKey(key, alignment)),
  )
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) =>
          @host.HostServiceResponse::TextFileContent(
            path,
            if path == "docs/catalog.json" {
              website_test_catalog().to_json().stringify()
            } else {
              "# Doc"
            },
          )
        _ => @host.HostServiceResponse::Unavailable("unexpected")
      }
    },
  )
  let runtime = test_runtime(
    Model::new().program_with_services(
      @backend_common_services.app_services(bridge~),
      route_host=Some(route_host),
    ),
    width=1180.0,
    height=760.0,
  )
  guard text_frame(runtime.draw_commands(), "Quick Start") is Some(frame) else {
    fail("expected Quick Start")
  }
  click_frame(runtime, frame)
  inspect(commands.length(), content="2")
  match commands[0] {
    PushRoute(route) => inspect(route, content="home?anchor=quick-start")
    _ => fail("expected route push")
  }
  match commands[1] {
    ScrollToKey(key, _) => inspect(key, content="home-quick-start")
    _ => fail("expected anchor scroll")
  }
}

///|
test "website docs metadata refreshes after deep-link catalog load" {
  let titles : Array[String] = []
  let route_host = WebsiteRouteHost::new(
    route_source=@services.RouteSource::new(),
    update_metadata=(title, _description, _canonical, _locale, _direction) => {
      titles.push(title)
    },
  )
  let model = {
    ..Model::new(),
    page: WebsiteDocs,
    selected_doc_slug: "moui-readme",
    catalog_state: CatalogLoading(1),
  }
  ignore(
    model.update_with_services(
      HostCatalogCompleted(
        1,
        @services.ServiceTaskResult::Success(
          website_test_catalog().to_json().stringify(),
        ),
      ),
      @services.AppServices::unavailable(),
      Some(route_host),
    ),
  )
  guard titles.last() is Some(title) else {
    fail("expected refreshed metadata")
  }
  inspect(title, content="MoUI README - MoUI Docs")
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
fn website_test_catalog() -> WebsiteDocsCatalog {
  let groups = [
    WebsiteDocGroup::{ id: "get-started", title: "Get Started" },
    WebsiteDocGroup::{ id: "platforms", title: "Platforms" },
    WebsiteDocGroup::{ id: "guides", title: "Guides" },
  ]
  let entries : Array[WebsiteDocEntry] = []
  let core_entries = [
    ("get-started", "moui-readme", "MoUI README"),
    ("guides", "development", "Development"),
    ("guides", "architecture", "Architecture"),
    ("platforms", "platform-notes-web", "Web Platform Notes"),
    ("platforms", "platform-notes-macos", "macOS Platform Notes"),
    ("platforms", "platform-notes-windows", "Windows Platform Notes"),
    ("platforms", "platform-notes-linux", "Linux Platform Notes"),
    ("platforms", "android-support", "Android Support"),
    ("platforms", "ios-support", "iOS Support"),
    ("platforms", "harmonyos-support", "HarmonyOS Support"),
  ]
  for item in core_entries {
    let (group, slug, title) = item
    entries.push({
      group,
      slug,
      title,
      path: "docs/" + slug + ".md",
      summary: title + " documentation",
      keywords: [slug, title],
    })
  }
  for index in 0..<28 {
    let slug = "guide-\{index}"
    entries.push({
      group: "guides",
      slug,
      title: "Guide \{index}",
      path: "docs/" + slug + ".md",
      summary: "Guide documentation",
      keywords: ["guide"],
    })
  }
  { schemaVersion: 1, siteUrl: "https://example.test/MoUI/", groups, entries }
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
fn Model::tracked_test_runtime(
  self : Model,
  latest : Ref[Model],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  let program = @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => (model.update(message), @moui.Effect::none()),
    view=(model, env) => {
      latest.val = model
      model.view(env)
    },
  )
  test_runtime(program, width~, height~)
}

///|
fn Model::test_runtime_with_services(
  self : Model,
  services : @services.AppServices,
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
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(text)
  })
}

///|
fn exact_text_count(commands : Array[@core.DrawCommand], text : String) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, .. }) if value == text =>
        count += 1
      _ => ()
    }
  }
  count
}

///|
/// Like `has_text`, but concatenates text runs that share the same line
/// (y within 2.0px) before matching. Needed for syntax-highlighted code
/// blocks where "fn main {}" is split into separate runs per token.
fn has_text_on_line(commands : Array[@core.DrawCommand], text : String) -> Bool {
  let items : Array[(Double, Double, String)] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        items.push((frame.origin.y, frame.origin.x, value))
      _ => ()
    }
  }
  items.sort_by(fn(a, b) {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  let mut combined = ""
  let mut last_y = 0.0
  let mut first = true
  for item in items {
    if first {
      combined = item.2
      last_y = item.0
      first = false
    } else if (item.0 - last_y).abs() < 2.0 {
      combined = combined + item.2
    } else {
      combined = combined + "\n" + item.2
      last_y = item.0
    }
  }
  combined.contains(text)
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
fn image_frame(
  commands : Array[@core.DrawCommand],
  source : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawImage({ source: value, frame, .. }) if value ==
        source => return Some(frame)
      _ => ()
    }
  }
  None
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
    value.contains(text) &&
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
  if candidates.is_empty() {
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

///|
test "website tutorial route is available" {
  let model = Model::new().update(OpenTutorial)
  let is_tutorial = match model.page {
    WebsiteTutorial => true
    _ => false
  }
  inspect(is_tutorial, content="true")
}

///|
test "website tutorial cards wrap within the desktop content width" {
  let size = @geometry.Size::new(width=1180.0, height=1400.0)
  let commands = Model::new()
    .update(OpenTutorial)
    .test_runtime(width=size.width, height=size.height)
    .draw_commands()
  guard text_frame(commands, "01-hello-world") is Some(first) else {
    fail("expected first tutorial card")
  }
  guard text_frame(commands, "03-state-events") is Some(third) else {
    fail("expected third tutorial card")
  }
  assert_true(third.origin.y > first.origin.y)
  assert_true(text_within(commands, "06-animation", size))
  assert_true(has_text(commands, "MOUI TUTORIAL"))
  assert_true(has_text(commands, "Course map"))
  assert_true(has_text(commands, "LESSON 06"))
  assert_true(has_text(commands, "Open lesson"))
}

///|
test "website playground links stay relative to the current deployment" {
  inspect(website_playground_url(), content="./playground/")
  inspect(
    website_playground_url(example="01-hello-world"),
    content="./playground/?example=01-hello-world",
  )
}
