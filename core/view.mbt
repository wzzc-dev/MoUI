///|
pub type ClickHandler = () -> Unit

///|
pub(all) enum ButtonState {
  Normal
  Hovered
  Pressed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LabelData {
  text : String
  size : Size
  color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ButtonData {
  text : String
  size : Size
  mut state : ButtonState
  on_click : ClickHandler?
}

///|
pub(all) struct TextFieldData {
  value : Binding[String]
  placeholder : String
  size : Size
  on_submit : (() -> Unit)?
}

///|
pub(all) struct FlexData {
  axis : Axis
  spacing : Double
  main_axis_alignment : MainAxisAlignment
  cross_axis_alignment : CrossAxisAlignment
  children : Array[ViewNode]
}

///|
pub(all) struct PaddingData {
  insets : Insets
  child : ViewNode
}

///|
pub(all) struct ContainerData {
  size : Size?
  background : Color?
  corner_radius : Double
  child : ViewNode
}

///|
pub(all) struct SpacerData {
  min_length : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct StyledData {
  style : ViewStyle
  child : ViewNode
}

///|
pub(all) struct KeyedData {
  key : Key
  child : ViewNode
}

///|
pub(all) struct EnvironmentData {
  environment : Environment
  child : ViewNode
}

///|
pub(all) enum ViewNode {
  Empty
  Label(LabelData)
  Button(ButtonData)
  TextField(TextFieldData)
  Flex(FlexData)
  Padding(PaddingData)
  Container(ContainerData)
  Spacer(SpacerData)
  Styled(StyledData)
  Keyed(KeyedData)
  EnvironmentNode(EnvironmentData)
}

///|
pub(all) struct PointerDispatch {
  node : ViewNode
  changed : Bool
  activated : Bool
}

///|
pub fn ViewNode::intrinsic_size(self : ViewNode) -> Size {
  match self {
    Empty => Size::new(width=0.0, height=0.0)
    Label(data) => data.size
    Button(data) => data.size
    TextField(data) => data.size
    Flex(_) => Size::new(width=0.0, height=0.0)
    Padding(data) => data.child.intrinsic_size().inflate(data.insets)
    Container(data) =>
      match data.size {
        Some(size) => size
        None => data.child.intrinsic_size()
      }
    Spacer(data) => Size::new(width=data.min_length, height=data.min_length)
    Styled(data) => data.child.intrinsic_size()
    Keyed(data) => data.child.intrinsic_size()
    EnvironmentNode(data) => data.child.intrinsic_size()
  }
}

///|
pub fn ViewNode::handle_pointer(
  self : ViewNode,
  event : PointerEvent,
  frame : Rect,
) -> PointerDispatch {
  match self {
    Empty | Label(_) => { node: self, changed: false, activated: false }
    Button(data) => handle_button_pointer(data, event, frame)
    TextField(_) => { node: self, changed: false, activated: false }
    Flex(data) => handle_flex_pointer(data, event, frame)
    Padding(data) => {
      let child_frame = frame.inset(data.insets)
      let result = data.child.handle_pointer(event, child_frame)
      {
        node: Padding({ insets: data.insets, child: result.node }),
        changed: result.changed,
        activated: result.activated,
      }
    }
    Container(data) => {
      let result = data.child.handle_pointer(event, frame)
      {
        node: Container({
          size: data.size,
          background: data.background,
          corner_radius: data.corner_radius,
          child: result.node,
        }),
        changed: result.changed,
        activated: result.activated,
      }
    }
    Spacer(_) => { node: self, changed: false, activated: false }
    Styled(data) => {
      let result = data.child.handle_pointer(event, frame)
      {
        node: Styled({ style: data.style, child: result.node }),
        changed: result.changed,
        activated: result.activated,
      }
    }
    Keyed(data) => {
      let result = data.child.handle_pointer(event, frame)
      {
        node: Keyed({ key: data.key, child: result.node }),
        changed: result.changed,
        activated: result.activated,
      }
    }
    EnvironmentNode(data) => {
      let result = data.child.handle_pointer(event, frame)
      {
        node: EnvironmentNode({
          environment: data.environment,
          child: result.node,
        }),
        changed: result.changed,
        activated: result.activated,
      }
    }
  }
}

///|
pub fn ViewNode::paint(
  self : ViewNode,
  frame : Rect,
  commands : Array[DrawCommand],
) -> Unit {
  self.paint_with_style(frame, commands, ViewStyle::empty())
}

///|
fn ViewNode::paint_with_style(
  self : ViewNode,
  frame : Rect,
  commands : Array[DrawCommand],
  style : ViewStyle,
) -> Unit {
  match self {
    Empty => ()
    Label(data) =>
      commands.push(
        DrawText({
          text: data.text,
          frame,
          font: style.font.unwrap_or(FontSpec::new(size=16.0, weight=500)),
          color: style.foreground.unwrap_or(data.color),
        }),
      )
    Button(data) => {
      let color = style.background.unwrap_or(
        match data.state {
          Normal => Color::gray()
          Hovered => Color::rgba(r=0.72, g=0.78, b=0.92)
          Pressed => Color::blue()
        },
      )
      match style.corner_radius {
        Some(radius) if radius > 0.0 =>
          commands.push(
            FillRoundedRect(RoundedRect::new(rect=frame, radius~), color),
          )
        _ => commands.push(FillRect(frame, color))
      }
      let text_color = style.foreground.unwrap_or(
        match data.state {
          Pressed => Color::white()
          Normal | Hovered => Color::black()
        },
      )
      commands.push(
        DrawText({
          text: data.text,
          frame,
          font: style.font.unwrap_or(FontSpec::new(size=16.0, weight=600)),
          color: text_color,
        }),
      )
    }
    TextField(data) => {
      commands.push(FillRect(frame, style.background.unwrap_or(Color::white())))
      commands.push(StrokeRect(frame, Color::gray(), 1.0))
      let text = data.value.get()
      let display = if text == "" { data.placeholder } else { text }
      let color = if text == "" {
        Color::gray()
      } else {
        style.foreground.unwrap_or(Color::black())
      }
      commands.push(
        DrawText({
          text: display,
          frame: frame.inset(Insets::symmetric(horizontal=10.0)),
          font: style.font.unwrap_or(FontSpec::new(size=16.0, weight=400)),
          color,
        }),
      )
    }
    Flex(data) => paint_flex(data, frame, commands, style)
    Padding(data) => {
      let child_frame = frame.inset(data.insets)
      data.child.paint_with_style(child_frame, commands, style)
    }
    Container(data) => {
      let frame = match data.size {
        Some(size) =>
          Rect::new(
            x=frame.origin.x,
            y=frame.origin.y,
            width=size.width,
            height=size.height,
          )
        None => frame
      }
      match option_prefer(data.background, style.background) {
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
      data.child.paint_with_style(frame, commands, style)
    }
    Spacer(_) => ()
    Styled(data) =>
      data.child.paint_with_style(frame, commands, style.merge(data.style))
    Keyed(data) => data.child.paint_with_style(frame, commands, style)
    EnvironmentNode(data) =>
      data.child.paint_with_style(
        frame,
        commands,
        style.merge(ViewStyle::from_theme(data.environment.theme)),
      )
  }
}

///|
pub fn ViewNode::font(self : ViewNode, font : FontSpec) -> ViewNode {
  Styled({
    style: {
      font: Some(font),
      foreground: None,
      background: None,
      corner_radius: None,
    },
    child: self,
  })
}

///|
pub fn ViewNode::foreground(self : ViewNode, color : Color) -> ViewNode {
  Styled({
    style: {
      font: None,
      foreground: Some(color),
      background: None,
      corner_radius: None,
    },
    child: self,
  })
}

///|
pub fn ViewNode::background(self : ViewNode, color : Color) -> ViewNode {
  Styled({
    style: {
      font: None,
      foreground: None,
      background: Some(color),
      corner_radius: None,
    },
    child: self,
  })
}

///|
pub fn ViewNode::corner_radius(self : ViewNode, radius : Double) -> ViewNode {
  Styled({
    style: {
      font: None,
      foreground: None,
      background: None,
      corner_radius: Some(radius),
    },
    child: self,
  })
}

///|
pub fn ViewNode::padding(self : ViewNode, value : Double) -> ViewNode {
  Padding({ insets: Insets::all(value), child: self })
}

///|
pub fn ViewNode::spacing(self : ViewNode, spacing : Double) -> ViewNode {
  match self {
    Flex(data) =>
      Flex({
        axis: data.axis,
        spacing,
        main_axis_alignment: data.main_axis_alignment,
        cross_axis_alignment: data.cross_axis_alignment,
        children: data.children,
      })
    Styled(data) =>
      Styled({ style: data.style, child: data.child.spacing(spacing) })
    Keyed(data) => Keyed({ key: data.key, child: data.child.spacing(spacing) })
    _ => self
  }
}

///|
pub fn ViewNode::main_axis_alignment(
  self : ViewNode,
  alignment : MainAxisAlignment,
) -> ViewNode {
  match self {
    Flex(data) =>
      Flex({
        axis: data.axis,
        spacing: data.spacing,
        main_axis_alignment: alignment,
        cross_axis_alignment: data.cross_axis_alignment,
        children: data.children,
      })
    Styled(data) =>
      Styled({
        style: data.style,
        child: data.child.main_axis_alignment(alignment),
      })
    Keyed(data) =>
      Keyed({ key: data.key, child: data.child.main_axis_alignment(alignment) })
    _ => self
  }
}

///|
pub fn ViewNode::cross_axis_alignment(
  self : ViewNode,
  alignment : CrossAxisAlignment,
) -> ViewNode {
  match self {
    Flex(data) =>
      Flex({
        axis: data.axis,
        spacing: data.spacing,
        main_axis_alignment: data.main_axis_alignment,
        cross_axis_alignment: alignment,
        children: data.children,
      })
    Styled(data) =>
      Styled({
        style: data.style,
        child: data.child.cross_axis_alignment(alignment),
      })
    Keyed(data) =>
      Keyed({ key: data.key, child: data.child.cross_axis_alignment(alignment) })
    _ => self
  }
}

///|
pub fn ViewNode::key(self : ViewNode, value : String) -> ViewNode {
  Keyed({ key: Key::new(value), child: self })
}

///|
pub fn ViewNode::theme(self : ViewNode, theme : Theme) -> ViewNode {
  EnvironmentNode({
    environment: Environment::default().with_theme(theme),
    child: self,
  })
}

///|
pub fn ViewNode::environment(
  self : ViewNode,
  environment : Environment,
) -> ViewNode {
  EnvironmentNode({ environment, child: self })
}

///|
fn handle_button_pointer(
  data : ButtonData,
  event : PointerEvent,
  frame : Rect,
) -> PointerDispatch {
  let inside = frame.contains(event.position)
  let tap = recognize_button_tap(data.state, inside, event.phase)
  if tap.activated {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
  }
  {
    node: Button({
      text: data.text,
      size: data.size,
      state: tap.next_state,
      on_click: data.on_click,
    }),
    changed: tap.next_state != data.state || tap.activated,
    activated: tap.activated,
  }
}

///|
fn handle_flex_pointer(
  data : FlexData,
  event : PointerEvent,
  frame : Rect,
) -> PointerDispatch {
  let children : Array[ViewNode] = []
  let mut changed = false
  let mut activated = false
  for index, child in data.children {
    let child_frame = flex_child_frame(data, frame, index)
    let result = child.handle_pointer(event, child_frame)
    children.push(result.node)
    changed = changed || result.changed
    activated = activated || result.activated
  }
  {
    node: Flex({
      axis: data.axis,
      spacing: data.spacing,
      main_axis_alignment: data.main_axis_alignment,
      cross_axis_alignment: data.cross_axis_alignment,
      children,
    }),
    changed,
    activated,
  }
}

///|
fn paint_flex(
  data : FlexData,
  frame : Rect,
  commands : Array[DrawCommand],
  style : ViewStyle,
) -> Unit {
  let count = data.children.length()
  if count == 0 {
    ()
  } else {
    let frames = flex_frames_for_view(data, frame)
    for index, child in data.children {
      child.paint_with_style(frames[index], commands, style)
    }
  }
}

///|
fn flex_child_frame(data : FlexData, frame : Rect, index : Int) -> Rect {
  let frames = flex_frames_for_view(data, frame)
  if index >= 0 && index < frames.length() {
    frames[index]
  } else {
    Rect::new(x=frame.origin.x, y=frame.origin.y, width=0.0, height=0.0)
  }
}

///|
fn flex_frames_for_view(data : FlexData, frame : Rect) -> Array[Rect] {
  flex_child_frames(
    data.axis,
    data.spacing,
    data.main_axis_alignment,
    data.cross_axis_alignment,
    data.children.map(child => child.intrinsic_size()),
    frame,
  )
}
