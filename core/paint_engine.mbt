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
  bounds : Rect,
  focused : ElementId?,
  environment : RenderEnvironment,
) -> RenderNode {
  if environment.matches_default_cache_key() &&
    !self.dirty.needs_paint &&
    !self.dirty.needs_layout &&
    self.cached_render_frame == Some(bounds) &&
    self.cached_render_focused == focused {
    match self.cached_render {
      Some(render) => return render
      None => ()
    }
  }
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  let post_commands : Array[DrawCommand] = []
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
      let background = match self.button_state {
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
        self,
        data,
        bounds,
        focused == Some(self.id),
        environment,
      )
    RichTextEditorSpec(data) =>
      append_rich_text_editor_commands(
        commands,
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
      append_picker_commands(commands, self, data, bounds, environment)
    DatePickerSpec(data) =>
      append_datepicker_commands(commands, self, data, bounds, environment)
    SearchBarSpec(data) =>
      append_searchbar_commands(
        commands, self, data, bounds, environment, focused,
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
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            bounds.inset(Insets::symmetric(horizontal=16.0, vertical=16.0)),
            focused,
            environment,
          ),
        )
      }
    }
    FlexSpec(data) => {
      let frames = flex_child_frames(
        data.axis,
        data.spacing,
        data.main_axis_alignment,
        data.cross_axis_alignment,
        self.children,
        bounds,
      )
      for index, child in self.children {
        children.push(
          child.render_with_environment(frames[index], focused, environment),
        )
      }
    }
    PaddingSpec(data) => {
      let child_frame = bounds.inset(data.insets)
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            child_frame, focused, environment,
          ),
        )
      }
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
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(frame, focused, environment),
        )
      }
    }
    FrameSpec(data) => {
      let frame = frame_rect_for_spec(data, bounds)
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(frame, focused, environment),
        )
      }
    }
    StackSpec(_) =>
      for child in self.children {
        children.push(
          child.render_with_environment(bounds, focused, environment),
        )
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
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(
            scroll_child_frame(bounds, data, self.children[0]),
            focused,
            environment,
          ),
        )
      }
      post_commands.push(PopClip)
    }
    GridSpec(data) => {
      let frames = grid_child_frames(
        data.columns,
        data.row_spacing,
        data.column_spacing,
        self.children,
        bounds,
      )
      for index, child in self.children {
        children.push(
          child.render_with_environment(frames[index], focused, environment),
        )
      }
    }
    ListSpec(data) => {
      let frames = list_child_frames(data.spacing, self.children, bounds)
      for index, child in self.children {
        children.push(
          child.render_with_environment(frames[index], focused, environment),
        )
      }
    }
    ModifiedSpec(data) =>
      render_modified_node(
        self, data, bounds, focused, environment, children, commands, post_commands,
      )
    CustomSpec(data) =>
      for command in (data.paint)(bounds) {
        commands.push(command)
      }
    CustomLayoutSpec(data) => {
      for command in (data.paint)(bounds) {
        commands.push(command)
      }
      let child_frames = (data.place)({
        frame: bounds,
        measured_size: bounds.size,
        child_sizes: self.children.map(child => child.intrinsic_size()),
        child_baselines: self.children.map(child => {
          child.first_baseline(text_system=environment.text_system)
        }),
        child_priorities: self.children.map(child => child.layout_priority()),
        child_alignment_guides: custom_alignment_guides(
          self.children.map(child => child.intrinsic_size()),
          self.children.map(child => {
            child.first_baseline(text_system=environment.text_system)
          }),
        ),
        cache: data.cache,
        cache_key: custom_layout_cache_key(
          self.spec,
          self.children.map(child => child.intrinsic_size()),
        ),
        layout_direction: environment.layout_direction,
        safe_area: Insets::symmetric(),
        viewport: Some(bounds.size),
      })
      for index, child in self.children {
        if index < child_frames.length() {
          children.push(
            child.render_with_environment(
              child_frames[index],
              focused,
              environment,
            ),
          )
        }
      }
    }
    ComponentSpec(_) =>
      if self.children.length() > 0 {
        children.push(
          self.children[0].render_with_environment(bounds, focused, environment),
        )
      }
  }
  self.dirty.clear()
  let render = {
    element_id: self.id,
    frame: bounds,
    children,
    hit_testable: element_hit_testable(self.spec),
    paint_commands: commands,
    post_paint_commands: post_commands,
  }
  if environment.matches_default_cache_key() {
    self.cached_render_frame = Some(bounds)
    self.cached_render_focused = focused
    self.cached_render = Some(render)
  }
  render
}
