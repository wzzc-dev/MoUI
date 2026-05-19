///|
test "views construct layout" {
  let root = @views.padding(
    @views.column([@views.text("A"), @views.button("B")], spacing=8.0),
    4.0,
  )
  let layout = @core.layout_spec(
    root,
    @core.Rect::new(x=0.0, y=0.0, width=200.0, height=120.0),
  )
  inspect(layout.children.length(), content="1")
}

///|
test "button on click callback" {
  let clicks = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@views.button("Tap", on_click=() => clicks.val = clicks.val + 1),
    size=@core.Size::new(width=100.0, height=50.0),
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
  inspect(clicks.val, content="1")
}

///|
test "image view builds draw image" {
  let runtime = @core.AppRuntime::new_spec(
    root=@views.image("logo.png", width=24.0, height=24.0),
    size=@core.Size::new(width=40.0, height=40.0),
  )
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawImage({ source: "logo.png", .. })
    }),
  )
}

///|
test "checkbox view toggles binding" {
  let checked = @core.State::new(false)
  let runtime = @core.AppRuntime::new_spec(
    root=@views.checkbox("Done", checked=checked.binding()),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(checked.get(), content="true")
}

///|
test "label paints text" {
  let runtime = @core.AppRuntime::new_spec(
    root=@views.text("Title"),
    size=@core.Size::new(width=160.0, height=32.0),
  )
  guard runtime.draw_commands()
    is [
      @core.DrawCommand::Clear(_),
      @core.DrawCommand::DrawText({ text: "Title", color, .. }),
    ] else {
    fail("expected label DrawText")
  }
  assert_true(color == @core.Color::black())
}

///|
test "button paints background and text command" {
  let runtime = @core.AppRuntime::new_spec(
    root=@views.button("Tap"),
    size=@core.Size::new(width=180.0, height=44.0),
  )
  guard runtime.draw_commands()
    is [
      @core.DrawCommand::Clear(_),
      @core.DrawCommand::DrawShadow(_),
      @core.DrawCommand::FillRoundedRectBrush(_, _),
      @core.DrawCommand::DrawText({ text: "Tap", frame, .. }),
    ] else {
    fail("expected button rect and DrawText")
  }
  assert_true(frame == @core.Rect::new(x=0.0, y=0.0, width=180.0, height=44.0))
}

///|
test "button accepts visual styles" {
  let style = @core.ButtonStyle::outline(theme=@core.Theme::light())
  let spec = @views.button("Outline", style~)
  guard spec is @core.ViewSpec::ButtonSpec({ corner_radius: 8.0, .. }) else {
    fail("expected styled button spec")
  }
}

///|
test "modifiers build styled view specs" {
  let spec = @views.text("Styled")
    .font(@core.FontSpec::new(size=20.0, weight=700))
    .foreground(@core.Color::blue())
    .key("title")
  guard spec
    is @core.ViewSpec::ModifiedSpec({ key: Some({ value: "title" }), .. }) else {
    fail("expected keyed modified spec")
  }
  let runtime = @core.AppRuntime::new_spec(
    root=spec,
    size=@core.Size::new(width=120.0, height=32.0),
  )
  guard runtime.draw_commands()
    is [
      _,
      @core.DrawCommand::DrawText(
        { text: "Styled", font: { size: 20.0, weight: 700, .. }, color, .. }
      ),
    ] else {
    fail("expected styled draw text")
  }
  assert_true(color == @core.Color::blue())
}

///|
test "flex alignment modifiers build view specs" {
  let spec = @views.row([@views.text("A")])
    .main_axis_alignment(@core.MainAxisAlignment::MainCenter)
    .cross_axis_alignment(@core.CrossAxisAlignment::CrossEnd)
  guard spec
    is @core.ViewSpec::FlexSpec(
      {
        main_axis_alignment: @core.MainAxisAlignment::MainCenter,
        cross_axis_alignment: @core.CrossAxisAlignment::CrossEnd,
        ..,
      }
    ) else {
    fail("expected flex alignment")
  }
}

///|
test "theme modifier feeds environment style into view spec" {
  let theme = @views.theme(
    foreground=@core.Color::blue(),
    background=@core.Color::gray(),
    corner_radius=10.0,
  )
  let spec = @views.button("Themed").theme(theme)
  let runtime = @core.AppRuntime::new_spec(
    root=spec,
    size=@core.Size::new(width=180.0, height=44.0),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::FillRoundedRectBrush(_, brush) =>
          brush == @core.Brush::solid(@core.Color::gray())
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text: "Themed", color, .. }) =>
          color == @core.Color::blue()
        _ => false
      }
    }),
  )
}

