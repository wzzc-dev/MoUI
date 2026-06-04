///|
/// Value-layer boundary for a single render pass.
pub(all) struct RenderPassDescriptor {
  surface : SurfaceDescriptor
  target_key : RendererResourceKey?
  bounds : IRect
  load_op : RenderPassLoadOp
  clear_color : Color?
  store_op : RenderPassStoreOp
} derive(Debug, Eq)

///|
fn normalized_render_pass_bounds(
  surface : SurfaceDescriptor,
  bounds : IRect?,
) -> IRect {
  let surface_bounds = surface.bounds()
  if surface_bounds.is_empty() {
    IRect::empty()
  } else {
    let requested = match bounds {
      None => surface_bounds
      Some(bounds) => bounds.sorted()
    }
    match surface_bounds.intersect(requested) {
      None => IRect::empty()
      Some(bounds) => bounds
    }
  }
}

///|
fn resolved_render_pass_load(
  load_op : RenderPassLoadOp,
  clear_color : Color?,
) -> RenderPassLoadOp {
  match clear_color {
    None => load_op
    Some(_) => ClearBeforeDraw
  }
}

///|
fn resolved_render_pass_clear_color(
  load_op : RenderPassLoadOp,
  clear_color : Color?,
) -> Color? {
  if load_op.needs_clear() {
    match clear_color {
      None => Some(Color::transparent())
      Some(color) => Some(color)
    }
  } else {
    None
  }
}

///|
fn default_render_pass_store_for_target(
  target : SurfaceTargetDescriptor,
) -> RenderPassStoreOp {
  if target.needs_present() {
    PresentPixels
  } else {
    StorePixels
  }
}

///|
fn resolved_render_pass_store_for_target(
  target : SurfaceTargetDescriptor,
  store_op : RenderPassStoreOp?,
) -> RenderPassStoreOp {
  match store_op {
    None => default_render_pass_store_for_target(target)
    Some(store_op) => store_op
  }
}

///|
fn normalized_render_pass_target_key(
  surface : SurfaceDescriptor,
  target_key : RendererResourceKey?,
) -> RendererResourceKey? {
  match target_key {
    None => None
    Some(key) =>
      if !key.is_empty() && key.kind == surface.resource_key().kind {
        Some(key)
      } else {
        None
      }
  }
}

///|
pub fn RenderPassDescriptor::new(
  surface : SurfaceDescriptor,
  target_key? : RendererResourceKey? = None,
  bounds? : IRect? = None,
  load_op? : RenderPassLoadOp = LoadExisting,
  clear_color? : Color? = None,
  store_op? : RenderPassStoreOp = StorePixels,
) -> RenderPassDescriptor {
  let load_op = resolved_render_pass_load(load_op, clear_color)
  {
    surface,
    target_key: normalized_render_pass_target_key(surface, target_key),
    bounds: normalized_render_pass_bounds(surface, bounds),
    load_op,
    clear_color: resolved_render_pass_clear_color(load_op, clear_color),
    store_op,
  }
}

///|
pub fn RenderPassDescriptor::clear(
  surface : SurfaceDescriptor,
  color : Color,
  bounds? : IRect? = None,
  store_op? : RenderPassStoreOp = StorePixels,
) -> RenderPassDescriptor {
  RenderPassDescriptor::new(
    surface,
    bounds~,
    load_op=ClearBeforeDraw,
    clear_color=Some(color),
    store_op~,
  )
}

///|
pub fn RenderPassDescriptor::for_target(
  target : SurfaceTargetDescriptor,
  bounds? : IRect? = None,
  load_op? : RenderPassLoadOp = LoadExisting,
  clear_color? : Color? = None,
  store_op? : RenderPassStoreOp? = None,
) -> RenderPassDescriptor {
  RenderPassDescriptor::new(
    target.surface,
    target_key=Some(target.resource_key()),
    bounds~,
    load_op~,
    clear_color~,
    store_op=resolved_render_pass_store_for_target(target, store_op),
  )
}

