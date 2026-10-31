///|
priv struct MeasuredNode {
  element_id : ElementId
  size : Size
  flex_weight : Double
  children : Array[MeasuredNode]
} derive(Eq, Debug, ToJson)

///|
priv struct PlacedNode {
  element_id : ElementId
  frame : Rect
  children : Array[PlacedNode]
  /// Element child indices whose placed frames are overlay-positioned: their
  /// render subtrees are hoisted and painted after the whole tree so popup
  /// content escapes ancestor clip rects.
  overlay_child_indices : Array[Int32]
  /// Hit region: the frame intersected with the accumulated ancestor clip.
  /// Hit-testing uses this instead of paint bounds so clipped content never
  /// wins hit-test over content painted below it.
  hit_rect : Rect
} derive(Eq, Debug, ToJson)

///|
fn PlacedNode::to_layout_result(self : PlacedNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}

///|
fn ElementNode::measure_with_text_system(
  self : ElementNode,
  constraints : Constraints,
  environment~ : Environment,
  style~ : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  environment_id~ : Int32 = 0,
) -> MeasuredNode {
  // Identity of the passed environment (C1): callers that already resolved it
  // pass the id; 0 means "resolve here" (intern scan over distinct envs).
  let env_id = if environment_id == 0 {
    environment_identity(environment)
  } else {
    environment_id
  }
  if !self.has_dirty_layout() &&
    self.layout_cache.cached_measure_constraints == Some(constraints) &&
    self.layout_cache.cached_measure_environment_id == env_id &&
    self.layout_cache.cached_measure_style == Some(style) {
    match self.layout_cache.cached_measured {
      Some(measured) => {
        self.layout_cache.hit_count = self.layout_cache.hit_count + 1
        return measured
      }
      None => ()
    }
  }
  self.layout_cache.miss_count = self.layout_cache.miss_count + 1
  let child_constraints = self.view_node.child_constraints(constraints)
  let child_environment = self.view_node.child_environment(environment)
  let child_environment_id = self.child_environment_identity(
    child_environment, environment, env_id,
  )
  let child_style = self.view_node.child_style(style)
  let children : Array[MeasuredNode] = []
  for child in self.children {
    children.push(
      child.measure_with_text_system(
        child_constraints,
        environment=child_environment,
        style=child_style,
        text_system~,
        environment_id=child_environment_id,
      ),
    )
  }
  let view_node_layout = self.view_node.layout({
    constraints,
    child_sizes: children.map(child => child.size),
    child_flex_weights: children.map(child => child.flex_weight),
    state: self.control.view_state,
    text_system,
    environment,
    style,
  })
  let measured = {
    element_id: self.id,
    size: constraints.constrain(view_node_layout.size),
    flex_weight: self.view_node.flex_weight(),
    children,
  }
  self.layout_cache.cached_measure_constraints = Some(constraints)
  self.layout_cache.cached_measure_environment_id = env_id
  self.layout_cache.cached_measure_style = Some(style)
  self.layout_cache.cached_measured = Some(measured)
  self.dirty.needs_layout = false
  self.refresh_descendant_dirty_flags()
  measured
}

///|
/// Identity of this node's child environment (C1). Most nodes pass the
/// environment through unchanged, so the parent's id forwards and the
/// per-element cache check is an integer compare. Environment-scoping
/// modifiers produce a new value whose id resolves through the intern table.
/// Classification is node-kind-derived and memoized per element: a scoping
/// modifier's output is never structurally equal to its input, and a
/// passthrough closure's output always is — identity is content, so a
/// structurally equal child environment shares the parent's id.
fn ElementNode::child_environment_identity(
  self : ElementNode,
  child_environment : Environment,
  environment : Environment,
  environment_id : Int32,
) -> Int32 {
  if !self.layout_cache.child_environment_classified {
    self.layout_cache.child_environment_classified = true
    self.layout_cache.child_environment_passthrough = child_environment ==
      environment
  }
  if self.layout_cache.child_environment_passthrough {
    environment_id
  } else {
    environment_identity(child_environment)
  }
}