///|
test "modifier order changes background frame" {
  let padded_background = @views.text("A")
    .padding(8.0)
    .background(@core.Color::gray())
  let background_padded = @views.text("A")
    .background(@core.Color::gray())
    .padding(8.0)
  let first = @core.AppRuntime::new_spec(
    root=padded_background,
    size=@core.Size::new(width=80.0, height=40.0),
  ).draw_commands()
  let second = @core.AppRuntime::new_spec(
    root=background_padded,
    size=@core.Size::new(width=80.0, height=40.0),
  ).draw_commands()
  guard first
    is [
      _,
      @core.DrawCommand::FillRoundedRectBrush({ rect: first_rect, .. }, _),
      ..,
    ] else {
    fail("expected first background")
  }
  guard second
    is [
      _,
      @core.DrawCommand::FillRoundedRectBrush({ rect: second_rect, .. }, _),
      ..,
    ] else {
    fail("expected second background")
  }
  assert_true(first_rect.size.width == 80.0)
  assert_true(second_rect.size.width == 64.0)
}

///|
test "visual modifiers emit wrapper commands in order" {
  let spec = @views.image(
      "logo.png",
      width=40.0,
      height=24.0,
      fit=@core.ImageFit::Cover,
    )
    .corner_radius(6.0)
    .clip()
    .opacity(0.6)
    .offset(dx=4.0, dy=3.0)
    .border(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::blue()),
        width=2.0,
      ),
    )
    .shadow(
      @core.ShadowStyle::new(
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.25),
      ),
    )
  let commands = @core.AppRuntime::new_spec(
    root=spec,
    size=@core.Size::new(width=80.0, height=48.0),
  ).draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, 2.0)
    }),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushOpacity(0.6)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_true(
    command_index(commands, "shadow") < command_index(commands, "border"),
  )
  assert_true(
    command_index(commands, "border") < command_index(commands, "opacity"),
  )
  assert_true(
    command_index(commands, "opacity") < command_index(commands, "clip"),
  )
  assert_true(
    command_index(commands, "clip") < command_index(commands, "image"),
  )
  assert_true(
    command_index(commands, "image") < command_index(commands, "pop_clip"),
  )
  assert_true(
    command_index(commands, "pop_clip") < command_index(commands, "pop_opacity"),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawImage(
        { frame: { origin: { x: 4.0, y: 3.0 }, .. }, .. }
      )
    }),
  )
}

///|
fn command_index(commands : Array[@core.DrawCommand], name : String) -> Int {
  for index, command in commands {
    let matched = match (name, command) {
      ("shadow", @core.DrawCommand::DrawShadow(_)) => true
      ("border", @core.DrawCommand::StrokeRoundedRectBrush(_, _, _)) => true
      ("opacity", @core.DrawCommand::PushOpacity(_)) => true
      ("clip", @core.DrawCommand::PushClip(_)) => true
      ("image", @core.DrawCommand::DrawImage(_)) => true
      ("pop_clip", @core.DrawCommand::PopClip) => true
      ("pop_opacity", @core.DrawCommand::PopOpacity) => true
      _ => false
    }
    if matched {
      return index
    }
  }
  -1
}

///|
test "theme helper selects dark token scheme" {
  let theme = @views.theme(scheme=@core.ColorScheme::Dark)
  assert_true(theme.scheme == @core.ColorScheme::Dark)
  assert_true(theme.background == theme.palette.background)
}

