///|
pub fn ElementNode::render(self : ElementNode, bounds : Rect) -> RenderNode {
  self.render_with_focus(bounds, None)
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
pub fn RenderNode::to_layout_result(self : RenderNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
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
pub fn ElementNode::render_focused_with_text_system(
  self : ElementNode,
  bounds : Rect,
  focused~ : ElementId?,
  environment? : Environment = Environment::default(),
  text_system~ : TextSystem,
) -> RenderNode {
  self.render_with_environment(
    bounds,
    focused,
    RenderEnvironment::from_environment(environment).with_text_system(
      text_system,
    ),
  )
}
