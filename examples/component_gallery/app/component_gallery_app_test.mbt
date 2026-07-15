///|
test "component gallery update changes model" {
  let model = ComponentGalleryModel::new(active_platform=PlatformId::MacOS)
  inspect(model.session_runtime.path, content="GPU")
  inspect(model.session_runtime.backend, content="skia-gpu-native")
  let item = update(model, SelectItem("text-field"))
  assert_true(item.active_item == @app.ComponentGalleryItemId::TextField)
  let selected = update(item, SelectPlatform("android"))
  assert_true(selected.selected_platform == @app.PlatformId::Android)
  assert_true(
    selected.active_item == @app.ComponentGalleryItemId::PlatformRoutes,
  )
  let searched = update(selected, SearchChanged("button"))
  inspect(searched.search_query, content="button")
  assert_true(searched.active_item == @app.ComponentGalleryItemId::Button)
  let edited = update(searched, SampleTextChanged("Reusable controls"))
  inspect(edited.sample_text, content="Reusable controls")
  let toggled = update(edited, FeatureToggled(false))
  inspect(toggled.feature_enabled, content="false")
  let slid = update(toggled, SliderChanged(0.25))
  inspect(slid.slider_value, content="0.25")
  inspect(update(slid, Increment).counter, content="1")
  inspect(update(update(slid, Increment), Decrement).counter, content="0")
  inspect(update(slid, Reset).slider_value, content="0.66")
  let probe = ComponentGalleryModel::new(active_platform=PlatformId::IOS)
  assert_true(
    probe.active_item == @app.ComponentGalleryItemId::MobileServiceProbe,
  )
  let edited_probe = update(
    probe,
    ProbeTextChanged("hello \u{1F469}\u{200D}\u{1F4BB}"),
  )
  inspect(edited_probe.probe_text, content="hello \u{1F469}\u{200D}\u{1F4BB}")
  inspect(update(edited_probe, ProbeAction).probe_action_count, content="1")
  inspect(update(edited_probe, ProbeSubmit).probe_submit_count, content="1")
}

///|
test "component gallery runtime renders component catalog" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Component Gallery"))
  assert_true(has_text(commands, "Components"))
  assert_true(has_text(commands, "Getting Started"))
  assert_true(has_text(commands, "Controls"))
  assert_true(has_text(commands, "Button"))
  assert_true(has_text(commands, "Text Field"))
  assert_true(has_text(commands, "Text Area"))
  assert_true(has_text(commands, "Password Field"))
  assert_true(has_text(commands, "Number Field"))
  assert_true(has_text(commands, "Checkbox"))
  assert_true(has_text(commands, "Toggle"))
  assert_true(has_text(commands, "Radio"))
  assert_true(has_text(commands, "Segmented Control"))
  assert_true(has_text(commands, "Picker"))
  assert_true(has_text(commands, "Slider"))
  assert_true(has_text(commands, "Chips"))
  assert_true(has_text(commands, "Feedback"))
  assert_true(has_text(commands, "Badge"))
  assert_true(has_text(commands, "Progress"))
  assert_true(has_text(commands, "Banner"))
  assert_true(has_text(commands, "Callout"))
  assert_true(has_text(commands, "State Panel"))
  assert_true(has_text(commands, "Toast"))
  assert_true(has_text(commands, "Snackbar"))
  assert_true(has_text(commands, "Display"))
  assert_true(has_text(commands, "Stat Card"))
  assert_true(has_text(commands, "Avatar"))
  assert_true(has_text(commands, "Layout"))
  assert_true(has_text(commands, "Divider"))
  assert_true(has_text(commands, "Toolbar"))
  assert_true(has_text(commands, "Status Bar"))
  assert_true(has_text(commands, "Surface"))
  assert_true(has_text(commands, "Row & Column"))
  assert_true(has_text(commands, "Responsive Grid"))
  assert_true(has_text(commands, "Scroll View"))
  assert_true(has_text(commands, "Runtime"))
  assert_true(has_text(commands, "Platform Routes"))
  assert_true(has_text(commands, "macOS"))
  assert_true(has_text(commands, "Linux"))
  assert_true(has_text(commands, "Windows"))
  assert_true(has_text(commands, "Android"))
  assert_true(has_text(commands, "iOS"))
  assert_true(has_text(commands, "HarmonyOS"))
  assert_true(has_text(commands, "Web"))
}

