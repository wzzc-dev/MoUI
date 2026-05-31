///|
/// How a render pass should initialize its target pixels.
#warnings("-deprecated_syntax")
pub(all) enum RenderPassLoadOp {
  LoadExisting
  ClearBeforeDraw
  DontCareLoad
} derive(Debug, Eq)

///|
pub impl Default for RenderPassLoadOp with fn default() {
  LoadExisting
}

///|
pub fn RenderPassLoadOp::needs_clear(self : RenderPassLoadOp) -> Bool {
  self is ClearBeforeDraw
}

///|
pub fn RenderPassLoadOp::preserves_existing_pixels(
  self : RenderPassLoadOp,
) -> Bool {
  self is LoadExisting
}

///|
/// How a render pass should finish target pixels after drawing.
#warnings("-deprecated_syntax")
pub(all) enum RenderPassStoreOp {
  StorePixels
  DiscardPixels
  PresentPixels
} derive(Debug, Eq)

///|
pub impl Default for RenderPassStoreOp with fn default() {
  StorePixels
}

///|
pub fn RenderPassStoreOp::keeps_pixels(self : RenderPassStoreOp) -> Bool {
  self is StorePixels || self is PresentPixels
}

///|
pub fn RenderPassStoreOp::needs_present(self : RenderPassStoreOp) -> Bool {
  self is PresentPixels
}

///|
/// Value-layer boundary for a single render pass.
pub(all) struct RenderPassDescriptor {
  surface : SurfaceDescriptor
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
pub fn RenderPassDescriptor::new(
  surface : SurfaceDescriptor,
  bounds? : IRect? = None,
  load_op? : RenderPassLoadOp = LoadExisting,
  clear_color? : Color? = None,
  store_op? : RenderPassStoreOp = StorePixels,
) -> RenderPassDescriptor {
  let load_op = resolved_render_pass_load(load_op, clear_color)
  {
    surface,
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
