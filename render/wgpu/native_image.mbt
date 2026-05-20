///|
struct ImageTexture {
  texture : @wgpu_mbt.Texture
  texture_view : @wgpu_mbt.TextureView
  width : Int
  height : Int
}

///|
struct NativeImagePipeline {
  shader : @wgpu_mbt.ShaderModule
  pipeline : @wgpu_mbt.RenderPipeline
  bind_group_layout : @wgpu_mbt.BindGroupLayout
  pipeline_layout : @wgpu_mbt.PipelineLayout
  sampler : @wgpu_mbt.Sampler
}

///|
fn NativeImagePipeline::new(
  device : @wgpu_mbt.Device,
  format : @wgpu_mbt.TextureFormat,
) -> NativeImagePipeline {
  let shader = device.create_shader_module_wgsl(image_shader_wgsl())
  let bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let pipeline_layout = device.create_pipeline_layout_1(bind_group_layout)
  let pipeline = create_image_pipeline(device, shader, format, pipeline_layout)
  let sampler = device.create_sampler_linear_clamp()
  { shader, pipeline, bind_group_layout, pipeline_layout, sampler }
}

///|
fn create_image_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(image_vertex_stride, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32, 16UL, 2U)
  try! builder.create_pipeline(device)
}

///|
let image_vertex_stride : UInt64 = 20UL

///|
fn image_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) opacity: f32,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) opacity: f32,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.opacity = opacity;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var image_sampler : sampler;
    #|@group(0) @binding(1) var image_texture : texture_2d<f32>;
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let sample = textureSample(image_texture, image_sampler, in.uv);
    #|  return vec4<f32>(sample.rgb, sample.a * in.opacity);
    #|}
    #|
  shader
}
