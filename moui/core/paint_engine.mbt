///|
fn aligned_rect(
  bounds : Rect,
  child_size : Size,
  alignment : Alignment,
) -> Rect {
  let width = min_double(bounds.size.width, child_size.width)
  let height = min_double(bounds.size.height, child_size.height)
  let dx = max_double(0.0, bounds.size.width - width) *
    (alignment.x + 1.0) /
    2.0
  let dy = max_double(0.0, bounds.size.height - height) *
    (alignment.y + 1.0) /
    2.0
  Rect::new(x=bounds.origin.x + dx, y=bounds.origin.y + dy, width~, height~)
}

///|
fn element_hit_testable(spec : ViewSpec) -> Bool {
  match spec {
    ButtonSpec(_) => true
    TextFieldSpec(_) => true
    RichTextEditorSpec(_) => true
    CheckboxSpec(_) => true
    PickerSpec(_) => true
    DatePickerSpec(_) => true
    SearchBarSpec(_) => true
    SheetSpec(_) => true
    ContainerSpec(data) => data.background is Some(_)
    ModifiedSpec(data) =>
      data.modifier is BackgroundModifier(_) ||
      data.modifier is BorderModifier(_) ||
      data.modifier is ShadowModifier(_) ||
      data.modifier is OnTapModifier(_) ||
      data.modifier is OnLongPressModifier(_) ||
      data.modifier is OnDoubleTapModifier(_) ||
      data.modifier is OnDragModifier(_) ||
      data.modifier is OnDragWithFrameModifier(_) ||
      data.modifier is OnFileDropModifier(_) ||
      data.modifier is FocusableModifier(true)
    CustomSpec(_) | CustomLayoutSpec(_) => true
    ComponentSpec(_) => false
    _ => false
  }
}

