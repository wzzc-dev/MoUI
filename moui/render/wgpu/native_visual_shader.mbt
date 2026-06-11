///|
let visual_mode_fill : Double = 0.0

///|
let visual_mode_stroke : Double = 1.0

///|
let visual_mode_shadow : Double = 2.0

///|
let visual_mode_path : Double = 3.0

///|
let visual_vertex_stride : UInt64 = 88UL

///|
let advanced_vertex_stride : UInt64 = 176UL

///|
fn visual_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) local: vec2<f32>,
    #|  @location(1) size_radius_mode_stroke: vec4<f32>,
    #|  @location(2) blur_start: vec4<f32>,
    #|  @location(3) end: vec2<f32>,
    #|  @location(4) color0: vec4<f32>,
    #|  @location(5) color1: vec4<f32>,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) local: vec2<f32>,
    #|  @location(2) size_radius_mode_stroke: vec4<f32>,
    #|  @location(3) blur_start: vec4<f32>,
    #|  @location(4) end: vec2<f32>,
    #|  @location(5) color0: vec4<f32>,
    #|  @location(6) color1: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.local = local;
    #|  out.size_radius_mode_stroke = size_radius_mode_stroke;
    #|  out.blur_start = blur_start;
    #|  out.end = end;
    #|  out.color0 = color0;
    #|  out.color1 = color1;
    #|  return out;
    #|}
    #|
    #|fn rounded_box_sdf(p: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    #|  let r = min(radius, min(half_size.x, half_size.y));
    #|  let q = abs(p) - (half_size - vec2<f32>(r, r));
    #|  return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    #|}
    #|
    #|fn linear_gradient_color(local: vec2<f32>, start: vec2<f32>, end: vec2<f32>, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let axis = end - start;
    #|  let denom = max(dot(axis, axis), 0.0001);
    #|  let t = clamp(dot(local - start, axis) / denom, 0.0, 1.0);
    #|  return mix(c0, c1, t);
    #|}
    #|
    #|fn radial_gradient_color(local: vec2<f32>, center: vec2<f32>, radius: f32, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let t = clamp(distance(local, center) / max(radius, 0.0001), 0.0, 1.0);
    #|  return mix(c0, c1, t);
    #|}
    #|
    #|fn brush_color(local: vec2<f32>, start: vec2<f32>, end: vec2<f32>, c0: vec4<f32>, c1: vec4<f32>, kind: f32) -> vec4<f32> {
    #|  if kind > 0.5 {
    #|    return radial_gradient_color(local, start, end.x, c0, c1);
    #|  }
    #|  return linear_gradient_color(local, start, end, c0, c1);
    #|}
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let width = in.size_radius_mode_stroke.x;
    #|  let height = in.size_radius_mode_stroke.y;
    #|  let radius = in.size_radius_mode_stroke.z;
    #|  let mode = in.size_radius_mode_stroke.w;
    #|  let stroke_width = in.blur_start.x;
    #|  let blur_radius = in.blur_start.y;
    #|  let start = in.blur_start.zw;
    #|  let end = in.end;
    #|  if mode > 2.5 {
    #|    return brush_color(in.local, start, end, in.color0, in.color1, blur_radius);
    #|  }
    #|  let center = vec2<f32>(width * 0.5, height * 0.5);
    #|  let half_size = center;
    #|  let dist = rounded_box_sdf(in.local - center, half_size, radius);
    #|  var alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    #|  if mode > 1.5 {
    #|    let spread = max(blur_radius, 1.0);
    #|    alpha = 1.0 - smoothstep(-spread, spread, dist);
    #|    alpha = alpha * alpha * in.color0.a;
    #|    return vec4<f32>(in.color0.rgb, alpha);
    #|  }
    #|  if mode > 0.5 {
    #|    let inner_radius = max(radius - stroke_width, 0.0);
    #|    let inner_half = max(half_size - vec2<f32>(stroke_width, stroke_width), vec2<f32>(0.0, 0.0));
    #|    let inner_dist = rounded_box_sdf(in.local - center, inner_half, inner_radius);
    #|    let inner_alpha = 1.0 - smoothstep(-0.5, 0.5, inner_dist);
    #|    alpha = max(alpha - inner_alpha, 0.0);
    #|  }
    #|  let color = brush_color(in.local, start, end, in.color0, in.color1, blur_radius);
    #|  return vec4<f32>(color.rgb, color.a * alpha);
    #|}
    #|
  shader
}

