///|
fn test_runtime(root : @core.View[Unit]) -> @core.AppRuntime {
  @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=480.0),
  )
}

///|
test "typed button dispatches message" {
  let clicks = Ref(0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.button("Click", on_click=1, width=120.0, height=44.0),
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => clicks.val = clicks.val + message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "theme helper customizes core theme tokens" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let motion : @core.MotionScale = {
    fast_ms: 80.0,
    normal_ms: 140.0,
    slow_ms: 220.0,
    easing: @core.Easing::EaseOut,
  }
  let theme = @views.theme(
    base=@core.Theme::dark(),
    accent~,
    spacing=14.0,
    corner_radius=10.0,
    motion~,
  )
  assert_true(theme.scheme == @core.ColorScheme::Dark)
  assert_true(theme.palette.primary == accent)
  inspect(theme.spacing_scale.sm, content="14")
  inspect(theme.radius_scale.md, content="10")
  inspect(theme.motion.normal_ms, content="140")
}

///|
test "scalar controls can resolve colors from theme" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let theme = @views.theme(accent~)
  let runtime = test_runtime(
    @views.column([
      @views.checkbox(
        "Themed checkbox",
        checked=true,
        on_change=_value => (),
        theme~,
      ),
      @views.progress(0.4, theme~, width=160.0),
      @views.slider(0.6, theme~, width=160.0),
      @views.toggle("Themed toggle", true, on_change=_value => (), theme~),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, accent))
  assert_true(has_text(draw, "Themed toggle"))
}

///|
test "picker controls can resolve surface style from theme" {
  let surface = @core.Color::rgba(r=0.14, g=0.18, b=0.24)
  let base = @core.Theme::light()
  let theme = @views.theme(
    base~,
    palette={ ..base.palette, surface, },
    corner_radius=18.0,
  )
  let items = [
    @views.picker_item("native", "Native"),
    @views.picker_item("web", "Web"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.picker(items, selected="native", on_select=_value => (), theme~),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=5, day=21),
        on_select=_value => (),
        theme~,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, surface))
}

///|
test "controls can consume neutral core style contracts" {
  let button_bg = @core.Color::rgba(r=0.72, g=0.12, b=0.36)
  let field_bg = @core.Color::rgba(r=0.10, g=0.18, b=0.26)
  let progress_fg = @core.Color::rgba(r=0.18, g=0.64, b=0.38)
  let slider_thumb = @core.Color::rgba(r=0.96, g=0.68, b=0.20)
  let picker_bg = @core.Color::rgba(r=0.18, g=0.12, b=0.30)
  let date_bg = @core.Color::rgba(r=0.14, g=0.24, b=0.20)
  let button_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(button_bg),
    border: None,
    radius: 14.0,
    shadow: None,
  }
  let button_style : @core.ButtonStyle = {
    normal: button_state,
    hovered: button_state,
    pressed: button_state,
    disabled: button_state,
  }
  let field_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(field_bg),
    border: None,
    radius: 10.0,
    shadow: None,
  }
  let field_style : @core.TextFieldStyle = {
    normal: field_state,
    focused: field_state,
    disabled: field_state,
    placeholder_color: @core.Color::gray(),
    cursor_color: progress_fg,
    font: @core.FontSpec::new(size=15.0, weight=500),
  }
  let progress_style : @core.ProgressStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.07, g=0.09, b=0.12),
    radius: 6.0,
  }
  let slider_style : @core.SliderStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.12, g=0.14, b=0.18),
    thumb_color: slider_thumb,
    track_height: 7.0,
    thumb_size: 18.0,
    radius: 9.0,
  }
  let picker_style : @core.PickerStyle = {
    font: @core.FontSpec::new(size=14.0, weight=600),
    foreground: @core.Color::white(),
    background: @core.Brush::solid(picker_bg),
    radius: 12.0,
    popup_max_height: 180.0,
  }
  let date_style = { ..picker_style, background: @core.Brush::solid(date_bg) }
  let items = [
    @views.picker_item("material", "Material"),
    @views.picker_item("carbon", "Carbon"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.button("Styled", on_click=(), style=button_style, width=120.0),
      @views.text_field(
        "tokens",
        on_input=_value => (),
        placeholder="Styled field",
        style=field_style,
      ),
      @views.progress(0.5, style=progress_style, width=160.0),
      @views.slider(0.5, style=slider_style, width=160.0),
      @views.picker(
        items,
        selected="material",
        on_select=_value => (),
        style=picker_style,
      ),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=6, day=10),
        on_select=_value => (),
        style=date_style,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, button_bg))
  assert_true(has_solid_fill(draw, field_bg))
  assert_true(has_solid_fill(draw, progress_fg))
  assert_true(has_solid_fill(draw, slider_thumb))
  assert_true(has_solid_fill(draw, picker_bg))
  assert_true(has_solid_fill(draw, date_bg))
}

