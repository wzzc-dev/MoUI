///|
fn RenderNode::collect_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  self.collect_draw_commands_with_overlays(commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_draw_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  match self.cached_draw_commands {
    Some(cached) => {
      for command in cached {
        commands.push(command)
      }
      match self.cached_overlay_draw_commands {
        Some(cached_overlays) =>
          for command in cached_overlays {
            overlays.push(command)
          }
        None => ()
      }
      return
    }
    None => ()
  }
  self.collect_uncached_draw_commands_with_overlays(commands, overlays)
}

///|
fn RenderNode::collect_uncached_draw_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_draw_commands_with_overlays(commands, overlays)
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
  for command in self.overlay_paint_commands {
    overlays.push(command)
  }
}

///|
fn RenderNode::with_repaint_boundary_cache(self : RenderNode) -> RenderNode {
  let commands : Array[DrawCommand] = []
  let overlays : Array[DrawCommand] = []
  self.collect_uncached_draw_commands_with_overlays(commands, overlays)
  {
    ..self,
    cached_draw_commands: Some(commands),
    cached_overlay_draw_commands: Some(overlays),
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
