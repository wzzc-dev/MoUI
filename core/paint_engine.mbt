///|
priv struct RenderEnvironment {
  font : FontSpec?
  foreground : Color?
  corner_radius : Double?
  text_measurer : TextMeasurer
  enabled : Bool
  scale_factor : Double
  text_scale : Double
  locale : String
  layout_direction : LayoutDirection
  accessibility_contrast : AccessibilityContrast
  reduced_motion : Bool
  content_size_category : ContentSizeCategory
}

///|
fn RenderEnvironment::from_environment(
  environment : Environment,
) -> RenderEnvironment {
  {
    font: None,
    foreground: None,
    corner_radius: None,
    text_measurer: TextMeasurer::default(),
    enabled: environment.enabled,
    scale_factor: environment.scale_factor,
    text_scale: environment.text_scale,
    locale: environment.locale,
    layout_direction: environment.layout_direction,
    accessibility_contrast: environment.accessibility_contrast,
    reduced_motion: environment.reduced_motion,
    content_size_category: environment.content_size_category,
  }
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
  environment? : Environment = Environment::default(),
) -> RenderNode {
  self.render_with_environment(
    bounds,
    focused,
    RenderEnvironment::from_environment(environment),
  )
}

///|
fn RenderEnvironment::with_text_measurer(
  self : RenderEnvironment,
  text_measurer : TextMeasurer,
) -> RenderEnvironment {
  { ..self, text_measurer, }
}

