///|
fn test_label(text : String, key? : String) -> ViewSpec {
  let spec = ViewSpec::TextSpec({
    key: None,
    text,
    size: Size::new(width=80.0, height=20.0),
    font: FontSpec::new(size=16.0, weight=500),
    color: Color::black(),
  })
  match key {
    Some(key) => spec.key(key)
    None => spec
  }
}

///|
fn test_text_field(
  value : Binding[String],
  on_submit? : (() -> Unit)? = None,
) -> ViewSpec {
  ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder: "Type",
    size: Size::new(width=120.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_submit,
  })
}

///|
fn test_tab_accepting_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=160.0, height=80.0),
    format: value => RichTextDocument::plain(value),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: true,
  })
}

///|
fn test_selection_highlight_color(commands : Array[DrawCommand]) -> Color? {
  for command in commands {
    match command {
      FillRect(_, color) => if color.a == 0.18 { return Some(color) }
      _ => ()
    }
  }
  None
}

///|
fn test_text_field_caret_rect(commands : Array[DrawCommand]) -> Rect? {
  for command in commands {
    match command {
      FillRect(rect, _) => if rect.size.width == 1.5 { return Some(rect) }
      _ => ()
    }
  }
  None
}

///|
fn test_draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn layout_spec(spec : ViewSpec, bounds : Rect) -> LayoutResult {
  mount_view_spec(spec).place(bounds).to_layout_result()
}

///|
fn layout_spec_with_text_system(
  spec : ViewSpec,
  bounds : Rect,
  text_system~ : TextSystem,
) -> LayoutResult {
  mount_view_spec(spec)
  .place_with_text_system(bounds, text_system~)
  .to_layout_result()
}

///|
fn ElementNode::measure(
  self : ElementNode,
  constraints : Constraints,
) -> MeasuredNode {
  self.measure_with_text_system(constraints, text_system=TextSystem::fallback())
}

///|
fn ElementNode::place(self : ElementNode, bounds : Rect) -> PlacedNode {
  self.place_with_text_system(bounds, text_system=TextSystem::fallback())
}

///|
fn ElementNode::render(self : ElementNode, bounds : Rect) -> RenderNode {
  self.render_with_environment(
    self.place(bounds),
    None,
    RenderEnvironment::from_environment(Environment::default()),
  )
}

///|
fn ElementTree::measure(
  self : ElementTree,
  constraints : Constraints,
) -> MeasuredNode {
  self.root.measure(constraints)
}

///|
fn ElementNode::find_keyed(self : ElementNode, key : String) -> ElementId? {
  if self.key == Some(Key::new(key)) {
    Some(self.id)
  } else {
    for child in self.children {
      match child.find_keyed(key) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementTree::find_keyed(self : ElementTree, key : String) -> ElementId? {
  self.root.find_keyed(key)
}

///|
fn reconcile_element(old : ElementNode, next_spec : ViewSpec) -> ElementNode {
  reconcile_element_for_runtime(old, next_spec, None, 1).node
}

///|
fn ElementNode::hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> HitTestResult {
  let path : Array[HitTestEntry] = []
  if self.append_hit_test_path(point, render, path) {
    { path, }
  } else {
    { path: [] }
  }
}

///|
fn ElementNode::append_hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
  path : Array[HitTestEntry],
) -> Bool {
  if !render.frame.contains(point) {
    false
  } else {
    path.push({
      element_id: self.id,
      local_position: Point::new(
        x=point.x - render.frame.origin.x,
        y=point.y - render.frame.origin.y,
      ),
      frame: render.frame,
    })
    let mut index = self.children.length() - 1
    while index >= 0 {
      if index < render.children.length() &&
        self.children[index].append_hit_test_path(
          point,
          render.children[index],
          path,
        ) {
        return true
      }
      index = index - 1
    }
    true
  }
}

///|
fn AppRuntime::new_spec(
  root~ : ViewSpec,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  {
    state: RuntimeState::new_spec(root~, size~, environment~),
    program_runtime_snapshot_fn: () => ProgramRuntimeSnapshot::empty(),
    destroy_program_runtime_fn: () => (),
  }
}

///|
fn AppRuntime::set_root_spec(self : AppRuntime, root : ViewSpec) -> Unit {
  self.state.set_root_spec(root)
}

///|
fn RuntimeState::set_root_spec(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions()
  self.root_spec = root
  self.rebuild()
  self.needs_redraw = true
}

///|
fn RuntimeState::mount(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectUnmounted,
  )
  let mounted = mount_view_spec_for_runtime(root, Some(self), 1)
  self.root_spec = root
  self.element_tree = ElementTree::new(mounted.node)
  self.next_element_id = mounted.next_id
  self.focused_element = None
  self.active_pointer_capture = None
  self.needs_rebuild = false
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
  self.mark_dirty(self.element_tree.id())
  self.layout_pass()
}

///|
fn ViewSpec::key(self : ViewSpec, value : String) -> ViewSpec {
  self.with_key(Key::new(value))
}

///|
fn ViewSpec::background(self : ViewSpec, color : Color) -> ViewSpec {
  self.background_brush(Brush::solid(color))
}

///|
fn ViewSpec::opacity(self : ViewSpec, opacity : Double) -> ViewSpec {
  self.modified(OpacityModifier(opacity))
}

///|
fn ViewSpec::clip(self : ViewSpec) -> ViewSpec {
  self.modified(ClipModifier)
}

///|
fn ViewSpec::focusable(self : ViewSpec, focusable? : Bool = true) -> ViewSpec {
  self.modified(FocusableModifier(focusable))
}

///|
fn ViewSpec::focus_trap(self : ViewSpec, enabled? : Bool = true) -> ViewSpec {
  self.modified(FocusTrapModifier(enabled))
}

///|
fn ViewSpec::keyboard_shortcut(
  self : ViewSpec,
  shortcut : KeyboardShortcut,
) -> ViewSpec {
  self.modified(KeyboardShortcutModifier(shortcut))
}

///|
fn ViewSpec::layout_priority(self : ViewSpec, priority : Double) -> ViewSpec {
  self.modified(LayoutPriorityModifier(priority))
}

///|
fn ViewSpec::align(
  self : ViewSpec,
  alignment? : Alignment = Alignment::center(),
) -> ViewSpec {
  self.modified(AlignModifier(alignment))
}

///|
fn ViewSpec::padding(self : ViewSpec, value : Double) -> ViewSpec {
  self.modified(PaddingModifier(Insets::all(value)))
}

///|
fn ViewSpec::frame(
  self : ViewSpec,
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> ViewSpec {
  self.modified(
    FrameModifier({
      width,
      height,
      min_width,
      min_height,
      max_width,
      max_height,
    }),
  )
}

///|
fn ViewSpec::custom(
  measure~ : (Constraints) -> Size,
  paint~ : (Rect) -> Array[DrawCommand],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomSpec({ key: None, measure, paint, semantics_role, semantics_label })
}

///|
fn ViewSpec::custom_layout(
  children~ : Array[ViewSpec],
  measure~ : (CustomLayoutContext) -> Size,
  place~ : (CustomPlacementContext) -> Array[Rect],
  paint? : (Rect) -> Array[DrawCommand] = _frame => [],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomLayoutSpec({
    key: None,
    children,
    cache: CustomLayoutCache::new(),
    measure,
    place,
    paint,
    semantics_role,
    semantics_label,
  })
}
