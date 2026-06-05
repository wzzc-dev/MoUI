///|
fn main {
  @linux_wgpu.run_renderer_proof_smoke() catch {
    err => abort("Linux native WGPU renderer proof failed: \{err.message()}")
  }
}