///|
test "feedback badge and validation views consume neutral core style contracts" {
  let feedback_info_fg = @core.Color::rgba(r=0.12, g=0.44, b=0.86)
  let feedback_info_bg = @core.Color::rgba(r=0.82, g=0.91, b=1.0)
  let feedback_success_fg = @core.Color::rgba(r=0.10, g=0.56, b=0.28)
  let feedback_success_bg = @core.Color::rgba(r=0.82, g=0.96, b=0.86)
  let feedback_danger_fg = @core.Color::rgba(r=0.86, g=0.12, b=0.24)
  let feedback_danger_bg = @core.Color::rgba(r=1.0, g=0.86, b=0.88)
  let neutral_tone : @core.ToneStyle = {
    foreground: @core.Color::rgba(r=0.24, g=0.27, b=0.32),
    background: @core.Color::rgba(r=0.94, g=0.95, b=0.97),
    border: @core.Color::rgba(r=0.70, g=0.72, b=0.76),
  }
  let info_tone : @core.ToneStyle = {
    foreground: feedback_info_fg,
    background: feedback_info_bg,
    border: @core.Color::rgba(r=0.46, g=0.68, b=0.92),
  }
  let success_tone : @core.ToneStyle = {
    foreground: feedback_success_fg,
    background: feedback_success_bg,
    border: @core.Color::rgba(r=0.40, g=0.76, b=0.48),
  }
  let warning_tone : @core.ToneStyle = {
    foreground: @core.Color::rgba(r=0.62, g=0.40, b=0.08),
    background: @core.Color::rgba(r=1.0, g=0.94, b=0.78),
    border: @core.Color::rgba(r=0.86, g=0.64, b=0.22),
  }
  let danger_tone : @core.ToneStyle = {
    foreground: feedback_danger_fg,
    background: feedback_danger_bg,
    border: @core.Color::rgba(r=0.92, g=0.48, b=0.54),
  }
  let feedback_style : @core.FeedbackStyle = {
    neutral: neutral_tone,
    info: info_tone,
    success: success_tone,
    warning: warning_tone,
    danger: danger_tone,
    radius: 11.0,
    padding: 9.0,
  }
  let badge_accent_bg = @core.Color::rgba(r=0.46, g=0.18, b=0.86)
  let badge_success_bg = @core.Color::rgba(r=0.08, g=0.58, b=0.28)
  let badge_danger_bg = @core.Color::rgba(r=0.78, g=0.10, b=0.20)
  let badge_style : @core.BadgeStyle = {
    neutral: neutral_tone,
    accent: {
      foreground: @core.Color::white(),
      background: badge_accent_bg,
      border: badge_accent_bg,
    },
    success: {
      foreground: @core.Color::white(),
      background: badge_success_bg,
      border: badge_success_bg,
    },
    warning: warning_tone,
    danger: {
      foreground: @core.Color::white(),
      background: badge_danger_bg,
      border: badge_danger_bg,
    },
    radius: 12.0,
    padding: 4.0,
  }
  let validation_fg = @core.Color::rgba(r=0.72, g=0.08, b=0.34)
  let validation_bg = @core.Color::rgba(r=1.0, g=0.88, b=0.94)
  let validation_style : @core.FormValidationStyle = {
    foreground: validation_fg,
    background: validation_bg,
    border: @core.Color::rgba(r=0.90, g=0.42, b=0.62),
    radius: 10.0,
    padding: 10.0,
  }
  let runtime = test_runtime(
    @views.column([
      @views.banner(
        "Styled banner",
        "Uses custom feedback tokens",
        tone=@views.FeedbackTone::Info,
        style=feedback_style,
      ),
      @views.inline_error(
        "Styled inline error",
        style=feedback_style,
        badge_style~,
      ),
      @views.progress_status(
        "Styled progress",
        value=0.48,
        tone=@views.FeedbackTone::Success,
        style=feedback_style,
        badge_style~,
        progress_style=@core.ProgressStyle::{
          foreground: @core.Color::gray(),
          background: @core.Color::rgba(r=0.18, g=0.18, b=0.20),
          radius: 4.0,
        },
      ),
      @views.row([
        @views.badge("Accent", tone=@views.BadgeTone::Accent, style=badge_style),
        @views.status_badge(
          "Passed",
          tone=@views.BadgeTone::Success,
          style=badge_style,
        ),
      ]),
      @views.form_validation_summary(
        summary=@core.FormValidationSummary::from_errors([
          { name: "email", message: "Email required" },
        ]),
        style=validation_style,
      ),
      @views.form_error("Standalone validation", style=validation_style),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, feedback_info_bg))
  assert_true(has_solid_fill(draw, feedback_danger_bg))
  assert_true(has_solid_fill(draw, feedback_success_bg))
  assert_true(has_solid_fill(draw, feedback_success_fg))
  assert_true(has_solid_fill(draw, badge_accent_bg))
  assert_true(has_solid_fill(draw, badge_success_bg))
  assert_true(has_solid_fill(draw, badge_danger_bg))
  assert_true(has_solid_fill(draw, validation_bg))
  assert_true(has_text_color(draw, "Review required", validation_fg))
  assert_true(has_text_color(draw, "Standalone validation", validation_fg))
}

///|
test "view map lifts child message" {
  let seen = Ref("")
  let view = @views.button("Save", on_click="save").map(message => {
    "child:" + message
  })
  let runtime = @core.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => seen.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(seen.val, content="child:save")
}

///|
test "layout constructors produce layout through public runtime" {
  let runtime = test_runtime(
    @views.surface(
      @views.column(
        [
          @views.text("Title").key("title"),
          @views.row(
            [
              @views.text("A"),
              @views.spacer(min_length=12.0, weight=0.0),
              @views.text("B"),
            ],
            spacing=4.0,
          ),
        ],
        spacing=8.0,
      ),
      width=300.0,
      height=160.0,
      padding=12.0,
    ),
  )
  let layout = runtime.layout()
  inspect(layout.frame.size.width, content="640")
  inspect(layout.children.length() > 0, content="true")
}

///|
test "controls and modifiers expose semantics" {
  let runtime = test_runtime(
    @views.column([
      @views.toggle_switch("Enabled", true, on_change=_value => ()),
      @views.progress(0.6, width=120.0),
      @views.text("Tip").semantics_role(@core.SemanticsRole::Tooltip),
    ]),
  )
  let semantics = runtime.semantics()
  inspect(semantics.children.length() > 0, content="true")
}

///|
test "web view constructor exposes platform placement and events" {
  let seen = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.web_view(
      id="docs",
      url="https://wzzc-dev.github.io/MoUI/",
      width=Some(320.0),
      height=Some(180.0),
      title="MoUI docs",
      on_event=Some(event => {
        match event {
          @core.WebViewEvent::NavigationRequested(url) => "nav:" + url
          _ => "other"
        }
      }),
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => seen.val = message),
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="docs")
  inspect(
    frame.platform_views[0].url,
    content="https://wzzc-dev.github.io/MoUI/",
  )
  inspect(frame.commands.length(), content="1")
  guard runtime.semantics().role == @core.SemanticsRole::WebView else {
    fail("expected web view semantics role")
  }
  runtime.dispatch_event(
    @core.AppEvent::WebView(
      "docs",
      @core.WebViewEvent::NavigationRequested("https://example.com/"),
    ),
  )
  inspect(seen.val, content="nav:https://example.com/")
}