///|
fn ElementNode::render_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  focused : ElementId?,
  environment : RenderEnvironment,
) -> RenderNode {
  let bounds = placed.frame
  if environment.matches_default_cache_key() &&
    !self.has_dirty_paint() &&
    !self.has_dirty_layout() &&
    self.render_cache.cached_render_frame == Some(bounds) &&
    self.render_cache.cached_render_focused == focused {
    match self.render_cache.cached_render {
      Some(render) => return render
      None => ()
    }
  }
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  let post_commands : Array[DrawCommand] = []
  let overlay_commands : Array[DrawCommand] = []
  match self.spec {
    EmptySpec => ()
    SpacerSpec(_) => ()
    TextSpec(data) =>
      commands.push(
        DrawText(
          TextRun::new(
            text=data.text,
            frame=bounds,
            font=environment_font(environment, data.font),
            color=environment_color(environment, data.color),
          ),
        ),
      )
    ButtonSpec(data) => {
      let background = match self.control.button_state {
        ButtonState::Normal => data.background
        ButtonState::Hovered => data.hovered_background
        ButtonState::Pressed => data.pressed_background
      }
      let rounded = RoundedRect::new(rect=bounds, radius=data.corner_radius)
      match data.shadow {
        Some(shadow) =>
          commands.push(
            DrawShadow(shadow_style_to_spec(shadow, bounds, data.corner_radius)),
          )
        None => ()
      }
      commands.push(FillRoundedRectBrush(rounded, background))
      match data.border {
        Some(border) =>
          if border.width > 0.0 {
            commands.push(
              StrokeRoundedRectBrush(rounded, border.brush, border.width),
            )
          }
        None => ()
      }
      let foreground = environment.foreground.unwrap_or(data.foreground)
      commands.push(
        DrawText(
          TextRun::new(
            text=data.text,
            frame=bounds,
            font=environment_font(environment, data.font),
            color=environment_color(environment, foreground),
          ),
        ),
      )
    }
    TextFieldSpec(data) =>
      append_text_field_commands(
        commands,
        overlay_commands,
        self,
        data,
        bounds,
        focused == Some(self.id),
        environment,
      )
    RichTextEditorSpec(data) =>
      append_rich_text_editor_commands(
        commands,
        children,
        post_commands,
        overlay_commands,
        self,
        data,
        bounds,
        focused == Some(self.id),
        environment,
      )
    ImageSpec(data) => {
      let frame = match data.size {
        Some(size) =>
          Rect::new(
            x=bounds.origin.x,
            y=bounds.origin.y,
            width=size.width,
            height=size.height,
          )
        None => bounds
      }
      let corner_radius = environment.corner_radius.unwrap_or(
        data.corner_radius,
      )
      if corner_radius > 0.0 {
        commands.push(PushClip(frame))
      }
      commands.push(
        DrawImage({
          source: data.source,
          frame,
          opacity: data.opacity,
          fit: data.fit,
        }),
      )
      if corner_radius > 0.0 {
        commands.push(PopClip)
      }
    }
    CheckboxSpec(data) =>
      append_checkbox_commands(commands, data, bounds, environment)
    PickerSpec(data) =>
      append_picker_commands(
        commands, overlay_commands, self, data, bounds, environment,
      )
    DatePickerSpec(data) =>
      append_datepicker_commands(
        commands, overlay_commands, self, data, bounds, environment,
      )
    SearchBarSpec(data) =>
      append_searchbar_commands(
        commands, overlay_commands, self, data, bounds, environment, focused,
      )
    SheetSpec(data) => {
      // Sheet background and shadow
      let rounded = RoundedRect::new(rect=bounds, radius=data.corner_radius)
      match data.shadow {
        Some(shadow) =>
          commands.push(
            DrawShadow(shadow_style_to_spec(shadow, bounds, data.corner_radius)),
          )
        None => ()
      }
      commands.push(FillRoundedRectBrush(rounded, data.background))
      // Render the content child
      if self.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    }
    FlexSpec(_) =>
      for index, child in self.children {
        if index < placed.children.length() {
          children.push(
            child.render_with_environment(
              placed.children[index],
              focused,
              environment,
            ),
          )
        }
      }
    PaddingSpec(_) =>
      if self.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    ContainerSpec(data) => {
      let frame = match data.size {
        Some(size) =>
          Rect::new(
            x=bounds.origin.x,
            y=bounds.origin.y,
            width=size.width,
            height=size.height,
          )
        None => bounds
      }
      match data.background {
        Some(brush) =>
          if environment.corner_radius.unwrap_or(data.corner_radius) > 0.0 {
            commands.push(
              FillRoundedRectBrush(
                RoundedRect::new(
                  rect=frame,
                  radius=environment.corner_radius.unwrap_or(data.corner_radius),
                ),
                brush,
              ),
            )
          } else {
            commands.push(
              FillRoundedRectBrush(RoundedRect::new(rect=frame), brush),
            )
          }
        None => ()
      }
      match data.shadow {
        Some(shadow) =>
          commands.push(
            DrawShadow(
              shadow_style_to_spec(
                shadow,
                frame,
                environment.corner_radius.unwrap_or(data.corner_radius),
              ),
            ),
          )
        None => ()
      }
      match data.border {
        Some(border) =>
          if border.width > 0.0 {
            commands.push(
              StrokeRoundedRectBrush(
                RoundedRect::new(
                  rect=frame,
                  radius=environment.corner_radius.unwrap_or(data.corner_radius),
                ),
                border.brush,
                border.width,
              ),
            )
          }
        None => ()
      }
      if self.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    }
    FrameSpec(_) =>
      if self.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    StackSpec(_) =>
      for child in self.children {
        let index = children.length()
        if index < placed.children.length() {
          children.push(
            child.render_with_environment(
              placed.children[index],
              focused,
              environment,
            ),
          )
        }
      }
    ScrollSpec(data) => {
      let viewport = data.viewport.unwrap_or(bounds.size)
      let clip = Rect::new(
        x=bounds.origin.x,
        y=bounds.origin.y,
        width=viewport.width,
        height=viewport.height,
      )
      commands.push(PushClip(clip))
      if self.children.length() > 0 && placed.children.length() > 0 {
        let child_placed = scroll_child_render_node(
          bounds,
          data,
          placed.children[0],
        )
        children.push(
          self.children[0].render_with_environment(
            child_placed,
            focused,
            environment,
          ),
        )
      }
      post_commands.push(PopClip)
    }
    GridSpec(_) =>
      for index, child in self.children {
        if index < placed.children.length() {
          children.push(
            child.render_with_environment(
              placed.children[index],
              focused,
              environment,
            ),
          )
        }
      }
    ListSpec(_) =>
      for index, child in self.children {
        if index < placed.children.length() {
          children.push(
            child.render_with_environment(
              placed.children[index],
              focused,
              environment,
            ),
          )
        }
      }
    ModifiedSpec(data) =>
      render_modified_node(
        self, data, placed, focused, environment, children, commands, post_commands,
      )
    CustomSpec(data) =>
      for command in (data.paint)(bounds) {
        commands.push(command)
      }
    CustomLayoutSpec(data) => {
      for command in (data.paint)(bounds) {
        commands.push(command)
      }
      for index, child in self.children {
        if index < placed.children.length() {
          children.push(
            child.render_with_environment(
              placed.children[index],
              focused,
              environment,
            ),
          )
        }
      }
    }
    ComponentSpec(_) =>
      if self.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
  }
  self.dirty.clear()
  self.render_cache.content_revision = self.render_cache.content_revision + 1
  let paint_bounds = render_node_paint_bounds(
    bounds,
    commands,
    children,
    post_commands,
    overlay_commands,
  )
  let render = {
    element_id: self.id,
    frame: bounds,
    children,
    hit_testable: element_hit_testable(self.spec),
    paint_bounds,
    content_revision: self.render_cache.content_revision,
    is_repaint_boundary: false,
    layer_cache_key: None,
    paint_commands: commands,
    post_paint_commands: post_commands,
    overlay_paint_commands: overlay_commands,
    cached_draw_commands: None,
    cached_overlay_draw_commands: None,
  }
  let render = match self.spec {
    ModifiedSpec({ modifier: RepaintBoundaryModifier, .. }) =>
      render.with_repaint_boundary_cache()
    _ => render
  }
  if environment.matches_default_cache_key() {
    self.render_cache.cached_render_frame = Some(bounds)
    self.render_cache.cached_render_focused = focused
    self.render_cache.cached_render = Some(render)
  }
  render
}

