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
fn RenderNode::collect_frame_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  self.collect_frame_commands_with_overlays(
    commands, overlays, known_layers,
  )
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_frame_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
) -> Unit {
  if self.is_repaint_boundary {
    match self.cached_layer_spec() {
      Some(spec) =>
        if known_layers.has_current_cached_layer(spec) {
          commands.push(DrawCachedLayer(spec))
        } else {
          commands.push(BeginCachedLayer(spec))
          self.collect_uncached_frame_commands_with_overlays(
            commands, overlays, known_layers,
          )
          commands.push(EndCachedLayer(spec.key))
        }
      None =>
        self.collect_uncached_frame_commands_with_overlays(
          commands, overlays, known_layers,
        )
    }
  } else {
    self.collect_uncached_frame_commands_with_overlays(
      commands, overlays, known_layers,
    )
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
fn RenderNode::collect_uncached_frame_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_frame_commands_with_overlays(
      commands, overlays, known_layers,
    )
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
    is_repaint_boundary: true,
    layer_cache_key: Some(self.repaint_boundary_cache_key()),
    cached_draw_commands: Some(commands),
    cached_overlay_draw_commands: Some(overlays),
  }
}

///|
fn RenderNode::cached_layer_spec(self : RenderNode) -> CachedLayerSpec? {
  match self.layer_cache_key {
    Some(key) =>
      Some(
        CachedLayerSpec::new(
          key~,
          frame=self.paint_bounds,
          content_revision=self.content_revision,
        ),
      )
    None => None
  }
}

///|
fn RenderNode::repaint_boundary_cache_key(self : RenderNode) -> String {
  "element=\{self.element_id.value};x=\{self.frame.origin.x};y=\{self.frame.origin.y};w=\{self.frame.size.width};h=\{self.frame.size.height}"
}

///|
fn Array::has_current_cached_layer(
  self : Array[CachedLayerState],
  spec : CachedLayerSpec,
) -> Bool {
  self.any(
    layer =>
      layer.key == spec.key &&
      layer.content_revision == spec.content_revision,
  )
}

///|
fn RenderNode::find_paint_bounds(self : RenderNode, id : ElementId) -> Rect? {
  if self.element_id == id {
    Some(self.paint_bounds)
  } else {
    for child in self.children {
      match child.find_paint_bounds(id) {
        Some(bounds) => return Some(bounds)
        None => ()
      }
    }
    None
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
