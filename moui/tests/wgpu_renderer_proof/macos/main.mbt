///|
fn main {
  @macos_wgpu.run_renderer_proof_smoke() catch {
    err => abort("macOS native WGPU renderer smoke failed: \{err.message()}")
  }
}