///|
fn scroll_child_render_frame(
  frame : Rect,
  data : ScrollViewSpec,
  placed_child : PlacedNode,
) -> Rect {
  let offset = scroll_view_offset(data)
  Rect::new(
    x=frame.origin.x - offset.x,
    y=frame.origin.y - offset.y,
    width=placed_child.frame.size.width,
    height=placed_child.frame.size.height,
  )
}

///|
fn scroll_child_render_node(
  frame : Rect,
  data : ScrollViewSpec,
  placed_child : PlacedNode,
) -> PlacedNode {
  let target = scroll_child_render_frame(frame, data, placed_child)
  let dx = target.origin.x - placed_child.frame.origin.x
  let dy = target.origin.y - placed_child.frame.origin.y
  translate_placed_node(placed_child, dx~, dy~)
}

///|
fn translate_placed_node(
  node : PlacedNode,
  dx~ : Double,
  dy~ : Double,
) -> PlacedNode {
  {
    ..node,
    frame: Rect::new(
      x=node.frame.origin.x + dx,
      y=node.frame.origin.y + dy,
      width=node.frame.size.width,
      height=node.frame.size.height,
    ),
    children: node.children.map(child => translate_placed_node(child, dx~, dy~)),
  }
}

///|
fn render_node_paint_bounds(
  frame : Rect,
  commands : Array[DrawCommand],
  children : Array[RenderNode],
  post_commands : Array[DrawCommand],
  overlay_commands : Array[DrawCommand],
) -> Rect {
  let mut bounds : Rect? = Some(frame)
  for command in commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  for child in children {
    bounds = optional_rect_union(bounds, Some(child.paint_bounds))
  }
  for command in post_commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  for command in overlay_commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  match bounds {
    Some(rect) => rect
    None => frame
  }
}