///|
test "container and spacer participate in layout" {
  let root = @views.column([
    @views.surface(
      @views.text("A"),
      width=120.0,
      height=40.0,
      background=@core.Color::gray(),
      corner_radius=8.0,
    ),
    @views.spacer(min_length=12.0),
  ]).spacing(6.0)
  let layout = @core.layout_spec(
    root,
    @core.Rect::new(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  inspect(layout.children.length(), content="2")
  inspect(layout.children[0].children[0].frame.size.width, content="120")
}

///|
test "frame helper constrains child layout" {
  let root = @views.frame(@views.text("A"), width=64.0, height=24.0)
  let layout = @core.layout_spec(
    root,
    @core.Rect::new(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  inspect(layout.children[0].frame.size.width, content="64")
  inspect(layout.children[0].frame.size.height, content="24")
}

///|
test "stack overlay and scroll helpers build advanced specs" {
  let spec = @views.overlay(@views.text("Base"), @views.text("Top"))
  guard spec is @core.ViewSpec::StackSpec({ children: [_, _], .. }) else {
    fail("expected stack spec")
  }
  let scroll = @views.scroll_view(
    @views.text("Long"),
    offset=@core.Point::new(x=0.0, y=8.0),
    width=80.0,
    height=40.0,
  )
  guard scroll
    is @core.ViewSpec::ScrollSpec(
      { viewport: Some({ width: 80.0, height: 40.0 }), .. }
    ) else {
    fail("expected scroll spec")
  }
}

///|
test "grid and list helpers build keyed collection specs" {
  let grid = @views.grid(
    [@views.text("A"), @views.text("B"), @views.text("C")],
    columns=2,
    row_spacing=4.0,
    column_spacing=8.0,
  )
  guard grid
    is @core.ViewSpec::GridSpec(
      { columns: 2, row_spacing: 4.0, column_spacing: 8.0, children, .. }
    ) else {
    fail("expected grid spec")
  }
  inspect(children.length(), content="3")
  let list = @views.list(
    [@views.text("One").key("one"), @views.text("Two").key("two")],
    spacing=6.0,
  )
  guard list
    is @core.ViewSpec::ListSpec({ spacing: 6.0, children: [first, _], .. }) else {
    fail("expected list spec")
  }
  guard first is @core.ViewSpec::TextSpec({ key: Some({ value: "one" }), .. }) else {
    fail("expected keyed list item")
  }
}

///|
test "text field constructs binding backed spec" {
  let state = @core.State::new("Draft")
  let submitted = Ref(false)
  let spec = @views.text_field(
    state.binding(),
    on_submit=Some(() => submitted.val = true),
    placeholder="New todo",
    width=220.0,
    height=40.0,
  )
  guard spec
    is @core.ViewSpec::TextFieldSpec(
      {
        placeholder: "New todo",
        size: { width: 220.0, height: 40.0 },
        value,
        ..,
      }
    ) else {
    fail("expected text field spec")
  }
  value.set("Changed")
  inspect(state.get(), content="Changed")
  ignore(submitted)
}

///|
test "text field accepts visual styles" {
  let state = @core.State::new("")
  let style = @core.TextFieldStyle::outline(theme=@core.Theme::dark())
  let spec = @views.text_field(state.binding(), style~)
  guard spec
    is @core.ViewSpec::TextFieldSpec(
      { focused_border: Some(focused_border), cursor_color, .. }
    ) else {
    fail("expected styled text field spec")
  }
  assert_true(focused_border.brush == @core.Brush::solid(cursor_color))
  inspect(focused_border.width, content="2")
}

///|
test "rich text editor constructs binding backed spec" {
  let state = @core.State::new("# Draft")
  let spec = @views.rich_text_editor(
    state.binding(),
    text => @core.RichTextDocument::plain(text),
    placeholder="Write notes",
    width=420.0,
    height=280.0,
  )
  guard spec
    is @core.ViewSpec::RichTextEditorSpec(
      {
        placeholder: "Write notes",
        size: { width: 420.0, height: 280.0 },
        value,
        ..,
      }
    ) else {
    fail("expected rich text editor spec")
  }
  value.set("Changed")
  inspect(state.get(), content="Changed")
}

///|
test "markdown editor wrapper composes rich text editor with visual styles" {
  let state = @core.State::new("")
  let style = @core.TextFieldStyle::outline(theme=@core.Theme::dark())
  let spec = @views.markdown_editor(
    state.binding(),
    text => @core.RichTextDocument::plain(text),
    style~,
  )
  guard spec
    is @core.ViewSpec::RichTextEditorSpec(
      {
        focused_border: Some(focused_border),
        cursor_color,
        placeholder_color,
        ..,
      }
    ) else {
    fail("expected styled rich text editor spec")
  }
  assert_true(focused_border.brush == @core.Brush::solid(cursor_color))
  assert_true(placeholder_color == @core.Theme::dark().palette.muted)
  inspect(focused_border.width, content="2")
}

///|
test "navigation stack selects current route" {
  let nav = @core.NavigationState::new(initial="controls")
  let spec = @views.navigation_stack(nav, [
    @views.navigation_destination(
      route="overview",
      view=@views.text("Overview"),
    ),
    @views.navigation_destination(
      route="controls",
      view=@views.text("Controls"),
    ),
  ])
  guard spec is @core.ViewSpec::TextSpec({ text: "Controls", .. }) else {
    fail("expected selected navigation destination")
  }
}

///|
test "lazy list windows visible rows" {
  let scroll = @core.ScrollState::new(offset=@core.Point::new(x=0.0, y=32.0))
  let items = ["One", "Two", "Three", "Four", "Five", "Six"]
  let spec = @views.lazy_list(
    items,
    item => item,
    item => @views.text(item, width=120.0, height=24.0),
    state=scroll,
    item_height=24.0,
    viewport_height=40.0,
    spacing=4.0,
  )
  guard spec is @core.ViewSpec::ListSpec({ children, .. }) else {
    fail("expected list spec")
  }
  assert_true(children.length() >= 2)
  assert_true(children.length() <= 4)
}

///|
test "dialog host wraps presented dialog" {
  let spec = @views.dialog_host(
    @views.text("Base"),
    dialog=Some(@views.text("Dialog")),
    presented=true,
  )
  guard spec is @core.ViewSpec::StackSpec({ children: [_, _], .. }) else {
    fail("expected stack host")
  }
}

///|
test "toggle radio progress and slider helpers build accessible specs" {
  let checked = @core.State::new(false)
  let value = @core.State::new(0.4)
  let toggle = @views.toggle_switch("Enabled", checked.binding())
  let radio = @views.radio("Choice", checked.binding())
  let progress = @views.progress(0.7, width=120.0)
  let slider = @views.slider(value.binding(), width=200.0)
  guard toggle
    is @core.ViewSpec::ModifiedSpec(
      {
        modifier: @core.ViewModifier::SemanticsRoleModifier(
          @core.SemanticsRole::Switch
        ),
        ..,
      }
    ) else {
    fail("expected toggle semantics wrapper")
  }
  guard radio
    is @core.ViewSpec::ModifiedSpec(
      {
        modifier: @core.ViewModifier::SemanticsRoleModifier(
          @core.SemanticsRole::Radio
        ),
        ..,
      }
    ) else {
    fail("expected radio semantics wrapper")
  }
  guard progress is @core.ViewSpec::CustomSpec(_) else {
    fail("expected progress custom view")
  }
  guard slider is @core.ViewSpec::CustomSpec(_) else {
    fail("expected slider custom view")
  }
}

///|
test "tab view selects content and updates binding" {
  let selected = @core.State::new("code")
  let spec = @views.tab_view(selected.binding(), [
    @views.tab_item(
      route="preview",
      label="Preview",
      view=@views.text("Preview pane"),
    ),
    @views.tab_item(route="code", label="Code", view=@views.text("Code pane")),
  ])
  let commands = @core.AppRuntime::new_spec(
    root=spec,
    size=@core.Size::new(width=260.0, height=120.0),
  ).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Code pane", .. })
    }),
  )
  guard spec is @core.ViewSpec::FlexSpec({ children: [tabs, _], .. }) else {
    fail("expected tab view column")
  }
  guard tabs is @core.ViewSpec::FlexSpec({ children: [first_tab, _], .. }) else {
    fail("expected tab row")
  }
  let runtime = @core.AppRuntime::new_spec(
    root=first_tab,
    size=@core.Size::new(width=112.0, height=36.0),
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
  inspect(selected.get(), content="preview")
}

///|
test "menu button and tooltip add presentation semantics" {
  let menu = @views.menu_button("More")
  guard menu
    is @core.ViewSpec::ModifiedSpec(
      {
        modifier: @core.ViewModifier::SemanticsRoleModifier(
          @core.SemanticsRole::Menu
        ),
        ..,
      }
    ) else {
    fail("expected menu semantics wrapper")
  }
  let tooltip = @views.tooltip(
    @views.text("Help"),
    "Keyboard: Meta+K",
    visible=true,
  )
  guard tooltip is @core.ViewSpec::StackSpec({ children: [_, overlay], .. }) else {
    fail("expected tooltip overlay")
  }
  let commands = @core.AppRuntime::new_spec(
    root=overlay,
    size=@core.Size::new(width=220.0, height=80.0),
  ).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Keyboard: Meta+K", .. })
    }),
  )
}