test "controlled and binding view facades build together" {
  let enabled = @core.State::new(false)
  let draft = @core.State::new("draft")
  let query = @core.State::new("query")
  let choice = @core.State::new("alpha")
  let selected_date = @core.State::new(
    @core.DateValue::new(year=2026, month=5, day=21),
  )
  let tabs = [
    @views.tab_item(route="alpha", label="Alpha", view=@views.text("Tab Alpha")),
    @views.tab_item(route="beta", label="Beta", view=@views.text("Tab Beta")),
  ]
  let picker_items = [
    @views.picker_item("alpha", "Alpha"),
    @views.picker_item("beta", "Beta"),
  ]
  let runtime = test_runtime(
    @views.column(
      [
        @views.text_field("Draft", on_input=_value => ()),
        @views.text_field_binding(draft.binding()),
        @views.searchbar(query="Query", on_input=_value => ()),
        @views.searchbar_binding(query=query.binding()),
        @views.checkbox("Enabled", checked=enabled.get(), on_change=_value => ()),
        @views.checkbox_binding("Enabled binding", checked=enabled.binding()),
        @views.toggle("Toggle", enabled.get(), on_change=_value => ()),
        @views.toggle_binding("Toggle binding", enabled.binding()),
        @views.toggle_switch_binding("Toggle switch binding", enabled.binding()),
        @views.radio("Radio", enabled.get(), on_change=_value => ()),
        @views.radio_binding("Radio binding", enabled.binding()),
        @views.picker(picker_items, selected=choice.get(), on_select=_value => {
          ()
        }),
        @views.picker_binding(picker_items, selected=choice.binding()),
        @views.datepicker(selected=selected_date.get(), on_select=_value => ()),
        @views.datepicker_binding(selected=selected_date.binding()),
        @views.tab_view("alpha", tabs, on_select=_value => ()),
        @views.tab_view_binding(choice.binding(), tabs, on_select=_value => ()),
        @views.rich_text_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Rich",
          width=240.0,
          height=96.0,
        ),
        @views.markdown_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Markdown",
          width=240.0,
          height=96.0,
        ),
      ],
      spacing=8.0,
    ),
  )
  inspect(runtime.layout().children.length() > 0, content="true")
}