///|
test "component gallery platform routes show session runtime" {
  let selected = update(
    ComponentGalleryModel::new(
      active_platform=PlatformId::Linux,
      session_runtime=session_runtime_from_selection(
        host="Linux",
        backend="skia-raster-native",
        surface_route="raster",
        requested="auto",
        gpu_available=false,
        gpu_promoted=true,
        note="Skia GPU host surface is unavailable",
      ),
    ),
    SelectItem("platform-routes"),
  )
  assert_true(
    selected.active_item == @app.ComponentGalleryItemId::PlatformRoutes,
  )
  inspect(selected.session_runtime.path, content="CPU")
  let selected_runtime = @runtime.new_program_with_dimensions(
    program=@moui.Program::simple_with_environment(
      init=selected,
      update~,
      view~,
    ),
    width=1040.0,
    height=720.0,
  )
  let commands = selected_runtime.draw_commands()
  assert_true(has_text(commands, "Session Runtime"))
  assert_true(has_text(commands, "Path"))
  assert_true(has_text(commands, "CPU"))
  assert_true(has_text(commands, "skia-raster-native"))
  assert_true(has_text(commands, "raster"))
  assert_true(has_text(commands, "Platform Routes"))
  assert_true(
    has_text_containing(commands, "Skia GPU host surface is unavailable"),
  )
}

///|
test "component gallery mobile host fills device width" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width=1366.0,
    height=1024.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_fill_at_least_width(commands, 1366.0))
  assert_true(has_text(commands, "Mobile Service Probe"))
  assert_true(has_text(commands, "IME value: mobile-service-probe"))
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawImage(_)),
  )
}

///|
test "component gallery portrait probe keeps compact gallery navigation" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width=390.0,
    height=844.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Component Gallery"))
  assert_true(has_text(commands, "Browse all components"))
  assert_true(has_text(commands, "Mobile Service Probe"))
  assert_true(has_text(commands, "IME value: mobile-service-probe"))
}

///|
test "component gallery selecting component preserves sidebar scroll" {
  let model = ComponentGalleryModel::new(active_platform=PlatformId::MacOS)
  model.sidebar_scroll.scroll_to(x=0.0, y=260.0)
  model.content_scroll.scroll_to(x=0.0, y=420.0)
  model.page_scroll.scroll_to(x=0.0, y=180.0)
  let selected = update(model, SelectItem("slider"))
  assert_true(selected.active_item == @app.ComponentGalleryItemId::Slider)
  assert_true(selected.sidebar_scroll.offset().y == 260.0)
  assert_true(selected.content_scroll.offset().y == 0.0)
  assert_true(selected.page_scroll.offset().y == 0.0)
}

///|
test "component gallery desktop sidebar wheel does not move preview" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let before_commands = runtime.draw_commands()
  guard first_text_frame_before_x(before_commands, text="Button", max_x=280.0)
    is Some(before_left) else {
    fail("expected Button in sidebar before scroll")
  }
  guard first_text_frame_after_x(
      commands=before_commands,
      text="Welcome",
      min_x=300.0,
    )
    is Some(before_right) else {
    fail("expected Welcome preview before scroll")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=40.0, y=180.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-160.0),
      ),
    ),
  )
  let after_commands = runtime.draw_commands()
  guard first_text_frame_before_x(after_commands, text="Button", max_x=280.0)
    is Some(after_left) else {
    fail("expected Button in sidebar after scroll")
  }
  guard first_text_frame_after_x(
      commands=after_commands,
      text="Welcome",
      min_x=300.0,
    )
    is Some(after_right) else {
    fail("expected Welcome preview after scroll")
  }
  assert_true(after_left.origin.y < before_left.origin.y)
  assert_true(after_right.origin.y == before_right.origin.y)
}

///|
test "component gallery header demo count stays inside header" {
  assert_component_count_inside_header(width=1040.0, height=720.0)
  assert_component_count_inside_header(width=390.0, height=640.0)
}

///|
test "component gallery welcome header mode badge stays inside header" {
  assert_component_header_badge_inside_header(width=1040.0, height=720.0)
}

///|
test "component gallery welcome wraps copy and keeps runtime chips inside section" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_false(has_text(commands, welcome_index_copy()))
  assert_true(
    has_text_containing(commands, "Use the sidebar to jump between small"),
  )
  guard first_text_frame(commands~, text="Runtime Hosts") is Some(title) else {
    fail("expected Runtime Hosts title")
  }
  guard enclosing_rounded_rect(
      commands~,
      frame=title,
      min_width=420.0,
      min_height=120.0,
    )
    is Some(section) else {
    fail("expected Runtime Hosts section frame")
  }
  for
    label in ["macOS", "Linux", "Windows", "Android", "iOS", "HarmonyOS", "Web"] {
    assert_platform_chip_inside_section(commands~, text=label, section~)
  }
}

