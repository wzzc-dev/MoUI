///|
/// How a render pass should initialize its target pixels.
#derive(Debug, Eq)
pub(all) enum RenderPassLoadOp {
  LoadExisting
  ClearBeforeDraw
  DontCareLoad
}

///|
pub extend RenderPassLoadOp with Debug::{to_repr}

///|
pub extend RenderPassLoadOp with Default::{default}

///|
pub extend RenderPassLoadOp with Eq::{not_equal, equal}

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
#derive(Debug, Eq)
pub(all) enum RenderPassStoreOp {
  StorePixels
  DiscardPixels
  PresentPixels
}

///|
pub extend RenderPassStoreOp with Debug::{to_repr}

///|
pub extend RenderPassStoreOp with Default::{default}

///|
pub extend RenderPassStoreOp with Eq::{not_equal, equal}

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
