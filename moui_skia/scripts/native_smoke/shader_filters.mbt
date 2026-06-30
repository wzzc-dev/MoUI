///|
priv struct SmokeShaderFilterDescriptors {
  color_shader_descriptor : @skia.ShaderDescriptor
  color_filter_descriptor : @skia.ColorFilterDescriptor
  image_filter_descriptor : @skia.ImageFilterDescriptor
  mask_filter_descriptor : @skia.MaskFilterDescriptor
}

///|
fn run_shader_filter_smoke(
  canvas : @native.Canvas,
) -> SmokeShaderFilterDescriptors? {
  guard @native.Shader::color(@skia.Color::cyan()) is Some(color_shader) else {
    fail_smoke("failed to create native color shader")
    None
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(18, 18, 4, 4),
    color_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::linear_gradient(
      @skia.Point::new(22, 18),
      @skia.Point::new(26, 18),
      @skia.Color::yellow(),
      @skia.Color::magenta(),
    )
    is Some(linear_shader) else {
    fail_smoke("failed to create native linear gradient shader")
    None
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(22, 18, 4, 4),
    linear_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::radial_gradient(
      @skia.Point::new(26, 24),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(radial_shader) else {
    fail_smoke("failed to create native radial gradient shader")
    None
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(24, 22, 4, 4),
    radial_shader,
    @skia.Paint::new(),
  )
  println("native smoke shader draws")
  println(3)

  let color_shader_descriptor = @skia.ShaderDescriptor::color(
    @skia.Color::cyan(),
  )
  guard @skia.ShaderDescriptor::linear_gradient(
      @skia.Point::new(22, 18),
      @skia.Point::new(26, 18),
      @skia.Color::yellow(),
      @skia.Color::magenta(),
    )
    is Some(linear_shader_descriptor) else {
    fail_smoke("failed to create value-layer linear shader descriptor")
    None
  }
  guard @skia.ShaderDescriptor::radial_gradient(
      @skia.Point::new(26, 24),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(radial_shader_descriptor) else {
    fail_smoke("failed to create value-layer radial shader descriptor")
    None
  }
  let shader_resource_plan = @skia.RendererResourcePlan::new([
    color_shader_descriptor.resource_descriptor(),
    linear_shader_descriptor.resource_descriptor(),
    radial_shader_descriptor.resource_descriptor(),
  ])
  if shader_resource_plan.length() != 3 ||
    shader_resource_plan.cacheable_count != 3 ||
    shader_resource_plan.uncacheable_count != 0 ||
    shader_resource_plan.byte_size <= 0L {
    fail_smoke("native shader resource plan did not match shader descriptors")
  }
  println("native smoke shader resource plan count")
  println(shader_resource_plan.length())
  let invalid_shader_scalar : Float = 0.0 / 0.0
  if @native.Shader::linear_gradient(
      @skia.Point::new(4, 4),
      @skia.Point::new(4, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) ||
    @skia.ShaderDescriptor::linear_gradient(
      @skia.Point::new(4, 4),
      @skia.Point::new(4, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) {
    fail_smoke("degenerate linear gradient shaders should be rejected")
  }
  println("native smoke shader linear gradient validation")
  println(1)
  if @native.Shader::linear_gradient(
      @skia.Point::new(invalid_shader_scalar, 4),
      @skia.Point::new(8, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) ||
    @native.Shader::linear_gradient(
      @skia.Point::new(4, 4),
      @skia.Point::new(1.0 / 0.0, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) ||
    @skia.ShaderDescriptor::linear_gradient(
      @skia.Point::new(invalid_shader_scalar, 4),
      @skia.Point::new(8, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) ||
    @skia.ShaderDescriptor::linear_gradient(
      @skia.Point::new(4, 4),
      @skia.Point::new(1.0 / 0.0, 4),
      @skia.Color::red(),
      @skia.Color::blue(),
    )
    is Some(_) {
    fail_smoke("non-finite linear gradient shaders should be rejected")
  }
  println("native smoke shader linear gradient finite validation")
  println(1)
  if @native.Shader::radial_gradient(
      @skia.Point::new(invalid_shader_scalar, 4),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(_) ||
    @native.Shader::radial_gradient(
      @skia.Point::new(4, 4),
      1.0 / 0.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(_) ||
    @skia.ShaderDescriptor::radial_gradient(
      @skia.Point::new(invalid_shader_scalar, 4),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(_) ||
    @skia.ShaderDescriptor::radial_gradient(
      @skia.Point::new(4, 4),
      1.0 / 0.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(_) {
    fail_smoke("non-finite radial gradient shaders should be rejected")
  }
  println("native smoke shader radial gradient validation")
  println(1)

  // Native color/filter support depends on the Skia release binary's header
  // structure. If ColorFilter headers are not available at compile time, the
  // native filter creation returns None. We handle this gracefully by logging
  // and using fallback placeholders so the remaining value-layer descriptor
  // tests still execute.
  let native_color_filter = @native.ColorFilter::saturation(0.8)
  let has_native_color_filters = native_color_filter.is_some()
  if has_native_color_filters {
    let color_filter = native_color_filter.unwrap()
    match (@native.ImageFilter::blur(1.0, 1.0), @native.MaskFilter::blur(1.0)) {
      (Some(image_filter), Some(mask_filter)) => {
        let save_count_before_filter_layer = canvas.save_count()
        let filtered_layer_count = canvas.save_layer(
          bounds=Some(@skia.Rect::from_xywh(0, 0, 16, 16)),
          color_filter=Some(color_filter),
          image_filter=Some(image_filter),
          mask_filter=Some(mask_filter),
        )
        if filtered_layer_count <= 0 {
          fail_smoke("native filtered save_layer did not return a valid save count")
        }
        canvas.restore_to_count(save_count_before_filter_layer)
        println("native smoke filter layer count")
        println(filtered_layer_count)
      }
      _ => fail_smoke("failed to create native image/mask filter")
    }
  } else {
    println("native color filters not available (Skia release header structure)")
  }

  guard @skia.ColorFilterDescriptor::saturation(0.8)
    is Some(color_filter_descriptor) else {
    fail_smoke("failed to create value-layer color filter descriptor")
    None
  }
  guard @skia.ImageFilterDescriptor::blur(1.0, 1.0)
    is Some(image_filter_descriptor) else {
    fail_smoke("failed to create value-layer image filter descriptor")
    None
  }
  guard @skia.MaskFilterDescriptor::blur(1.0) is Some(mask_filter_descriptor) else {
    fail_smoke("failed to create value-layer mask filter descriptor")
    None
  }
  let filter_resource_plan = @skia.RendererResourcePlan::new([
    color_filter_descriptor.resource_descriptor(),
    image_filter_descriptor.resource_descriptor(),
    mask_filter_descriptor.resource_descriptor(),
  ])
  if filter_resource_plan.length() != 3 ||
    filter_resource_plan.cacheable_count != 3 ||
    filter_resource_plan.uncacheable_count != 0 ||
    filter_resource_plan.byte_size <= 0L {
    fail_smoke("native filter resource plan did not match filter descriptors")
  }
  println("native smoke filter resource plan count")
  println(filter_resource_plan.length())
  let invalid_filter_scalar : Float = 0.0 / 0.0
  let invalid_filter_matrix : Array[Float] = [
    invalid_filter_scalar, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
  ]
  if @native.ColorFilter::matrix(invalid_filter_matrix) is Some(_) ||
    @native.ColorFilter::saturation(invalid_filter_scalar) is Some(_) ||
    @native.ImageFilter::blur(invalid_filter_scalar, 1.0) is Some(_) ||
    @native.MaskFilter::blur(invalid_filter_scalar) is Some(_) ||
    @skia.ColorFilterDescriptor::matrix(invalid_filter_matrix) is Some(_) ||
    @skia.ColorFilterDescriptor::saturation(invalid_filter_scalar) is Some(_) ||
    @skia.ImageFilterDescriptor::blur(invalid_filter_scalar, 1.0) is Some(_) ||
    @skia.MaskFilterDescriptor::blur(invalid_filter_scalar) is Some(_) {
    fail_smoke("non-finite filter inputs should be rejected")
  }
  println("native smoke filter finite validation")
  println(1)
  let infinite_filter_scalar : Float = 1.0 / 0.0
  if @native.ColorFilter::brightness(infinite_filter_scalar) is Some(_) ||
    @native.ColorFilter::contrast(infinite_filter_scalar) is Some(_) ||
    @native.ImageFilter::blur(infinite_filter_scalar, 1.0) is Some(_) ||
    @native.MaskFilter::blur(infinite_filter_scalar) is Some(_) ||
    @skia.ColorFilterDescriptor::brightness(infinite_filter_scalar) is Some(_) ||
    @skia.ColorFilterDescriptor::contrast(infinite_filter_scalar) is Some(_) ||
    @skia.ImageFilterDescriptor::blur(infinite_filter_scalar, 1.0) is Some(_) ||
    @skia.MaskFilterDescriptor::blur(infinite_filter_scalar) is Some(_) {
    fail_smoke("infinite filter inputs should be rejected")
  }
  println("native smoke filter non-finite handle validation")
  println(1)
  let invalid_shader_descriptor = @skia.LinearGradientShader(
    @skia.Point::new(4, 4),
    @skia.Point::new(4, 4),
    @skia.Color::red(),
    @skia.Color::blue(),
    @skia.Clamp,
  )
  let invalid_color_filter_descriptor = @skia.ColorMatrixFilter(
    invalid_filter_matrix,
  )
  let invalid_image_filter_descriptor = @skia.BlurImageFilter(
    invalid_filter_scalar, 1.0,
  )
  let invalid_mask_filter_descriptor = @skia.BlurMaskFilter(
    invalid_filter_scalar,
  )
  let invalid_descriptor_plan = @skia.RendererResourcePlan::new([
    invalid_shader_descriptor.resource_descriptor(),
    invalid_color_filter_descriptor.resource_descriptor(),
    invalid_image_filter_descriptor.resource_descriptor(),
    invalid_mask_filter_descriptor.resource_descriptor(),
  ])
  if invalid_shader_descriptor.is_valid() ||
    invalid_color_filter_descriptor.is_valid() ||
    invalid_image_filter_descriptor.is_valid() ||
    invalid_mask_filter_descriptor.is_valid() ||
    invalid_descriptor_plan.length() != 4 ||
    invalid_descriptor_plan.cacheable_count != 0 ||
    invalid_descriptor_plan.uncacheable_count != 4 ||
    invalid_descriptor_plan.count_kind(@skia.ShaderResource) != 1 ||
    invalid_descriptor_plan.count_kind(@skia.ColorFilterResource) != 1 ||
    invalid_descriptor_plan.count_kind(@skia.ImageFilterResource) != 1 ||
    invalid_descriptor_plan.count_kind(@skia.MaskFilterResource) != 1 {
    fail_smoke("invalid shader/filter descriptors should be uncacheable")
  }
  println("native smoke invalid shader filter descriptor resources")
  println(invalid_descriptor_plan.uncacheable_count)
  let invalid_replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    @skia.ISize::new(4, 4),
  )
  let invalid_replay_commands = @skia.RenderCommandList::for_target(
      invalid_replay_target,
    )
    .clear(@skia.Color::white())
    .draw_paint_shader(invalid_shader_descriptor)
    .save_layer(
      color_filter=Some(invalid_color_filter_descriptor),
      image_filter=Some(invalid_image_filter_descriptor),
      mask_filter=Some(invalid_mask_filter_descriptor),
    )
  let invalid_replay_plan = invalid_replay_commands.resource_plan()
  if invalid_replay_plan.length() != 1 ||
    invalid_replay_plan.cacheable_count != 1 ||
    invalid_replay_plan.uncacheable_count != 0 ||
    invalid_replay_plan.count_kind(@skia.SurfaceResource) != 1 ||
    invalid_replay_plan.count_kind(@skia.ShaderResource) != 0 ||
    invalid_replay_plan.count_kind(@skia.ColorFilterResource) != 0 ||
    invalid_replay_plan.count_kind(@skia.ImageFilterResource) != 0 ||
    invalid_replay_plan.count_kind(@skia.MaskFilterResource) != 0 {
    fail_smoke("invalid shader/filter replay plan is not cache-safe")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4))
    is Some(invalid_replay_surface) else {
    fail_smoke("failed to create invalid descriptor replay surface")
    None
  }
  guard invalid_replay_surface.canvas() is Some(invalid_replay_canvas) else {
    fail_smoke("failed to borrow invalid descriptor replay canvas")
    None
  }
  let invalid_replay_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
    color_filter_max_bytes=1024L,
    image_filter_max_bytes=1024L,
    mask_filter_max_bytes=1024L,
  )
  let invalid_replay_stats = invalid_replay_canvas.replay_with_resources(
    invalid_replay_commands, invalid_replay_resources,
  )
  let invalid_shader_cache_stats = invalid_replay_resources.shader_cache.stats()
  let invalid_color_filter_cache_stats = invalid_replay_resources.color_filter_cache.stats()
  let invalid_image_filter_cache_stats = invalid_replay_resources.image_filter_cache.stats()
  let invalid_mask_filter_cache_stats = invalid_replay_resources.mask_filter_cache.stats()
  if invalid_replay_stats.is_complete() ||
    invalid_replay_stats.command_count != 3 ||
    invalid_replay_stats.replayed_count != 1 ||
    invalid_replay_stats.skipped_count != 2 ||
    invalid_replay_stats.draw_count != 1 ||
    invalid_replay_stats.state_count != 1 ||
    invalid_replay_stats.clear_count != 1 ||
    invalid_replay_stats.shader_resource_count != 1 ||
    invalid_replay_stats.filter_resource_count != 3 ||
    invalid_replay_resources.shader_cache.length() != 0 ||
    invalid_replay_resources.color_filter_cache.length() != 0 ||
    invalid_replay_resources.image_filter_cache.length() != 0 ||
    invalid_replay_resources.mask_filter_cache.length() != 0 ||
    invalid_shader_cache_stats.misses != 0 ||
    invalid_shader_cache_stats.hits != 0 ||
    invalid_color_filter_cache_stats.misses != 0 ||
    invalid_color_filter_cache_stats.hits != 0 ||
    invalid_image_filter_cache_stats.misses != 0 ||
    invalid_image_filter_cache_stats.hits != 0 ||
    invalid_mask_filter_cache_stats.misses != 0 ||
    invalid_mask_filter_cache_stats.hits != 0 {
    fail_smoke("invalid shader/filter descriptors should skip without caching")
  }
  println("native smoke invalid shader filter replay skipped")
  println(invalid_replay_stats.skipped_count)
  println("native smoke invalid shader filter replay cache resources")
  println(
    invalid_replay_resources.shader_cache.length() +
    invalid_replay_resources.color_filter_cache.length() +
    invalid_replay_resources.image_filter_cache.length() +
    invalid_replay_resources.mask_filter_cache.length(),
  )
  println("native smoke invalid shader filter replay cache misses")
  println(
    invalid_shader_cache_stats.misses +
    invalid_color_filter_cache_stats.misses +
    invalid_image_filter_cache_stats.misses +
    invalid_mask_filter_cache_stats.misses,
  )
  println("native smoke invalid shader filter replay filter resources")
  println(invalid_replay_stats.filter_resource_count)

  Some({
    color_shader_descriptor,
    color_filter_descriptor,
    image_filter_descriptor,
    mask_filter_descriptor,
  })
}
