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
pub(all) struct FlexData {
  axis : Axis
  spacing : Double
  children : Array[ViewNode]
}

///|
pub(all) struct PaddingData {
  insets : Insets
  child : ViewNode
}

///|
pub(all) enum ViewNode {
  Empty
  Label(LabelData)
  Button(ButtonData)
  Flex(FlexData)
  Padding(PaddingData)
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
    Flex(_) => Size::new(width=0.0, height=0.0)
    Padding(data) => data.child.intrinsic_size().inflate(data.insets)
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
  }
}

///|
pub fn ViewNode::paint(
  self : ViewNode,
  frame : Rect,
  commands : Array[DrawCommand],
) -> Unit {
  match self {
    Empty => ()
    Label(data) =>
      commands.push(
        DrawText({
          text: data.text,
          frame,
          font: FontSpec::new(size=16.0, weight=500),
          color: data.color,
        }),
      )
    Button(data) => {
      let color = match data.state {
        Normal => Color::gray()
        Hovered => Color::rgba(r=0.72, g=0.78, b=0.92)
        Pressed => Color::blue()
      }
      commands.push(FillRect(frame, color))
      let text_color = match data.state {
        Pressed => Color::white()
        Normal | Hovered => Color::black()
      }
      commands.push(
        DrawText({
          text: data.text,
          frame,
          font: FontSpec::new(size=16.0, weight=600),
          color: text_color,
        }),
      )
    }
    Flex(data) => paint_flex(data, frame, commands)
    Padding(data) => {
      let child_frame = frame.inset(data.insets)
      data.child.paint(child_frame, commands)
    }
  }
}

///|
fn handle_button_pointer(
  data : ButtonData,
  event : PointerEvent,
  frame : Rect,
) -> PointerDispatch {
  let inside = frame.contains(event.position)
  let was_pressed = data.state == Pressed
  let next = match event.phase {
    Move => if inside { Hovered } else { Normal }
    Down => if inside { Pressed } else { Normal }
    Up => if inside { Hovered } else { Normal }
    Cancel => Normal
  }
  let activated = event.phase == Up && inside && was_pressed
  if activated {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
  }
  {
    node: Button({
      text: data.text,
      size: data.size,
      state: next,
      on_click: data.on_click,
    }),
    changed: next != data.state || activated,
    activated,
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
    node: Flex({ axis: data.axis, spacing: data.spacing, children }),
    changed,
    activated,
  }
}

///|
fn paint_flex(
  data : FlexData,
  frame : Rect,
  commands : Array[DrawCommand],
) -> Unit {
  let count = data.children.length()
  if count == 0 {
    ()
  } else {
    let total_spacing = data.spacing * (count.to_double() - 1.0)
    let main = match data.axis {
      Horizontal =>
        max_double(0.0, frame.size.width - total_spacing) / count.to_double()
      Vertical =>
        max_double(0.0, frame.size.height - total_spacing) / count.to_double()
    }
    for index, child in data.children {
      let child_frame = flex_child_frame_with_main(data, frame, index, main)
      child.paint(child_frame, commands)
    }
  }
}

///|
fn flex_child_frame(data : FlexData, frame : Rect, index : Int) -> Rect {
  let count = data.children.length()
  if count == 0 {
    Rect::new(x=frame.origin.x, y=frame.origin.y, width=0.0, height=0.0)
  } else {
    let total_spacing = data.spacing * (count.to_double() - 1.0)
    let main = match data.axis {
      Horizontal =>
        max_double(0.0, frame.size.width - total_spacing) / count.to_double()
      Vertical =>
        max_double(0.0, frame.size.height - total_spacing) / count.to_double()
    }
    flex_child_frame_with_main(data, frame, index, main)
  }
}

///|
fn flex_child_frame_with_main(
  data : FlexData,
  frame : Rect,
  index : Int,
  main : Double,
) -> Rect {
  let offset = index.to_double() * (main + data.spacing)
  match data.axis {
    Horizontal =>
      Rect::new(
        x=frame.origin.x + offset,
        y=frame.origin.y,
        width=main,
        height=frame.size.height,
      )
    Vertical =>
      Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + offset,
        width=frame.size.width,
        height=main,
      )
  }
}
