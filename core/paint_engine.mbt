///|
priv struct RenderEnvironment {
  font : FontSpec?
  foreground : Color?
  corner_radius : Double?
  enabled : Bool
}

///|
fn RenderEnvironment::default() -> RenderEnvironment {
  { font: None, foreground: None, corner_radius: None, enabled: true }
}

///|
pub fn ElementNode::render(self : ElementNode, bounds : Rect) -> RenderNode {
  self.render_with_focus(bounds, None)
}

///|
fn ElementNode::render_with_focus(
  self : ElementNode,
  bounds : Rect,
  focused : ElementId?,
) -> RenderNode {
  self.render_with_environment(bounds, focused, RenderEnvironment::default())
}

///|
fn ElementNode::render_with_environment(
  self : ElementNode,
  bounds : Rect,
  focused : ElementId?,
  environment : RenderEnvironment,
) -> RenderNode {
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
            font=environment.font.unwrap_or(data.font),
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
      let foreground = match self.button_state {
        ButtonState::Pressed => Color::white()
        ButtonState::Normal | ButtonState::Hovered =>
          environment.foreground.unwrap_or(data.foreground)
      }
      commands.push(
        DrawText(
          TextRun::new(
            text=data.text,
            frame=bounds,
            font=environment.font.unwrap_or(data.font),
            color=foreground,
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
        DrawImage({ source: data.source, frame, opacity: data.opacity }),
      )
      if corner_radius > 0.0 {
        commands.push(PopClip)
      }
    }
    CheckboxSpec(data) =>
      append_checkbox_commands(commands, data, bounds, environment)
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
            bounds.offset(dx=-data.offset.x, dy=-data.offset.y),
            focused,
            environment,
          ),
        )
      }
      commands.push(PopClip)
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
  }
  self.dirty.clear()
  {
    element_id: self.id,
    frame: bounds,
    children,
    hit_testable: element_hit_testable(self.spec),
    paint_commands: commands,
    post_paint_commands: post_commands,
  }
}

///|
fn environment_color(
  environment : RenderEnvironment,
  fallback : Color,
) -> Color {
  let color = environment.foreground.unwrap_or(fallback)
  if environment.enabled {
    color
  } else {
    color.multiply_alpha(0.7)
  }
}