///|
test "component gallery page scroll responds to wheel delta" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width=390.0,
    height=640.0,
  )
  let before = text_y(
    commands=runtime.draw_commands(),
    text="Mobile Service Probe",
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=24.0, y=24.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-160.0),
      ),
    ),
  )
  let after = text_y(
    commands=runtime.draw_commands(),
    text="Mobile Service Probe",
  )
  match (before, after) {
    (Some(before), Some(after)) => assert_true(after < before)
    _ => fail("expected clipped page content before and after scroll")
  }
}

///|
test "component gallery ids roundtrip" {
  let platforms = [
    @app.PlatformId::MacOS,
    @app.PlatformId::Linux,
    @app.PlatformId::Windows,
    @app.PlatformId::Android,
    @app.PlatformId::IOS,
    @app.PlatformId::HarmonyOs,
    @app.PlatformId::Web,
  ]
  for id in platforms {
    assert_true(platform_id_from_string(platform_id_to_string(id)) == Some(id))
  }
  assert_true(platform_id_from_string("plan9") is None)
  let items = [
    @app.ComponentGalleryItemId::Welcome,
    @app.ComponentGalleryItemId::Button,
    @app.ComponentGalleryItemId::TextField,
    @app.ComponentGalleryItemId::TextArea,
    @app.ComponentGalleryItemId::ClearableTextField,
    @app.ComponentGalleryItemId::PasswordField,
    @app.ComponentGalleryItemId::NumberField,
    @app.ComponentGalleryItemId::Stepper,
    @app.ComponentGalleryItemId::Checkbox,
    @app.ComponentGalleryItemId::Toggle,
    @app.ComponentGalleryItemId::Radio,
    @app.ComponentGalleryItemId::RadioGroup,
    @app.ComponentGalleryItemId::CheckboxGroup,
    @app.ComponentGalleryItemId::SegmentedControl,
    @app.ComponentGalleryItemId::Picker,
    @app.ComponentGalleryItemId::Slider,
    @app.ComponentGalleryItemId::Chips,
    @app.ComponentGalleryItemId::Badge,
    @app.ComponentGalleryItemId::Progress,
    @app.ComponentGalleryItemId::Banner,
    @app.ComponentGalleryItemId::Callout,
    @app.ComponentGalleryItemId::StatePanel,
    @app.ComponentGalleryItemId::InlineError,
    @app.ComponentGalleryItemId::Toast,
    @app.ComponentGalleryItemId::Snackbar,
    @app.ComponentGalleryItemId::StatCard,
    @app.ComponentGalleryItemId::Avatar,
    @app.ComponentGalleryItemId::Divider,
    @app.ComponentGalleryItemId::Toolbar,
    @app.ComponentGalleryItemId::StatusBar,
    @app.ComponentGalleryItemId::Surface,
    @app.ComponentGalleryItemId::RowColumn,
    @app.ComponentGalleryItemId::ResponsiveGrid,
    @app.ComponentGalleryItemId::ScrollView,
    @app.ComponentGalleryItemId::PlatformRoutes,
    @app.ComponentGalleryItemId::MobileServiceProbe,
  ]
  for id in items {
    assert_true(
      gallery_item_id_from_string(gallery_item_id_to_string(id)) == Some(id),
    )
  }
  assert_true(gallery_item_id_from_string("unknown") is None)
}

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
fn has_fill_at_least_width(
  commands : Array[@core.DrawCommand],
  width : Double,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::FillRoundedRectBrush({ rect: { size, .. }, .. }, _) &&
    size.width >= width
  })
}

///|
fn text_y(commands~ : Array[@core.DrawCommand], text~ : String) -> Double? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame.origin.y)
        }
      _ => ()
    }
  }
  None
}

///|
fn assert_component_count_inside_header(
  width~ : Double,
  height~ : Double,
) -> Unit raise {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::MacOS),
    width~,
    height~,
  )
  let commands = runtime.draw_commands()
  match
    (first_text_frame(commands~, text="36 demos"), first_header_frame(commands)) {
    (Some(text_frame), Some(header_frame)) => {
      assert_true(text_frame.origin.x >= header_frame.origin.x)
      assert_true(
        text_frame.origin.x + text_frame.size.width <=
        header_frame.origin.x + header_frame.size.width,
      )
      assert_true(text_frame.origin.y >= header_frame.origin.y)
      assert_true(
        text_frame.origin.y + text_frame.size.height <=
        header_frame.origin.y + header_frame.size.height,
      )
    }
    _ => fail("expected demo-count text and header frame")
  }
}

