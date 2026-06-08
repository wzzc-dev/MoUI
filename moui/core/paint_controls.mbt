///|
fn render_modified_node(
  element : ElementNode,
  data : ModifiedViewSpec,
  placed : PlacedNode,
  focused : ElementId?,
  environment : RenderEnvironment,
  children : Array[RenderNode],
  commands : Array[DrawCommand],
  post_commands : Array[DrawCommand],
) -> Unit {
  let bounds = placed.frame
  match data.modifier {
    PaddingModifier(_) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    FrameModifier(_) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
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
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    }
    ForegroundModifier(color) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            { ..environment, foreground: Some(color) },
          ),
        )
      }
    FontModifier(font) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            { ..environment, font: Some(font) },
          ),
        )
      }
    CornerRadiusModifier(radius) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            { ..environment, corner_radius: Some(radius) },
          ),
        )
      }
    OpacityModifier(opacity) => {
      commands.push(PushOpacity(opacity))
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
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
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
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
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    }
    OffsetModifier(_, _) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    ClipModifier => {
      commands.push(PushClip(bounds))
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
      post_commands.push(PopClip)
    }
    ScaleModifier(sx, sy) => {
      commands.push(PushTransform(Transform2D::scale(sx~, sy~)))
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
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
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            child_environment,
          ),
        )
      }
      if disabled {
        post_commands.push(PopOpacity)
      }
    }
    AccessibilityLabelModifier(_)
    | SemanticsRoleModifier(_)
    | SemanticsSelectedModifier(_)
    | SemanticsPressedModifier(_)
    | SemanticsCheckedModifier(_)
    | SemanticsExpandedModifier(_)
    | SemanticsInvalidModifier(_)
    | SemanticsRequiredModifier(_)
    | SemanticsDescriptionModifier(_)
    | SemanticsActionModifier(_)
    | FocusableModifier(_)
    | FocusTrapModifier(_)
    | OnTapModifier(_)
    | OnLongPressModifier(_)
    | OnDoubleTapModifier(_)
    | OnDragModifier(_)
    | OnDragWithFrameModifier(_)
    | OnFileDropModifier(_)
    | KeyboardShortcutModifier(_)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier
    | RepaintBoundaryModifier =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    AlignModifier(_) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
    AspectRatioModifier(_) =>
      if element.children.length() > 0 && placed.children.length() > 0 {
        children.push(
          element.children[0].render_with_environment(
            placed.children[0],
            focused,
            environment,
          ),
        )
      }
  }
}

///|
fn ElementNode::intrinsic_size(self : ElementNode) -> Size {
  if !self.dirty.needs_layout {
    match self.layout_cache.cached_intrinsic_size {
      Some(size) => return size
      None => ()
    }
    match self.layout_cache.cached_measured {
      Some(measured) => return measured.size
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
  self.layout_cache.cached_intrinsic_size = Some(size)
  size
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
