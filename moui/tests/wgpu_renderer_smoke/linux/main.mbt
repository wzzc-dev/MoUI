///|
fn main {
  @linux_wgpu.run_renderer_smoke() catch {
    err => abort("Linux native WGPU renderer smoke failed: \{err.message()}")
  }
}