///|
fn RenderEnvironment::matches_default_cache_key(
  self : RenderEnvironment,
) -> Bool {
  self.font is None &&
  self.foreground is None &&
  self.corner_radius is None &&
  self.text_measurer.id() == TextMeasurer::default().id() &&
  self.enabled &&
  self.scale_factor == 1.0 &&
  self.text_scale == 1.0 &&
  self.locale == "en-US" &&
  self.layout_direction == LayoutDirection::LeftToRight &&
  self.accessibility_contrast == AccessibilityContrast::Standard &&
  !self.reduced_motion &&
  self.content_size_category == ContentSizeCategory::Medium
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
            bounds.offset(dx=-data.offset.x, dy=-data.offset.y),
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
        child_baselines: self.children.map(child => child.first_baseline()),
        child_priorities: self.children.map(child => child.layout_priority()),
        child_alignment_guides: custom_alignment_guides(
          self.children.map(child => child.intrinsic_size()),
          self.children.map(child => child.first_baseline()),
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
fn environment_font(
  environment : RenderEnvironment,
  fallback : FontSpec,
) -> FontSpec {
  let font = environment.font.unwrap_or(fallback)
  if environment.text_scale == 1.0 {
    font
  } else {
    { ..font, size: font.size * environment.text_scale }
  }
}

///|
fn environment_measure_text(
  environment : RenderEnvironment,
  input : TextLayoutInput,
) -> TextLayoutResult {
  environment.text_measurer.measure_text(input)
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
    | LayoutPriorityModifier(_)
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
  if !self.dirty.needs_layout {
    match self.cached_intrinsic_size {
      Some(size) => return size
      None => ()
    }
  }
  let size = match self.spec {
    EmptySpec => Size::new(width=0.0, height=0.0)
    TextSpec(data) => data.size
    ButtonSpec(data) => data.size
    TextFieldSpec(data) => data.size
    RichTextEditorSpec(data) => data.size
    ImageSpec(data) => data.size.unwrap_or(Size::new(width=0.0, height=0.0))
    CheckboxSpec(data) => checkbox_intrinsic_size(data)
    PickerSpec(_) => Size::new(width=200.0, height=40.0)
    DatePickerSpec(_) => Size::new(width=200.0, height=40.0)
    SearchBarSpec(_) => Size::new(width=240.0, height=40.0)
    SheetSpec(_data) =>
      if self.children.length() > 0 {
        // Add padding to child size
        self.children[0]
        .intrinsic_size()
        .inflate(Insets::symmetric(horizontal=16.0, vertical=16.0))
      } else {
        Size::new(width=240.0, height=200.0)
      }
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
    CustomLayoutSpec(data) =>
      (data.measure)({
        constraints: Constraints::unbounded(),
        child_sizes: self.children.map(child => child.intrinsic_size()),
        child_baselines: self.children.map(child => child.first_baseline()),
        child_priorities: self.children.map(child => child.layout_priority()),
        child_alignment_guides: custom_alignment_guides(
          self.children.map(child => child.intrinsic_size()),
          self.children.map(child => child.first_baseline()),
        ),
        cache: data.cache,
        cache_key: custom_layout_cache_key(
          self.spec,
          self.children.map(child => child.intrinsic_size()),
        ),
        layout_direction: LayoutDirection::LeftToRight,
        safe_area: Insets::symmetric(),
        viewport: None,
      })
    ComponentSpec(_) =>
      if self.children.length() > 0 {
        self.children[0].intrinsic_size()
      } else {
        Size::new(width=0.0, height=0.0)
      }
  }
  self.cached_intrinsic_size = Some(size)
  size
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
      data.modifier is FocusableModifier(true)
    CustomSpec(_) | CustomLayoutSpec(_) => true
    ComponentSpec(_) => false
    _ => false
  }
}

///|
pub fn ElementNode::render_focused(
  self : ElementNode,
  bounds : Rect,
  focused~ : ElementId?,
  environment? : Environment = Environment::default(),
) -> RenderNode {
  self.render_with_focus(bounds, focused, environment~)
}

///|
pub fn ElementNode::render_focused_with_text_measurer(
  self : ElementNode,
  bounds : Rect,
  focused~ : ElementId?,
  environment? : Environment = Environment::default(),
  text_measurer~ : TextMeasurer,
) -> RenderNode {
  self.render_with_environment(
    bounds,
    focused,
    RenderEnvironment::from_environment(environment).with_text_measurer(
      text_measurer,
    ),
  )
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
        font=environment_font(environment, data.font),
        color=environment_color(environment, data.foreground),
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
  let font = environment_font(environment, data.font)
  let color = if text == "" {
    environment_color(environment, data.placeholder_color)
  } else {
    environment_color(environment, data.foreground)
  }
  let text_frame = frame.inset(Insets::symmetric(horizontal=10.0, vertical=4.0))
  if focused && element.composition is None {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_selection_commands(
      commands,
      text_frame,
      layout,
      element.selection,
    )
  }
  commands.push(
    DrawText(
      TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    let caret = clamp_int(
      text_field_visual_caret(text, element, focused),
      0,
      layout.caret_positions.length() - 1,
    )
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
fn append_text_field_selection_commands(
  commands : Array[DrawCommand],
  text_frame : Rect,
  layout : TextLayoutResult,
  selection : TextRange?,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let start = clamp_int(
        selection.start,
        0,
        layout.caret_positions.length() - 1,
      )
      let end = clamp_int(
        selection.end,
        start,
        layout.caret_positions.length() - 1,
      )
      let x0 = text_frame.origin.x + layout.caret_positions[start]
      let x1 = text_frame.origin.x + layout.caret_positions[end]
      if x1 > x0 {
        commands.push(
          FillRect(
            Rect::new(
              x=x0,
              y=text_frame.origin.y + 6.0,
              width=x1 - x0,
              height=max_double(8.0, text_frame.size.height - 12.0),
            ),
            Color::blue().with_alpha(0.18),
          ),
        )
      }
    }
    None => ()
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
fn append_picker_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : PickerViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.cornerRadius)
  commands.push(FillRoundedRectBrush(rounded, data.background))
  commands.push(
    StrokeRoundedRectBrush(
      rounded,
      Brush::solid(Theme::default().palette.surface_variant),
      1.0,
    ),
  )
  let mut selected_label = data.placeholder
  for item in data.items {
    if item.id == data.selected.get() {
      selected_label = item.label
      break
    }
  }
  let text_frame = frame.inset(Insets::symmetric(horizontal=12.0, vertical=0.0))
  commands.push(
    DrawText(
      TextRun::new(
        text=selected_label,
        frame=text_frame,
        font=environment_font(environment, data.font),
        color=environment_color(environment, data.foreground),
        align=TextAlign::TextStart,
      ),
    ),
  )
  let arrow_size = 12.0
  let arrow_x = frame.origin.x + frame.size.width - arrow_size - 12.0
  let arrow_y = frame.origin.y + (frame.size.height - arrow_size) / 2.0
  let arrow_text = if element.picker_expanded { "▲" } else { "▼" }
  commands.push(
    DrawText(
      TextRun::new(
        text=arrow_text,
        frame=Rect::new(
          x=arrow_x,
          y=arrow_y,
          width=arrow_size,
          height=arrow_size,
        ),
        font=FontSpec::new(size=arrow_size * 0.9, weight=400),
        color=environment_color(environment, data.foreground),
        align=TextAlign::TextCenter,
      ),
    ),
  )
  if element.picker_expanded {
    let item_height = 36.0
    let count = data.items.length().to_double()
    let list_height = min_double(data.maxHeight, count * item_height)
    let list_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=frame.size.width,
      height=list_height,
    )
    let list_rounded = RoundedRect::new(
      rect=list_frame,
      radius=data.cornerRadius,
    )
    commands.push(
      DrawShadow(
        ShadowSpec::new(
          rect=list_rounded,
          color=Color::black().with_alpha(0.15),
          offset=Point::new(x=0.0, y=4.0),
          blur_radius=12.0,
          spread=0.0,
        ),
      ),
    )
    commands.push(FillRoundedRectBrush(list_rounded, data.background))
    for i, item in data.items {
      let index = i.to_double()
      let item_frame = Rect::new(
        x=list_frame.origin.x,
        y=list_frame.origin.y + index * item_height,
        width=list_frame.size.width,
        height=item_height,
      )
      let is_selected = item.id == data.selected.get()
      if is_selected {
        commands.push(
          FillRoundedRectBrush(
            RoundedRect::new(
              rect=item_frame.inset(
                Insets::symmetric(horizontal=4.0, vertical=2.0),
              ),
              radius=4.0,
            ),
            Brush::solid(Theme::default().palette.primary.with_alpha(0.1)),
          ),
        )
      }
      commands.push(
        DrawText(
          TextRun::new(
            text=item.label,
            frame=item_frame.inset(
              Insets::symmetric(horizontal=12.0, vertical=0.0),
            ),
            font=environment_font(environment, data.font),
            color=environment_color(
              environment,
              if is_selected {
                Theme::default().palette.primary
              } else {
                data.foreground
              },
            ),
            align=TextAlign::TextStart,
          ),
        ),
      )
    }
  }
}

///|
fn append_datepicker_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : DatePickerViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  let theme = Theme::default()
  let border_color = Brush::solid(theme.palette.outline.with_alpha(0.5))

  // 绘制选择器背景和边框
  commands.push(FillRoundedRectBrush(rounded, data.background))
  commands.push(StrokeRoundedRectBrush(rounded, border_color, 1.0))

  // 显示选中的日期或占位符
  let selected = data.selected.get()
  let display_text = selected.format(data.mode)
  let font = environment_font(environment, data.font)
  let color = environment_color(environment, data.foreground)
  commands.push(
    DrawText(
      TextRun::new(
        text=display_text,
        frame=frame.inset(Insets::symmetric(horizontal=12.0, vertical=0.0)),
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )

  // 绘制箭头指示器
  let arrow_size = 16.0
  let arrow_frame = Rect::new(
    x=frame.origin.x + frame.size.width - arrow_size - 12.0,
    y=frame.origin.y + (frame.size.height - arrow_size) / 2.0,
    width=arrow_size,
    height=arrow_size,
  )
  commands.push(
    DrawText(
      TextRun::new(
        text="▼",
        frame=arrow_frame,
        font=FontSpec::new(size=12.0),
        color=data.foreground,
      ),
    ),
  )

  // 展开时显示日期选择面板
  if element.datepicker_expanded {
    let panel_width = max_double(frame.size.width, 280.0)
    let panel_height = 350.0
    let panel_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=panel_width,
      height=panel_height,
    )
    let panel_rounded = RoundedRect::new(rect=panel_frame, radius=8.0)
    commands.push(
      DrawShadow(
        ShadowSpec::new(
          rect=panel_rounded,
          color=Color::black().with_alpha(0.15),
          offset=Point::new(x=0.0, y=4.0),
          blur_radius=12.0,
          spread=0.0,
        ),
      ),
    )
    commands.push(FillRoundedRectBrush(panel_rounded, data.background))

    // 绘制标题和导航
    let header_height = 50.0
    let header_frame = Rect::new(
      x=panel_frame.origin.x,
      y=panel_frame.origin.y,
      width=panel_frame.size.width,
      height=header_height,
    )
    let view_date = element.datepicker_view
    let header_text = "{view_date.year}年{view_date.month}月"
    commands.push(
      DrawText(
        TextRun::new(
          text=header_text,
          frame=header_frame,
          font=FontSpec::new(size=16.0, weight=600),
          color=data.foreground,
        ),
      ),
    )

    // 绘制左右导航按钮
    let button_size = 32.0
    let left_button_frame = Rect::new(
      x=panel_frame.origin.x + 8.0,
      y=panel_frame.origin.y + (header_height - button_size) / 2.0,
      width=button_size,
      height=button_size,
    )
    let right_button_frame = Rect::new(
      x=panel_frame.origin.x + panel_frame.size.width - button_size - 8.0,
      y=panel_frame.origin.y + (header_height - button_size) / 2.0,
      width=button_size,
      height=button_size,
    )
    commands.push(
      DrawText(
        TextRun::new(
          text="◀",
          frame=left_button_frame,
          font=FontSpec::new(size=18.0),
          color=data.foreground,
        ),
      ),
    )
    commands.push(
      DrawText(
        TextRun::new(
          text="▶",
          frame=right_button_frame,
          font=FontSpec::new(size=18.0),
          color=data.foreground,
        ),
      ),
    )

    // 绘制星期标题
    let day_header_height = 36.0
    let day_cell_width = panel_frame.size.width / 7.0
    let day_names = ["日", "一", "二", "三", "四", "五", "六"]
    let mut day_index = 0
    while day_index < 7 {
      let day = day_names[day_index]
      let day_frame = Rect::new(
        x=panel_frame.origin.x + day_index.to_double() * day_cell_width,
        y=panel_frame.origin.y + header_height,
        width=day_cell_width,
        height=day_header_height,
      )
      commands.push(
        DrawText(
          TextRun::new(
            text=day,
            frame=day_frame,
            font=FontSpec::new(size=12.0, weight=500),
            color=data.foreground.with_alpha(0.6),
          ),
        ),
      )
      day_index = day_index + 1
    }

    // 绘制日期网格
    let cell_height = 36.0
    let start_y = panel_frame.origin.y + header_height + day_header_height

    // 计算该月第一天是星期几 (0=周日, 1=周一...)
    // 使用 Zeller 公式的简化版本
    let year = view_date.year
    let month = view_date.month
    let q = 1
    let m = if month < 3 { month + 12 } else { month }
    let y = if month < 3 { year - 1 } else { year }
    let k = y % 100
    let j = y / 100
    let h = (q + 13 * (m + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
    let first_day_weekday = h

    let days_in_month_count = days_in_month(year, month)

    // 绘制当前月的日期
    let mut day = 1
    while day <= days_in_month_count {
      let total_index = first_day_weekday + day - 1
      let col = total_index % 7
      let row = total_index / 7
      let cell_frame = Rect::new(
        x=panel_frame.origin.x + col.to_double() * day_cell_width,
        y=start_y + row.to_double() * cell_height,
        width=day_cell_width,
        height=cell_height,
      )

      let is_selected = selected.year == year &&
        selected.month == month &&
        selected.day == day
      let cell_rounded = RoundedRect::new(
        rect=cell_frame.inset(Insets::all(4.0)),
        radius=18.0,
      )

      if is_selected {
        commands.push(FillRoundedRect(cell_rounded, theme.palette.primary))
      }

      let day_color = if is_selected { Color::white() } else { data.foreground }

      commands.push(
        DrawText(
          TextRun::new(
            text="{day}",
            frame=cell_frame,
            font=FontSpec::new(size=14.0),
            color=day_color,
          ),
        ),
      )
      day = day + 1
    }
  }
}

///|
fn append_searchbar_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : SearchBarViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
  focused_id : ElementId?,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  let is_focused = focused_id == Some(element.id)
  let border = if is_focused { data.focused_border } else { data.border }
  commands.push(FillRoundedRectBrush(rounded, data.background))
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }

  let icon_frame = Rect::new(
    x=frame.origin.x + 10.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
  append_searchbar_search_icon(
    commands,
    icon_frame,
    data.foreground.with_alpha(0.6),
  )

  let text = data.query.get()
  let display_text = text_with_composition(text, element, is_focused)
  let display = if display_text == "" { data.placeholder } else { display_text }
  let font = environment_font(environment, data.font)
  let color = if text == "" {
    environment_color(environment, data.placeholder_color)
  } else {
    environment_color(environment, data.foreground)
  }
  let text_frame = Rect::new(
    x=frame.origin.x + 32.0,
    y=frame.origin.y,
    width=if text != "" {
      frame.size.width - 64.0
    } else {
      frame.size.width - 32.0
    },
    height=frame.size.height,
  ).inset(Insets::symmetric(vertical=0.0))
  if is_focused && element.composition is None {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_selection_commands(
      commands,
      text_frame,
      layout,
      element.selection,
    )
  }
  commands.push(
    DrawText(
      TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )
  if is_focused {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    let caret = clamp_int(
      text_field_visual_caret(text, element, is_focused),
      0,
      layout.caret_positions.length() - 1,
    )
    let cursor_x = text_frame.origin.x + layout.caret_positions[caret]
    let cursor = Rect::new(
      x=cursor_x,
      y=text_frame.origin.y + 6.0,
      width=1.5,
      height=max_double(8.0, text_frame.size.height - 12.0),
    )
    commands.push(FillRect(cursor, data.cursor_color))
  }

  if text != "" {
    let clear_frame = Rect::new(
      x=frame.origin.x + frame.size.width - 26.0,
      y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
      width=16.0,
      height=16.0,
    )
    append_searchbar_clear_icon(
      commands,
      clear_frame,
      data.foreground.with_alpha(0.6),
    )
  }
}

///|
fn append_searchbar_search_icon(
  commands : Array[DrawCommand],
  frame : Rect,
  color : Color,
) -> Unit {
  let center = Point::new(
    x=frame.origin.x + frame.size.width * 0.42,
    y=frame.origin.y + frame.size.height * 0.42,
  )
  let radius = frame.size.width * 0.26
  commands.push(
    StrokeRoundedRect(
      RoundedRect::new(
        rect=Rect::new(
          x=center.x - radius,
          y=center.y - radius,
          width=radius * 2.0,
          height=radius * 2.0,
        ),
        radius~,
      ),
      color,
      1.6,
    ),
  )
  commands.push(
    DrawPath(
      PathSpec::new(
        verbs=[
          PathVerb::MoveTo(
            Point::new(x=center.x + radius * 0.7, y=center.y + radius * 0.7),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + frame.size.width * 0.86,
              y=frame.origin.y + frame.size.height * 0.86,
            ),
          ),
        ],
        stroke=Some(Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
fn append_searchbar_clear_icon(
  commands : Array[DrawCommand],
  frame : Rect,
  color : Color,
) -> Unit {
  let inset = frame.size.width * 0.28
  commands.push(
    DrawPath(
      PathSpec::new(
        verbs=[
          PathVerb::MoveTo(
            Point::new(x=frame.origin.x + inset, y=frame.origin.y + inset),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
          PathVerb::MoveTo(
            Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + inset,
            ),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
        ],
        stroke=Some(Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
pub fn RenderNode::to_layout_result(self : RenderNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}