///|
test "layout helper constructors build modifier and custom specs" {
  let child = @views.text("A")
  guard @views.expanded(child, weight=2.0)
    is @core.ViewSpec::ModifiedSpec(
      { modifier: @core.ViewModifier::FlexibleModifier(2.0), .. }
    ) else {
    fail("expected flexible modifier")
  }
  guard @views.align(child, alignment=@core.Alignment::top_leading())
    is @core.ViewSpec::ModifiedSpec(
      { modifier: @core.ViewModifier::AlignModifier(_), .. }
    ) else {
    fail("expected align modifier")
  }
  guard @views.aspect_ratio(child, 1.5)
    is @core.ViewSpec::ModifiedSpec(
      { modifier: @core.ViewModifier::AspectRatioModifier(1.5), .. }
    ) else {
    fail("expected aspect ratio modifier")
  }
  guard @views.intrinsic_width(child)
    is @core.ViewSpec::ModifiedSpec(
      { modifier: @core.ViewModifier::IntrinsicWidthModifier, .. }
    ) else {
    fail("expected intrinsic width modifier")
  }
  guard @views.custom_layout(
      measure=constraints => {
        constraints.constrain(@core.Size::new(width=10.0, height=8.0))
      },
      paint=_frame => [],
      semantics_label="Custom",
    )
    is @core.ViewSpec::CustomSpec(_) else {
    fail("expected custom layout spec")
  }
}
