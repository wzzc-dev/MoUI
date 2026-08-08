///|
fn main {
  @wgpu_renderer.native_renderer_smoke(
    platform_label="macos",
    text_engine=@wgpu_coretext.coretext_text_engine(),
  ) catch {
    err => abort("macOS native WGPU renderer smoke failed: \{err.message()}")
  }
}