///|
test "text field submit emits typed message" {
  let submitted = Ref(false)
  let runtime = @core.AppRuntime::new_view(
    root=@views.text_field(
      "hello",
      on_input=_value => false,
      on_submit=Some(true),
    ),
    size=@core.Size::new(width=260.0, height=80.0),
    on_message=Some(message => submitted.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(submitted.val, content="true")
}

///|
test "lazy list and grid build public views" {
  let items = [1, 2, 3, 4, 5, 6]
  let state = @core.ScrollState::new()
  let intent = @views.scroll_to_index(
    state,
    index=3,
    item_height=20.0,
    spacing=2.0,
  )
  let runtime = test_runtime(
    @views.column([
      @views.lazy_list(
        items,
        item => "item-\{item}",
        item => @views.text("Row \{item}"),
        viewport_height=80.0,
      ),
      @views.lazy_grid(
        items,
        item => "cell-\{item}",
        item => @views.text("Cell \{item}"),
        columns=2,
        viewport_height=120.0,
      ),
      @views.virtual_list(
        items,
        item => "virtual-\{item}",
        item => @views.text("Virtual \{item}"),
        state~,
        item_height=20.0,
        viewport_height=44.0,
        spacing=2.0,
        overscan=0,
      ),
    ]),
  )
  inspect(runtime.layout().children.length() > 0, content="true")
  inspect(intent.offset.y, content="66")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Virtual 4"))
  assert_true(has_text(commands, "Virtual 5"))
  assert_true(has_text(commands, "Virtual 6"))
  assert_false(has_text(commands, "Virtual 1"))
}

///|
test "sectioned list renders headers rows and empty state" {
  let sections = [
    @views.SectionListSection::new(id="a", title="Group A", items=[
      "Ada", "Alan",
    ]),
    @views.SectionListSection::new(id="b", title="Group B", items=["Grace"]),
  ]
  let runtime = test_runtime(
    @views.sectioned_list(
      sections,
      item => "person-" + item,
      item => @views.text(item),
      header=section => @views.text(section.title),
      item_height=20.0,
      header_height=20.0,
      viewport_height=96.0,
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Group A"))
  assert_true(has_text(commands, "Ada"))
  assert_true(has_text(commands, "Group B"))
  let empty_runtime = test_runtime(
    @views.sectioned_list(
      [],
      item => item,
      item => @views.text(item),
      empty=Some(@views.text("No sections")),
    ),
  )
  assert_true(has_text(empty_runtime.draw_commands(), "No sections"))
}

///|
test "custom layout facade participates in layout" {
  let runtime = test_runtime(
    @views.custom_layout(
      measure=constraints => {
        constraints.constrain(@core.Size::new(width=80.0, height=32.0))
      },
      paint=_frame => [],
      semantics_label="custom",
    ),
  )
  inspect(runtime.layout().frame.size.width, content="640")
}

///|
test "flow responsive grid and baseline rows place children" {
  let runtime = test_runtime(
    @views.column([
      @views.wrap(
        [
          @views.text("Chip A", width=72.0, height=20.0),
          @views.text("Chip B", width=72.0, height=20.0),
          @views.text("Chip C", width=72.0, height=20.0),
        ],
        width=160.0,
        spacing=4.0,
        row_spacing=6.0,
      ),
      @views.responsive_grid(
        [
          @views.text("Grid A", width=72.0, height=20.0),
          @views.text("Grid B", width=72.0, height=20.0),
          @views.text("Grid C", width=72.0, height=20.0),
        ],
        width=260.0,
        min_column_width=100.0,
        column_spacing=8.0,
      ),
      @views.baseline_form_rows(
        [
          @views.BaselineFormRow::new(
            label=@views.text("Label", width=80.0, height=24.0),
            control=@views.text_field(
              "Value",
              on_input=_value => (),
              width=140.0,
            ),
          ),
        ],
        width=260.0,
        label_width=90.0,
      ),
    ]),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Chip A"))
  assert_true(has_text(commands, "Chip C"))
  assert_true(has_text(commands, "Grid B"))
  assert_true(has_text(commands, "Label"))
  assert_true(has_text(commands, "Value"))
  guard text_frame(commands, "Grid A") is Some(grid_a) else {
    fail("expected Grid A text")
  }
  guard text_frame(commands, "Grid B") is Some(grid_b) else {
    fail("expected Grid B text")
  }
  guard text_frame(commands, "Grid C") is Some(grid_c) else {
    fail("expected Grid C text")
  }
  guard text_frame(commands, "Label") is Some(label) else {
    fail("expected Label text")
  }
  assert_true(grid_b.origin.x > grid_a.origin.x)
  assert_true(grid_c.origin.x < grid_b.origin.x)
  assert_true(grid_c.origin.y > grid_a.origin.y)
  assert_true(label.origin.y > grid_c.origin.y + grid_c.size.height)
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_color(
  commands : Array[@core.DrawCommand],
  text : String,
  color : @core.Color,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::DrawText({ text: value, color: value_color, .. }) &&
    value == text &&
    value_color == color
  })
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
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @core.AppRuntime, frame : @core.Rect) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
    ),
  )
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
fn full_frame_solid_fill_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    if is_full_frame_solid_fill(command) {
      count = count + 1
    }
  }
  count
}