///|
fn ElementNode::place_with_text_system(
  self : ElementNode,
  bounds : Rect,
  environment~ : Environment,
  style~ : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  overlay_overrides~ : Array[(Int32, Array[(Int32, Rect)])] = [],
  overlay_affected~ : DirtyIdSet? = None,
  environment_id~ : Int32 = 0,
) -> PlacedNode {
  let env_id = if environment_id == 0 {
    environment_identity(environment)
  } else {
    environment_id
  }
  if !self.has_dirty_layout() &&
    self.layout_cache.cached_place_frame == Some(bounds) &&
    self.layout_cache.cached_place_environment_id == env_id &&
    self.layout_cache.cached_place_style == Some(style) &&
    overlay_overrides.is_empty() {
    match self.layout_cache.cached_placed {
      Some(placed) => {
        self.layout_cache.hit_count = self.layout_cache.hit_count + 1
        return placed
      }
      None => ()
    }
  }
  let constraints = Constraints::tight(bounds.size)
  let measured = self.measure_with_text_system(
    constraints,
    environment~,
    style~,
    text_system~,
    environment_id=env_id,
  )
  let placed = self.place_measured_with_text_system(
    measured,
    bounds,
    environment~,
    style~,
    text_system~,
    overlay_overrides~,
    overlay_affected~,
    environment_id=env_id,
  )
  self.layout_cache.cached_place_frame = Some(bounds)
  self.layout_cache.cached_place_environment_id = env_id
  self.layout_cache.cached_place_style = Some(style)
  self.layout_cache.cached_placed = Some(placed)
  self.refresh_descendant_dirty_flags()
  placed
}

///|
fn ElementNode::place_measured_with_text_system(
  self : ElementNode,
  measured : MeasuredNode,
  frame : Rect,
  environment~ : Environment,
  style~ : ViewStyle,
  text_system~ : TextSystem,
  overlay_overrides~ : Array[(Int32, Array[(Int32, Rect)])] = [],
  overlay_affected~ : DirtyIdSet? = None,
  accumulated_clip~ : Rect? = None,
  fit_measured_sizes~ : Bool = false,
  environment_id~ : Int32 = 0,
) -> PlacedNode {
  // C3: per-node place cache. The overlay re-place walks the tree with
  // overrides applied; nodes outside the affected spines reuse their previous
  // placed subtree instead of re-running `view_node.layout`, so an open
  // dropdown no longer re-places the whole application every frame. The key
  // must cover every input `view_node.layout` reads: the frame (tight
  // constraints), the interned environment, the style, the accumulated clip
  // (hit rects), the ADR 0035 fit flag, and the view-state revision (state
  // flips change layout output without necessarily marking layout dirty).
  // Nodes on an override spine — or carrying an override themselves — are
  // forced to re-place so the overrides are always consumed.
  let env_id = if environment_id == 0 {
    environment_identity(environment)
  } else {
    environment_id
  }
  let forced = (match overlay_affected {
      Some(affected) => affected.contains(self.id)
      None => false
    }) ||
    overlay_overrides_for(overlay_overrides, self.id.value()) is Some(_)
  if !forced &&
    !self.has_dirty_layout() &&
    self.layout_cache.cached_placed is Some(_) &&
    self.layout_cache.cached_place_frame == Some(frame) &&
    self.layout_cache.cached_place_environment_id == env_id &&
    self.layout_cache.cached_place_style == Some(style) &&
    self.layout_cache.cached_place_clip == accumulated_clip &&
    self.layout_cache.cached_place_fit == fit_measured_sizes &&
    self.layout_cache.cached_place_state_revision == self.control.state_revision {
    match self.layout_cache.cached_placed {
      Some(placed) => {
        self.layout_cache.hit_count = self.layout_cache.hit_count + 1
        return placed
      }
      None => ()
    }
  }
  // A tight-fit re-measure already settled this subtree under the final
  // frame's tight constraints, so its `measured` child sizes are the wrapped
  // sizes; feed them to `layout` instead of the unbounded intrinsic sizes so
  // internal frames reflect the extent the children actually occupy (ADR 0035).
  let child_sizes : Array[Size] = []
  if fit_measured_sizes && measured.children.length() == self.children.length() {
    for index, child in self.children {
      child_sizes.push(
        match measured.children.get(index) {
          Some(node) => node.size
          None => child.intrinsic_size(text_system~)
        },
      )
    }
  } else {
    for child in self.children {
      child_sizes.push(child.intrinsic_size(text_system~))
    }
  }
  let result = self.view_node.layout({
    constraints: Constraints::tight(frame.size),
    child_sizes,
    child_flex_weights: measured.children.map(child => child.flex_weight),
    state: self.control.view_state,
    text_system,
    environment,
    style,
  })
  let child_frames = result.child_frames.map(child_frame => {
    child_frame.offset(dx=frame.origin.x, dy=frame.origin.y)
  })
  let overrides = overlay_overrides_for(overlay_overrides, self.id.value())
  let child_environment = self.view_node.child_environment(environment)
  let child_environment_id = self.child_environment_identity(
    child_environment, environment, env_id,
  )
  let child_style = self.view_node.child_style(style)
  // A clip container folds its own frame into the accumulated ancestor clip;
  // children inherit that, and their hit regions are the intersection.
  let child_clip : Rect? = if result.clips_children {
    match accumulated_clip {
      Some(clip) => frame.intersection(clip)
      None => Some(frame)
    }
  } else {
    accumulated_clip
  }
  let children : Array[PlacedNode] = []
  let overlay_child_indices : Array[Int32] = []
  for index, child in self.children {
    if index < child_frames.length() && index < measured.children.length() {
      // Overlay-positioned children skip their parent-assigned provisional
      // frame and are placed directly at the absolute rect computed by the
      // post-layout placement pass.
      let is_overlay = overlay_child_override(overrides, index) is Some(_)
      let child_frame = match overlay_child_override(overrides, index) {
        Some(override_frame) => override_frame
        None => child_frames[index]
      }
      // Tight-fit parents (flex with weighted children) measure children
      // under looser constraints than the frame they finally place them in.
      // When the final frame is a different size, re-measure that subtree
      // under tight constraints so its internal layout re-wraps to the
      // extent it actually occupies; the measure memo is constraint-keyed, so
      // this is cache-safe and stays silent once the subtree settles (ADR 0035).
      let refits = result.child_frames_tight &&
        child_frame.size != measured.children[index].size
      let child_measured = if refits {
        child.measure_with_text_system(
          Constraints::tight(child_frame.size),
          environment=child_environment,
          style=child_style,
          text_system~,
          environment_id=child_environment_id,
        )
      } else {
        measured.children[index]
      }
      children.push(
        child.place_measured_with_text_system(
          child_measured,
          child_frame,
          environment=child_environment,
          style=child_style,
          text_system~,
          overlay_overrides~,
          overlay_affected~,
          environment_id=child_environment_id,
          // Hoisted popups escape ancestor clips by design.
          accumulated_clip=if is_overlay { None } else { child_clip },
          fit_measured_sizes=refits || fit_measured_sizes,
        ),
      )
      if is_overlay {
        overlay_child_indices.push(index)
      }
    }
  }
  let placed : PlacedNode = {
    element_id: self.id,
    frame,
    children,
    overlay_child_indices,
    hit_rect: match accumulated_clip {
      Some(clip) =>
        match frame.intersection(clip) {
          Some(hit) => hit
          None => Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
        }
      None => frame
    },
  }
  // C3: store the per-node entry. `place_with_text_system` re-stores the
  // frame/environment/style fields for its root call; storing them here as
  // well keeps inner nodes' entries complete.
  self.layout_cache.cached_place_frame = Some(frame)
  self.layout_cache.cached_place_environment_id = env_id
  self.layout_cache.cached_place_style = Some(style)
  self.layout_cache.cached_place_clip = accumulated_clip
  self.layout_cache.cached_place_fit = fit_measured_sizes
  self.layout_cache.cached_place_state_revision = self.control.state_revision
  self.layout_cache.cached_placed = Some(placed)
  placed
}

