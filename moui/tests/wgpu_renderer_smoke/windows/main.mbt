///|
fn main {
  @windows_wgpu.run_renderer_smoke() catch {
    err => abort("Windows native WGPU renderer smoke failed: \{err.message()}")
  }
}