///|
fn advanced_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) meta0: vec4<f32>,
    #|  @location(2) meta1: vec4<f32>,
    #|  @location(3) color0: vec4<f32>,
    #|  @location(4) color1: vec4<f32>,
    #|  @location(5) matrix0: vec4<f32>,
    #|  @location(6) matrix1: vec4<f32>,
    #|  @location(7) matrix2: vec4<f32>,
    #|  @location(8) matrix3: vec4<f32>,
    #|  @location(9) matrix4: vec4<f32>,
    #|  @location(10) rect_mask: vec4<f32>,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) meta0: vec4<f32>,
    #|  @location(3) meta1: vec4<f32>,
    #|  @location(4) color0: vec4<f32>,
    #|  @location(5) color1: vec4<f32>,
    #|  @location(6) matrix0: vec4<f32>,
    #|  @location(7) matrix1: vec4<f32>,
    #|  @location(8) matrix2: vec4<f32>,
    #|  @location(9) matrix3: vec4<f32>,
    #|  @location(10) matrix4: vec4<f32>,
    #|  @location(11) rect_mask: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.meta0 = meta0;
    #|  out.meta1 = meta1;
    #|  out.color0 = color0;
    #|  out.color1 = color1;
    #|  out.matrix0 = matrix0;
    #|  out.matrix1 = matrix1;
    #|  out.matrix2 = matrix2;
    #|  out.matrix3 = matrix3;
    #|  out.matrix4 = matrix4;
    #|  out.rect_mask = rect_mask;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var layer_sampler : sampler;
    #|@group(0) @binding(1) var layer_texture : texture_2d<f32>;
    #|@group(0) @binding(2) var backdrop_texture : texture_2d<f32>;
    #|
    #|fn checker(local: vec2<f32>, amount: f32, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let scale = max(amount, 8.0);
    #|  let cell = floor(local * scale);
    #|  let alt = (i32(cell.x) + i32(cell.y)) & 1;
    #|  if alt == 0 {
    #|    return c0;
    #|  }
    #|  return c1;
    #|}
    #|
    #|fn vignette(local: vec2<f32>, amount: f32, c0: vec4<f32>) -> vec4<f32> {
    #|  let centered = local * 2.0 - vec2<f32>(1.0, 1.0);
    #|  let fade = 1.0 - smoothstep(0.25, max(amount, 0.8), length(centered));
    #|  return vec4<f32>(c0.rgb * fade, c0.a);
    #|}
    #|
    #|fn blur_sample(uv: vec2<f32>, amount: f32) -> vec4<f32> {
    #|  let dims = vec2<f32>(textureDimensions(layer_texture));
    #|  let step = vec2<f32>(1.0, 1.0) / max(dims, vec2<f32>(1.0, 1.0));
    #|  let radius = max(amount, 1.0);
    #|  var color = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0, -1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 0.0, -1.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0, -1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0,  0.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv) * 0.25;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0,  0.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0,  1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 0.0,  1.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0,  1.0)) * 0.0625;
    #|  return color;
    #|}
    #|
    #|fn rounded_box_sdf_advanced(p: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    #|  let r = min(radius, min(half_size.x, half_size.y));
    #|  let q = abs(p) - (half_size - vec2<f32>(r, r));
    #|  return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    #|}
    #|
    #|fn apply_filter(color: vec4<f32>, kind: i32, amount: f32, m0: vec4<f32>, m1: vec4<f32>, m2: vec4<f32>, m3: vec4<f32>, m4: vec4<f32>) -> vec4<f32> {
    #|  if kind == 2 {
    #|    let luma = dot(color.rgb, vec3<f32>(0.2126, 0.7152, 0.0722));
    #|    return vec4<f32>(mix(vec3<f32>(luma, luma, luma), color.rgb, amount), color.a);
    #|  }
    #|  if kind == 3 {
    #|    return vec4<f32>(color.rgb * amount, color.a);
    #|  }
    #|  if kind == 4 {
    #|    return vec4<f32>((color.rgb - vec3<f32>(0.5, 0.5, 0.5)) * amount + vec3<f32>(0.5, 0.5, 0.5), color.a);
    #|  }
    #|  if kind == 5 {
    #|    let v = vec4<f32>(color.rgb, color.a);
    #|    return vec4<f32>(
    #|      dot(v, m0) + m4.x,
    #|      dot(v, m1) + m4.y,
    #|      dot(v, m2) + m4.z,
    #|      dot(v, m3) + m4.w,
    #|    );
    #|  }
    #|  return color;
    #|}
    #|
    #|fn overlay_channel(base: f32, source: f32) -> f32 {
    #|  if base <= 0.5 {
    #|    return 2.0 * base * source;
    #|  }
    #|  return 1.0 - 2.0 * (1.0 - base) * (1.0 - source);
    #|}
    #|
    #|fn overlay_rgb(base: vec3<f32>, source: vec3<f32>) -> vec3<f32> {
    #|  return vec3<f32>(
    #|    overlay_channel(base.r, source.r),
    #|    overlay_channel(base.g, source.g),
    #|    overlay_channel(base.b, source.b),
    #|  );
    #|}
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let opacity = in.meta0.x;
    #|  let shader_kind = i32(in.meta0.z + 0.5);
    #|  let effect_amount = in.meta0.w;
    #|  let filter_kind = i32(in.meta1.z + 0.5);
    #|  let filter_amount = in.meta1.w;
    #|  var sample = textureSample(layer_texture, layer_sampler, in.uv);
    #|  if shader_kind == 1 {
    #|    sample = checker(in.meta1.xy, effect_amount, in.color0, in.color1);
    #|  } else if shader_kind == 2 {
    #|    sample = in.color0;
    #|  } else if shader_kind == 3 {
    #|    sample = mix(in.color0, in.color1, clamp(in.meta1.x, 0.0, 1.0));
    #|  } else if shader_kind == 4 {
    #|    sample = vignette(in.meta1.xy, effect_amount, in.color0);
    #|  } else if shader_kind == 5 {
    #|    sample = in.color0;
    #|  }
    #|  if filter_kind == 1 {
    #|    sample = blur_sample(in.uv, filter_amount);
    #|  }
    #|  sample = apply_filter(sample, filter_kind, filter_amount, in.matrix0, in.matrix1, in.matrix2, in.matrix3, in.matrix4);
    #|  var mask_alpha = 1.0;
    #|  if in.rect_mask.w > 0.5 {
    #|    let mask_size = in.rect_mask.xy;
    #|    let local = in.meta1.xy * mask_size;
    #|    let dist = rounded_box_sdf_advanced(local - mask_size * 0.5, mask_size * 0.5, in.rect_mask.z);
    #|    mask_alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    #|  }
    #|  let blend_mode = i32(in.meta0.y + 0.5);
    #|  let source_alpha = clamp(sample.a * opacity * mask_alpha, 0.0, 1.0);
    #|  var source_rgb = sample.rgb;
    #|  if shader_kind == 0 && sample.a > 0.0001 {
    #|    source_rgb = clamp(sample.rgb / sample.a, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));
    #|  }
    #|  if blend_mode == 1 {
    #|    return vec4<f32>(source_rgb * source_alpha + vec3<f32>(1.0 - source_alpha), source_alpha);
    #|  }
    #|  if blend_mode == 2 {
    #|    return vec4<f32>(source_rgb * source_alpha, source_alpha);
    #|  }
    #|  if blend_mode == 3 {
    #|    let backdrop = textureSample(backdrop_texture, layer_sampler, in.uv);
    #|    let blended = overlay_rgb(backdrop.rgb, source_rgb);
    #|    let out_rgb = mix(backdrop.rgb, blended, source_alpha);
    #|    let out_alpha = source_alpha + backdrop.a * (1.0 - source_alpha);
    #|    return vec4<f32>(out_rgb, out_alpha);
    #|  }
    #|  if blend_mode == 4 {
    #|    return vec4<f32>(source_rgb * source_alpha + vec3<f32>(1.0 - source_alpha), source_alpha);
    #|  }
    #|  if blend_mode == 5 {
    #|    return vec4<f32>(source_rgb * source_alpha, source_alpha);
    #|  }
    #|  return vec4<f32>(source_rgb, source_alpha);
    #|}
    #|
  shader
}
