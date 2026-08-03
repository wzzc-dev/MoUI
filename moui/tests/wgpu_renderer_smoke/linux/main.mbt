///|
fn main {
  @wgpu_renderer.native_renderer_smoke(
    platform_label="linux",
    text_engine=@wgpu_fontconfig.fontconfig_text_engine(),
  ) catch {
    err => abort("Linux native WGPU renderer smoke failed: \{err.message()}")
  }
}
