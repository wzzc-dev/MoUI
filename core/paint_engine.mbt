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
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  match self.spec {
    EmptySpec => ()
    SpacerSpec(_) => ()
    TextSpec(data) =>
      commands.push(
        DrawText({
          text: data.text,
          frame: bounds,
          font: data.font,
          color: data.color,
        }),
      )
    ButtonSpec(data) => {
      let background = match self.button_state {
        ButtonState::Normal => data.background
        ButtonState::Hovered => data.hovered_background
        ButtonState::Pressed => data.pressed_background
      }
      if data.corner_radius > 0.0 {
        commands.push(
          FillRoundedRect(
            RoundedRect::new(rect=bounds, radius=data.corner_radius),
            background,
          ),
        )
      } else {
        commands.push(FillRect(bounds, background))
      }
      let foreground = match self.button_state {
        ButtonState::Pressed => Color::white()
        ButtonState::Normal | ButtonState::Hovered => data.foreground
      }
      commands.push(
        DrawText({
          text: data.text,
          frame: bounds,
          font: data.font,
          color: foreground,
        }),
      )
    }
    TextFieldSpec(data) =>
      append_text_field_commands(
        commands,
        self,
        data,
        bounds,
        focused == Some(self.id),
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
      if data.corner_radius > 0.0 {
        commands.push(PushClip(frame))
      }
      commands.push(
        DrawImage({ source: data.source, frame, opacity: data.opacity }),
      )
      if data.corner_radius > 0.0 {
        commands.push(PopClip)
      }
    }
    CheckboxSpec(data) => append_checkbox_commands(commands, data, bounds)
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
        children.push(child.render_with_focus(frames[index], focused))
      }
    }
    PaddingSpec(data) => {
      let child_frame = bounds.inset(data.insets)
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(child_frame, focused))
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
        Some(color) =>
          if data.corner_radius > 0.0 {
            commands.push(
              FillRoundedRect(
                RoundedRect::new(rect=frame, radius=data.corner_radius),
                color,
              ),
            )
          } else {
            commands.push(FillRect(frame, color))
          }
        None => ()
      }
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(frame, focused))
      }
    }
    FrameSpec(data) => {
      let frame = frame_rect_for_spec(data, bounds)
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(frame, focused))
      }
    }
    StackSpec(_) =>
      for child in self.children {
        children.push(child.render_with_focus(bounds, focused))
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
          self.children[0].render_with_focus(
            bounds.offset(dx=-data.offset.x, dy=-data.offset.y),
            focused,
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
        children.push(child.render_with_focus(frames[index], focused))
      }
    }
    ListSpec(data) => {
      let frames = list_child_frames(data.spacing, self.children, bounds)
      for index, child in self.children {
        children.push(child.render_with_focus(frames[index], focused))
      }
    }
  }
  self.dirty.clear()
  {
    element_id: self.id,
    frame: bounds,
    children,
    hit_testable: element_hit_testable(self.spec),
    paint_commands: commands,
  }
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
  }
}

///|
fn element_hit_testable(spec : ViewSpec) -> Bool {
  match spec {
    ButtonSpec(_) => true
    TextFieldSpec(_) => true
    CheckboxSpec(_) => true
    ContainerSpec(data) => data.background is Some(_)
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
) -> Unit {
  let box_side = data.size.width
  let box_y = frame.origin.y + max_double(0.0, (frame.size.height - box_side) / 2.0)
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
      DrawText({
        text: "✓",
        frame: box_rect,
        font: FontSpec::new(size=box_side * 0.78, weight=700),
        color: Color::white(),
      }),
    )
  } else {
    commands.push(StrokeRoundedRect(box, data.check_color, 2.0))
  }
  commands.push(
    DrawText({
      text: data.label,
      frame: Rect::new(
        x=frame.origin.x + box_side + 8.0,
        y=frame.origin.y,
        width=max_double(0.0, frame.size.width - box_side - 8.0),
        height=frame.size.height,
      ),
      font: data.font,
      color: data.foreground,
    }),
  )
}

///|
fn append_text_field_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : TextFieldViewSpec,
  frame : Rect,
  focused : Bool,
) -> Unit {
  let border = if focused {
    data.focused_border_color
  } else {
    data.border_color
  }
  if data.corner_radius > 0.0 {
    commands.push(
      FillRoundedRect(
        RoundedRect::new(rect=frame, radius=data.corner_radius),
        data.background,
      ),
    )
    commands.push(
      StrokeRoundedRect(
        RoundedRect::new(rect=frame, radius=data.corner_radius),
        border,
        if focused {
          2.0
        } else {
          1.0
        },
      ),
    )
  } else {
    commands.push(FillRect(frame, data.background))
    commands.push(StrokeRect(frame, border, if focused { 2.0 } else { 1.0 }))
  }
  let text = data.value.get()
  let display_text = text_with_composition(text, element, focused)
  let display = if display_text == "" { data.placeholder } else { display_text }
  let color = if text == "" { data.placeholder_color } else { data.foreground }
  let text_frame = frame.inset(Insets::symmetric(horizontal=10.0, vertical=4.0))
  commands.push(
    DrawText({ text: display, frame: text_frame, font: data.font, color }),
  )
  if focused {
    let cursor_x = text_frame.origin.x +
      clamp_int(element.caret, 0, text_length(text)).to_double() *
      data.font.size *
      0.55
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
}

///|
pub fn RenderNode::to_layout_result(self : RenderNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}