///|
fn render_modified_node(
  element : ElementNode,
  data : ModifiedViewSpec,
  bounds : Rect,
  focused : ElementId?,
  environment : RenderEnvironment,
  children : Array[RenderNode],
  commands : Array[DrawCommand],
  post_commands : Array[DrawCommand],
) -> Unit {
  match data.modifier {
    PaddingModifier(insets) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds.inset(insets),
            focused,
            environment,
          ),
        )
      }
    FrameModifier(frame) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            frame_rect_for_modifier(frame, bounds),
            focused,
            environment,
          ),
        )
      }
    BackgroundModifier(color) => {
      let radius = environment.corner_radius.unwrap_or(0.0)
      if radius > 0.0 {
        commands.push(
          FillRoundedRectBrush(RoundedRect::new(rect=bounds, radius~), color),
        )
      } else {
        commands.push(
          FillRoundedRectBrush(RoundedRect::new(rect=bounds), color),
        )
      }
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
    }
    ForegroundModifier(color) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(bounds, focused, {
            ..environment,
            foreground: Some(color),
          }),
        )
      }
    FontModifier(font) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(bounds, focused, {
            ..environment,
            font: Some(font),
          }),
        )
      }
    CornerRadiusModifier(radius) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(bounds, focused, {
            ..environment,
            corner_radius: Some(radius),
          }),
        )
      }
    OpacityModifier(opacity) => {
      commands.push(PushOpacity(opacity))
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
      post_commands.push(PopOpacity)
    }
    ShadowModifier(style) => {
      commands.push(
        DrawShadow(
          shadow_style_to_spec(
            style,
            bounds,
            environment.corner_radius.unwrap_or(0.0),
          ),
        ),
      )
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
    }
    BorderModifier(style) => {
      let radius = environment.corner_radius.unwrap_or(0.0)
      if style.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(
            RoundedRect::new(rect=bounds, radius~),
            style.brush,
            style.width,
          ),
        )
      }
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
    }
    OffsetModifier(dx, dy) => {
      let child_bounds = bounds.offset(dx~, dy~)
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            child_bounds, focused, environment,
          ),
        )
      }
    }
    ClipModifier => {
      commands.push(PushClip(bounds))
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
      post_commands.push(PopClip)
    }
    ScaleModifier(sx, sy) => {
      commands.push(PushTransform(Transform2D::scale(sx~, sy~)))
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
      post_commands.push(PopTransform)
    }
    DisabledModifier(disabled) => {
      let child_environment = { ..environment, enabled: !disabled }
      if disabled {
        commands.push(PushOpacity(0.42))
      }
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, child_environment,
          ),
        )
      }
      if disabled {
        post_commands.push(PopOpacity)
      }
    }
    AccessibilityLabelModifier(_)
    | SemanticsRoleModifier(_)
    | FocusableModifier(_)
    | OnTapModifier(_)
    | KeyboardShortcutModifier(_)
    | FlexibleModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            bounds, focused, environment,
          ),
        )
      }
    AlignModifier(alignment) =>
      if element.children.length() > 0 {
        let child_bounds = aligned_rect(
          bounds,
          element.children[0].intrinsic_size(),
          alignment,
        )
        children.push(
          element.children[0].render_with_environment(
            child_bounds, focused, environment,
          ),
        )
      }
    AspectRatioModifier(ratio) =>
      if element.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            aspect_ratio_rect(bounds, ratio),
            focused,
            environment,
          ),
        )
      }
  }
}

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
pub fn ElementNode::intrinsic_size(self : ElementNode) -> Size {
  match self.spec {
    EmptySpec => Size::new(width=0.0, height=0.0)
    TextSpec(data) => data.size
    ButtonSpec(data) => data.size
    TextFieldSpec(data) => data.size
    ImageSpec(data) => data.size.unwrap_or(Size::new(width=0.0, height=0.0))
    CheckboxSpec(data) => checkbox_intrinsic_size(data)
    SpacerSpec(data) =>
      if data.weight > 0.0 {
        Size::new(width=0.0, height=0.0)
      } else {
        Size::new(width=data.min_length, height=data.min_length)
      }
    PaddingSpec(data) =>
      if self.children.length() > 0 {
        self.children[0].intrinsic_size().inflate(data.insets)
      } else {
        Size::new(width=0.0, height=0.0).inflate(data.insets)
      }
    ContainerSpec(data) =>
      match data.size {
        Some(size) => size
        None =>
          if self.children.length() > 0 {
            self.children[0].intrinsic_size()
          } else {
            Size::new(width=0.0, height=0.0)
          }
      }
    FlexSpec(data) => measure_flex_sizes(data.axis, data.spacing, self.children)
    FrameSpec(data) => {
      let child_size = if self.children.length() > 0 {
        self.children[0].intrinsic_size()
      } else {
        Size::new(width=0.0, height=0.0)
      }
      resolve_frame_size(data, child_size)
    }
    StackSpec(_) => measure_stack_size(self.children)
    ScrollSpec(data) =>
      match data.viewport {
        Some(size) => size
        None =>
          if self.children.length() > 0 {
            self.children[0].intrinsic_size()
          } else {
            Size::new(width=0.0, height=0.0)
          }
      }
    GridSpec(data) =>
      measure_grid_size(
        data.columns,
        data.row_spacing,
        data.column_spacing,
        self.children,
      )
    ListSpec(data) => measure_list_size(data.spacing, self.children)
    ModifiedSpec(data) => modified_intrinsic_size(data.modifier, self.children)
    CustomSpec(data) => (data.measure)(Constraints::unbounded())
  }
}

///|
fn element_hit_testable(spec : ViewSpec) -> Bool {
  match spec {
    ButtonSpec(_) => true
    TextFieldSpec(_) => true
    CheckboxSpec(_) => true
    ContainerSpec(data) => data.background is Some(_)
    ModifiedSpec(data) =>
      data.modifier is BackgroundModifier(_) ||
      data.modifier is BorderModifier(_) ||
      data.modifier is ShadowModifier(_) ||
      data.modifier is OnTapModifier(_) ||
      data.modifier is FocusableModifier(true)
    CustomSpec(_) => true
    _ => false
  }
}