///|
fn assert_component_header_badge_inside_header(
  width~ : Double,
  height~ : Double,
) -> Unit raise {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width~,
    height~,
  )
  let commands = runtime.draw_commands()
  guard first_text_frame_after_x(commands~, text="Welcome", min_x=280.0)
    is Some(title_frame) else {
    fail("expected Welcome item header title")
  }
  guard first_text_frame_after_x(commands~, text="Canvas", min_x=280.0)
    is Some(canvas_frame) else {
    fail("expected Canvas mode badge")
  }
  guard enclosing_rounded_rect_for_pair(
      commands~,
      first=title_frame,
      second=canvas_frame,
      min_width=420.0,
      min_height=80.0,
    )
    is Some(header_frame) else {
    fail("expected item header frame containing Welcome and Canvas")
  }
  assert_rect_inside(canvas_frame, header_frame)
}

///|
fn first_text_frame(
  commands~ : Array[@core.DrawCommand],
  text~ : String,
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
fn first_text_frame_after_x(
  commands~ : Array[@core.DrawCommand],
  text~ : String,
  min_x~ : Double,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text && frame.origin.x >= min_x {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn first_text_frame_before_x(
  commands : Array[@core.DrawCommand],
  text~ : String,
  max_x~ : Double,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text && frame.origin.x < max_x {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn first_header_frame(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.origin.x == 16.0 && rect.origin.y == 16.0 {
          return Some(rect)
        }
      _ => ()
    }
  }
  None
}

///|
fn welcome_index_copy() -> String {
  "Use the sidebar to jump between small component demos. Each demo is plain app code that can be reused in another MoUI example."
}

///|
fn enclosing_rounded_rect(
  commands~ : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  min_width~ : Double,
  min_height~ : Double,
) -> @core.Rect? {
  let mut candidate : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width >= min_width &&
          rect.size.height >= min_height &&
          rect_contains_rect(rect, frame) {
          candidate = match candidate {
            Some(current) =>
              if rect.area() < current.area() {
                Some(rect)
              } else {
                Some(current)
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
fn enclosing_rounded_rect_for_pair(
  commands~ : Array[@core.DrawCommand],
  first~ : @core.Rect,
  second~ : @core.Rect,
  min_width~ : Double,
  min_height~ : Double,
) -> @core.Rect? {
  let mut candidate : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width >= min_width &&
          rect.size.height >= min_height &&
          rect_contains_rect(rect, first) &&
          rect_contains_rect(rect, second) {
          candidate = match candidate {
            Some(current) =>
              if rect.area() < current.area() {
                Some(rect)
              } else {
                Some(current)
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
fn assert_platform_chip_inside_section(
  commands~ : Array[@core.DrawCommand],
  text~ : String,
  section~ : @core.Rect,
) -> Unit raise {
  guard text_frame_inside_section(commands~, text~, section~) is Some(frame) else {
    fail("expected text inside section: \{text}")
  }
  assert_frame_inside_x(frame, section)
  guard enclosing_rounded_rect(
      commands~,
      frame~,
      min_width=70.0,
      min_height=24.0,
    )
    is Some(chip) else {
    fail("expected chip frame around text: \{text}")
  }
  assert_frame_inside_x(chip, section)
}

///|
fn text_frame_inside_section(
  commands~ : Array[@core.DrawCommand],
  text~ : String,
  section~ : @core.Rect,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text && rect_contains_rect(section, frame) {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn assert_frame_inside_x(frame : @core.Rect, bounds : @core.Rect) -> Unit raise {
  if frame.origin.x < bounds.origin.x {
    fail(
      "frame left overflow: frame.x=\{frame.origin.x} bounds.x=\{bounds.origin.x} frame.w=\{frame.size.width} bounds.w=\{bounds.size.width}",
    )
  }
  if frame.max_x() > bounds.max_x() {
    fail(
      "frame right overflow: frame.max=\{frame.max_x()} bounds.max=\{bounds.max_x()} frame.x=\{frame.origin.x} frame.w=\{frame.size.width} bounds.x=\{bounds.origin.x} bounds.w=\{bounds.size.width}",
    )
  }
}

///|
fn assert_rect_inside(frame : @core.Rect, bounds : @core.Rect) -> Unit raise {
  if !rect_contains_rect(bounds, frame) {
    fail(
      "frame overflow: frame=(\{frame.origin.x},\{frame.origin.y},\{frame.size.width},\{frame.size.height}) bounds=(\{bounds.origin.x},\{bounds.origin.y},\{bounds.size.width},\{bounds.size.height})",
    )
  }
}

///|
fn rect_contains_rect(bounds : @core.Rect, frame : @core.Rect) -> Bool {
  frame.origin.x >= bounds.origin.x &&
  frame.origin.y >= bounds.origin.y &&
  frame.max_x() <= bounds.max_x() &&
  frame.max_y() <= bounds.max_y()
}