///|
pub fn RenderPassDescriptor::clear_target(
  target : SurfaceTargetDescriptor,
  color : Color,
  bounds? : IRect? = None,
  store_op? : RenderPassStoreOp? = None,
) -> RenderPassDescriptor {
  RenderPassDescriptor::for_target(
    target,
    bounds~,
    load_op=ClearBeforeDraw,
    clear_color=Some(color),
    store_op~,
  )
}

///|
pub fn RenderPassDescriptor::present(
  surface : SurfaceDescriptor,
  bounds? : IRect? = None,
  clear_color? : Color? = None,
) -> RenderPassDescriptor {
  RenderPassDescriptor::new(
    surface,
    bounds~,
    clear_color~,
    store_op=PresentPixels,
  )
}

///|
pub fn RenderPassDescriptor::is_empty(self : RenderPassDescriptor) -> Bool {
  self.bounds.is_empty()
}

///|
pub fn RenderPassDescriptor::needs_clear(self : RenderPassDescriptor) -> Bool {
  self.load_op.needs_clear()
}

///|
pub fn RenderPassDescriptor::needs_present(self : RenderPassDescriptor) -> Bool {
  self.store_op.needs_present()
}

///|
pub fn RenderPassDescriptor::keeps_pixels(self : RenderPassDescriptor) -> Bool {
  self.store_op.keeps_pixels()
}

///|
pub fn RenderPassDescriptor::is_msaa(self : RenderPassDescriptor) -> Bool {
  self.surface.is_msaa()
}

///|
pub fn RenderPassDescriptor::has_target_binding(
  self : RenderPassDescriptor,
) -> Bool {
  self.target_key is Some(_)
}

///|
pub fn RenderPassDescriptor::is_bound_to_target(
  self : RenderPassDescriptor,
  target : SurfaceTargetDescriptor,
) -> Bool {
  self.surface == target.surface &&
  (match self.target_key {
    None => true
    Some(key) => key == target.resource_key()
  })
}

///|
pub fn RenderPassDescriptor::resource_descriptor(
  self : RenderPassDescriptor,
) -> RendererResourceDescriptor {
  let descriptor = self.surface.resource_descriptor()
  match self.target_key {
    None => descriptor
    Some(key) =>
      RendererResourceDescriptor::new(
        key,
        byte_size=descriptor.byte_size,
        cacheable=descriptor.cacheable,
      )
  }
}

///|
pub fn RenderPassDescriptor::with_bounds(
  self : RenderPassDescriptor,
  bounds : IRect,
) -> RenderPassDescriptor {
  { ..self, bounds: normalized_render_pass_bounds(self.surface, Some(bounds)) }
}

///|
pub fn RenderPassDescriptor::with_load_op(
  self : RenderPassDescriptor,
  load_op : RenderPassLoadOp,
) -> RenderPassDescriptor {
  let clear_color = if load_op.needs_clear() { self.clear_color } else { None }
  RenderPassDescriptor::new(
    self.surface,
    target_key=self.target_key,
    bounds=Some(self.bounds),
    load_op~,
    clear_color~,
    store_op=self.store_op,
  )
}

///|
pub fn RenderPassDescriptor::with_clear_color(
  self : RenderPassDescriptor,
  color : Color,
) -> RenderPassDescriptor {
  RenderPassDescriptor::new(
    self.surface,
    target_key=self.target_key,
    bounds=Some(self.bounds),
    load_op=ClearBeforeDraw,
    clear_color=Some(color),
    store_op=self.store_op,
  )
}

///|
pub fn RenderPassDescriptor::without_clear(
  self : RenderPassDescriptor,
) -> RenderPassDescriptor {
  RenderPassDescriptor::new(
    self.surface,
    target_key=self.target_key,
    bounds=Some(self.bounds),
    load_op=LoadExisting,
    store_op=self.store_op,
  )
}

///|
pub fn RenderPassDescriptor::with_store_op(
  self : RenderPassDescriptor,
  store_op : RenderPassStoreOp,
) -> RenderPassDescriptor {
  { ..self, store_op, }
}
