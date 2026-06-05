///|
fn main {
  @windows_wgpu.run_renderer_proof_smoke() catch {
    err => abort("Windows native WGPU renderer proof failed: \{err.message()}")
  }
}