///|
fn overlay_overrides_for(
  overrides : Array[(Int32, Array[(Int32, Rect)])],
  element_id : Int32,
) -> Array[(Int32, Rect)]? {
  for entry in overrides {
    if entry.0 == element_id {
      return Some(entry.1)
    }
  }
  None
}

///|
fn overlay_child_override(
  pairs : Array[(Int32, Rect)]?,
  index : Int32,
) -> Rect? {
  match pairs {
    Some(pairs) =>
      for pair in pairs {
        if pair.0 == index {
          return Some(pair.1)
        }
      }
    None => ()
  }
  None
}

///|
fn ElementNode::intrinsic_size(
  self : ElementNode,
  text_system~ : TextSystem,
) -> Size {
  if !self.has_dirty_layout() {
    match self.layout_cache.cached_intrinsic_size {
      Some(size) => return size
      None => ()
    }
    match self.layout_cache.cached_measured {
      Some(measured) => return measured.size
      None => ()
    }
  }
  let size = self.view_node.layout({
      constraints: Constraints::unbounded(),
      child_sizes: self.children.map(child => child.intrinsic_size(text_system~)),
      child_flex_weights: self.children.map(child => {
        child.view_node.flex_weight()
      }),
      state: self.control.view_state,
      // Thread the host's text system instead of the core fallback. Intrinsic
      // sizing feeds the child_sizes handed to a parent during placement, and
      // the fallback estimates advances from font size alone, which
      // underestimates real glyph runs. A view then receives a frame narrower
      // than the glyphs it draws, and renderers clip glyphs to that frame,
      // truncating the text.
      text_system,
      environment: Environment::neutral(),
      style: ViewStyle::empty(),
    }).size
  self.layout_cache.cached_intrinsic_size = Some(size)
  size
}