///|
fn has_full_frame_solid_fill(
  commands : Array[@core.DrawCommand],
  alpha~ : Double,
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(
        { rect: { origin, size }, .. },
        @core.Brush::Solid({ r, g, b, a })
      ) =>
        origin.x == 0.0 &&
        origin.y == 0.0 &&
        size.width == 640.0 &&
        size.height == 480.0 &&
        r == 0.0 &&
        g == 0.0 &&
        b == 0.0 &&
        a == alpha
      _ => false
    }
  })
}

///|
fn has_solid_fill(
  commands : Array[@core.DrawCommand],
  color : @core.Color,
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(_, @core.Brush::Solid(value)) =>
        value == color
      _ => false
    }
  })
}

///|
fn is_full_frame_solid_fill(command : @core.DrawCommand) -> Bool {
  match command {
    @core.DrawCommand::FillRoundedRectBrush(
      { rect: { origin, size }, .. },
      @core.Brush::Solid(_)
    ) =>
      origin.x == 0.0 &&
      origin.y == 0.0 &&
      size.width == 640.0 &&
      size.height == 480.0
    _ => false
  }
}

///|
fn find_semantics_label(
  node : @core.SemanticsNode,
  label : String,
) -> @core.SemanticsNode? {
  if node.label == label {
    Some(node)
  } else {
    for child in node.children {
      match find_semantics_label(child, label) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}
