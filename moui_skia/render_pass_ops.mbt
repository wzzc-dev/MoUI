///|
/// How a render pass should initialize its target pixels.
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
