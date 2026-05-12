///|
pub fn rect_shader_wgsl() -> String {
  let shader =
    #|struct VSOut { @builtin(position) pos: vec4<f32> };
    #|@vertex
    #|fn vs_main(@builtin(vertex_index) vid: u32) -> VSOut {
    #|  var positions = array<vec2<f32>, 3>(vec2<f32>(-1.0, -1.0), vec2<f32>(3.0, -1.0), vec2<f32>(-1.0, 3.0));
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(positions[vid], 0.0, 1.0);
    #|  return out;
    #|}
    #|@fragment
    #|fn fs_main() -> @location(0) vec4<f32> { return vec4<f32>(0.12, 0.36, 0.95, 1.0); }
    #|
  shader
}
