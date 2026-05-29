///|
fn RenderNode::collect_draw_commands(
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
fn ElementNode::render_focused_with_text_system(
  self : ElementNode,
  placed : PlacedNode,
  focused~ : ElementId?,
  environment? : Environment = Environment::default(),
  text_system~ : TextSystem,
) -> RenderNode {
  self.render_with_environment(
    placed,
    focused,
    RenderEnvironment::from_environment(environment).with_text_system(
      text_system,
    ),
  )
}
