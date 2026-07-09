///|
test "component gallery update changes model" {
  let model = ComponentGalleryModel::new(active_platform=PlatformId::MacOS)
  let story = update(model, SelectStory("inputs"))
  assert_true(story.active_story == @app.ComponentGalleryStoryId::Inputs)
  let selected = update(story, SelectPlatform("android"))
  assert_true(selected.selected_platform == @app.PlatformId::Android)
  assert_true(selected.active_story == @app.ComponentGalleryStoryId::Platforms)
  let searched = update(selected, SearchChanged("button"))
  inspect(searched.search_query, content="button")
  assert_true(searched.active_story == @app.ComponentGalleryStoryId::Buttons)
  let edited = update(searched, SampleTextChanged("Reusable controls"))
  inspect(edited.sample_text, content="Reusable controls")
  let toggled = update(edited, FeatureToggled(false))
  inspect(toggled.feature_enabled, content="false")
  let slid = update(toggled, SliderChanged(0.25))
  inspect(slid.slider_value, content="0.25")
  inspect(update(slid, Increment).counter, content="1")
  inspect(update(update(slid, Increment), Decrement).counter, content="0")
  inspect(update(slid, Reset).slider_value, content="0.66")
}

///|
test "component gallery runtime renders story browser" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Component Gallery"))
  assert_true(has_text(commands, "Stories"))
  assert_true(has_text(commands, "Getting Started"))
  assert_true(has_text(commands, "Components"))
  assert_true(has_text(commands, "Buttons"))
  assert_true(has_text(commands, "Inputs"))
  assert_true(has_text(commands, "Feedback"))
  assert_true(has_text(commands, "Adaptive Layout"))
  assert_true(has_text(commands, "Platform Routes"))
  assert_true(has_text(commands, "macOS"))
  assert_true(has_text(commands, "Linux"))
  assert_true(has_text(commands, "Windows"))
  assert_true(has_text(commands, "Android"))
  assert_true(has_text(commands, "iOS"))
  assert_true(has_text(commands, "Web"))
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
}

///|
test "component gallery header story count stays inside header" {
  assert_story_count_inside_header(width=1040.0, height=720.0)
  assert_story_count_inside_header(width=390.0, height=640.0)
}

///|
test "component gallery welcome header mode badge stays inside header" {
  assert_story_header_badge_inside_header(width=1040.0, height=720.0)
}

///|
test "component gallery welcome wraps copy and keeps runtime chips inside section" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_false(has_text(commands, welcome_intro_copy()))
  assert_true(
    has_text_containing(commands, "Component Gallery groups MoUI controls"),
  )
  guard first_text_frame(commands~, text="Runtime Targets") is Some(title) else {
    fail("expected Runtime Targets title")
  }
  guard enclosing_rounded_rect(
      commands~,
      frame=title,
      min_width=420.0,
      min_height=120.0,
    )
    is Some(section) else {
    fail("expected Runtime Targets section frame")
  }
  for label in ["macOS", "Linux", "Windows", "Android", "iOS", "Web"] {
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
    text="Component Gallery",
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
  let after = text_y(commands=runtime.draw_commands(), text="Component Gallery")
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
    @app.PlatformId::Web,
  ]
  for id in platforms {
    assert_true(platform_id_from_string(platform_id_to_string(id)) == Some(id))
  }
  assert_true(platform_id_from_string("plan9") is None)
  let stories = [
    @app.ComponentGalleryStoryId::Welcome,
    @app.ComponentGalleryStoryId::Buttons,
    @app.ComponentGalleryStoryId::Inputs,
    @app.ComponentGalleryStoryId::Feedback,
    @app.ComponentGalleryStoryId::Layout,
    @app.ComponentGalleryStoryId::Platforms,
  ]
  for id in stories {
    assert_true(story_id_from_string(story_id_to_string(id)) == Some(id))
  }
  assert_true(story_id_from_string("unknown") is None)
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
fn assert_story_count_inside_header(
  width~ : Double,
  height~ : Double,
) -> Unit raise {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width~,
    height~,
  )
  let commands = runtime.draw_commands()
  match
    (
      first_text_frame(commands~, text="6 stories"),
      first_header_frame(commands),
    ) {
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
    _ => fail("expected story-count text and header frame")
  }
}

///|
fn assert_story_header_badge_inside_header(
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
    fail("expected Welcome story header title")
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
    fail("expected story header frame containing Welcome and Canvas")
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
fn welcome_intro_copy() -> String {
  "Component Gallery groups MoUI controls into focused stories. The same model/update/view app is rendered by desktop Skia, mobile embedded sessions, and Web wasm-gc."
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
