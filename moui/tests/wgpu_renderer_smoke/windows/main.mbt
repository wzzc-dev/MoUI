///|
fn main {
  @wgpu_renderer.native_renderer_smoke(
    platform_label="windows",
    text_engine=@wgpu_directwrite.directwrite_text_engine(),
  ) catch {
    err => abort("Windows native WGPU renderer smoke failed: \{err.message()}")
  }
}