///|
pub fn ElementNode::render_focused(
  self : ElementNode,
  bounds : Rect,
  focused~ : ElementId?,
) -> RenderNode {
  self.render_with_focus(bounds, focused)
}

///|
fn checkbox_intrinsic_size(data : CheckboxViewSpec) -> Size {
  let spacing = 8.0
  let label_width = text_length(data.label).to_double() * data.font.size * 0.58
  Size::new(
    width=data.size.width + spacing + label_width,
    height=max_double(data.size.height, data.font.size * 1.25),
  )
}

///|
fn append_checkbox_commands(
  commands : Array[DrawCommand],
  data : CheckboxViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
) -> Unit {
  let box_side = data.size.width
  let box_y = frame.origin.y +
    max_double(0.0, (frame.size.height - box_side) / 2.0)
  let box_rect = Rect::new(
    x=frame.origin.x,
    y=box_y,
    width=box_side,
    height=box_side,
  )
  let box = RoundedRect::new(rect=box_rect, radius=4.0)
  if data.checked.get() {
    commands.push(FillRoundedRect(box, data.check_color))
    commands.push(
      DrawText(
        TextRun::new(
          text="✓",
          frame=box_rect,
          font=FontSpec::new(size=box_side * 0.78, weight=700),
          color=Color::white(),
        ),
      ),
    )
  } else {
    commands.push(StrokeRoundedRect(box, data.check_color, 2.0))
  }
  commands.push(
    DrawText(
      TextRun::new(
        text=data.label,
        frame=Rect::new(
          x=frame.origin.x + box_side + 8.0,
          y=frame.origin.y,
          width=max_double(0.0, frame.size.width - box_side - 8.0),
          height=frame.size.height,
        ),
        font=environment.font.unwrap_or(data.font),
        color=environment.foreground.unwrap_or(data.foreground),
        align=TextAlign::TextStart,
      ),
    ),
  )
}

///|
fn append_text_field_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : TextFieldViewSpec,
  frame : Rect,
  focused : Bool,
  environment : RenderEnvironment,
) -> Unit {
  let border = if focused { data.focused_border } else { data.border }
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  if data.corner_radius > 0.0 {
    commands.push(FillRoundedRectBrush(rounded, data.background))
  } else {
    commands.push(FillRoundedRectBrush(rounded, data.background))
  }
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }
  let text = data.value.get()
  let display_text = text_with_composition(text, element, focused)
  let display = if display_text == "" { data.placeholder } else { display_text }
  let color = if text == "" {
    data.placeholder_color
  } else {
    environment.foreground.unwrap_or(data.foreground)
  }
  let text_frame = frame.inset(Insets::symmetric(horizontal=10.0, vertical=4.0))
  commands.push(
    DrawText(
      TextRun::new(
        text=display,
        frame=text_frame,
        font=environment.font.unwrap_or(data.font),
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let font = environment.font.unwrap_or(data.font)
    let layout = measure_text_layout(
      TextLayoutInput::new(text~, font~, max_width=text_frame.size.width),
    )
    let caret = clamp_int(element.caret, 0, layout.caret_positions.length() - 1)
    let cursor_x = text_frame.origin.x + layout.caret_positions[caret]
    let cursor = Rect::new(
      x=cursor_x,
      y=text_frame.origin.y + 6.0,
      width=1.5,
      height=max_double(8.0, text_frame.size.height - 12.0),
    )
    commands.push(FillRect(cursor, data.cursor_color))
  }
}

///|
pub fn RenderNode::collect_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_draw_commands(commands)
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
}

///|
fn shadow_style_to_spec(
  style : ShadowStyle,
  rect : Rect,
  radius : Double,
) -> ShadowSpec {
  ShadowSpec::new(
    rect=RoundedRect::new(rect~, radius~),
    color=style.color,
    offset=style.offset,
    blur_radius=style.blur_radius,
    spread=style.spread,
  )
}

///|
pub fn RenderNode::to_layout_result(self : RenderNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}
