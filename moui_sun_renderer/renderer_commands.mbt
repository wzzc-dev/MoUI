///|
fn SunRasterRenderer::render_command(
  self : SunRasterRenderer,
  command : @core.DrawCommand,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  opacity_stack : Array[Double],
  blend_mode_stack : Array[@sun_graphics.BlendMode],
  layer_spec_stack : Array[SunLayerScope],
  rounded_clip_transform_stack : Array[@sun_graphics.Transform],
) -> Unit {
  let opacity = sun_current_opacity(opacity_stack)
  match command {
    Clear(color) => self.canvas.clear(sun_color(color))
    FillRect(rect, color) =>
      self.canvas.fill_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_paint(color, opacity),
      )
    StrokeRect(rect, color, width) =>
      self.canvas.stroke_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_stroke_paint(color, width, opacity),
      )
    FillRoundedRect(rounded, color) =>
      self.fill_rounded_rect(rounded, @core.Brush::solid(color), opacity)
    StrokeRoundedRect(rounded, color, width) =>
      self.stroke_rounded_rect(
        rounded,
        @core.Brush::solid(color),
        width,
        opacity,
      )
    FillRoundedRectBrush(rounded, brush) =>
      self.fill_rounded_rect(rounded, brush, opacity)
    StrokeRoundedRectBrush(rounded, brush, width) =>
      self.stroke_rounded_rect(rounded, brush, width, opacity)
    DrawShadow(shadow) => self.draw_shadow(shadow, opacity)
    DrawText(run) => self.draw_text(run, opacity)
    DrawImage(image) => self.draw_image(image, opacity)
    PushClip(rect) => {
      self.canvas.save()
      canvas_scopes.push(Clip)
      self.canvas.intersect_clip_rect(
        sun_transformed_rect_bounds(self.canvas.get_transform(), rect),
      )
    }
    PopClip => self.pop_canvas_scope(canvas_scopes, opacity_stack, Clip)
    PushPathClip(spec) => {
      self.canvas.save()
      canvas_scopes.push(Clip)
      // The software canvas only stores a rect clip; path clips degrade to
      // their bounds until the rasterizer grows a mask scope.
      match spec.shape_bounds() {
        Some(bounds) =>
          self.canvas.intersect_clip_rect(
            sun_transformed_rect_bounds(self.canvas.get_transform(), bounds),
          )
        None =>
          self.canvas.intersect_clip_rect(
            @sun_graphics.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
          )
      }
    }
    PopPathClip => self.pop_canvas_scope(canvas_scopes, opacity_stack, Clip)
    PushRoundedClip(rounded) => {
      self.rounded_clip_stack.push(rounded)
      rounded_clip_transform_stack.push(self.canvas.get_transform())
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(RoundedClip)
    }
    PopRoundedClip =>
      match canvas_scopes.pop() {
        Some(RoundedClip) => {
          let layer_pixmap = self.canvas.get_pixmap()
          match self.canvas_stack.pop() {
            Some(parent_canvas) =>
              match self.rounded_clip_stack.pop() {
                Some(rounded) => {
                  self.canvas = parent_canvas
                  let transform = match rounded_clip_transform_stack.pop() {
                    Some(value) => value
                    None => {
                      self.record_unsupported_command(
                        "PopRoundedClip", "PopRoundedClip has no matching rounded clip transform stack entry",
                      )
                      @sun_graphics.Transform::identity()
                    }
                  }
                  self.composite_rounded_clip(
                    layer_pixmap, rounded, transform, opacity,
                  )
                }
                None => {
                  self.canvas = parent_canvas
                  match rounded_clip_transform_stack.pop() {
                    Some(_) => ()
                    None => ()
                  }
                  self.record_unsupported_command(
                    "PopRoundedClip", "PopRoundedClip has no matching rounded clip stack entry",
                  )
                }
              }
            None =>
              self.record_unsupported_command(
                "PopRoundedClip", "PopRoundedClip has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          self.record_unsupported_command(
            "PopRoundedClip",
            "pop did not match active \{@render_common.plan_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopRoundedClip", "pop has no matching push scope",
          )
      }
    PushTransform(transform) => {
      self.canvas.save()
      canvas_scopes.push(Transform)
      self.canvas.concat_transform(sun_transform(transform))
    }
    PopTransform =>
      self.pop_canvas_scope(canvas_scopes, opacity_stack, Transform)
    PushOpacity(opacity) => {
      canvas_scopes.push(Opacity)
      opacity_stack.push(sun_clamp_unit(opacity))
    }
    PopOpacity => self.pop_canvas_scope(canvas_scopes, opacity_stack, Opacity)
    PushLayer(spec) => {
      blend_mode_stack.push(sun_blend_mode(spec.blend_mode))
      layer_spec_stack.push({ spec, transform: self.canvas.get_transform(), })
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(Layer)
    }
    PopLayer =>
      match canvas_scopes.pop() {
        Some(Layer) => {
          let layer_pixmap = self.canvas.get_pixmap()
          let layer_blend = match blend_mode_stack.pop() {
            Some(m) => m
            None => SourceOver
          }
          let layer_scope = match layer_spec_stack.pop() {
            Some(scope) => scope
            None => {
              self.record_unsupported_command(
                "PopLayer", "PopLayer has no matching layer spec stack entry",
              )
              {
                spec: @core.LayerSpec::new(),
                transform: @sun_graphics.Transform::identity(),
              }
            }
          }
          match self.canvas_stack.pop() {
            Some(parent_canvas) => {
              self.canvas = parent_canvas
              self.composite_layer_pixmap(
                layer_pixmap, layer_scope, opacity, layer_blend,
              )
            }
            None =>
              self.record_unsupported_command(
                "PopLayer", "PopLayer has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          self.record_unsupported_command(
            "PopLayer",
            "pop did not match active \{@render_common.plan_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopLayer", "pop has no matching push scope",
          )
      }
    PushFilter(effect) => {
      self.filter_stack.push(sun_filter_effect(effect))
      match effect {
        Blur(radius) => self.blur_radius_stack.push(radius.max(0.0))
        _ => self.blur_radius_stack.push(0.0)
      }
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(Filter)
    }
    PopFilter => {
      let filter = self.filter_stack.pop()
      let blur_radius_entry = self.blur_radius_stack.pop()
      let blur_radius = blur_radius_entry.unwrap_or(0.0)
      match canvas_scopes.pop() {
        Some(Filter) => {
          let layer_pixmap = self.canvas.get_pixmap()
          // Blur radii are logical; the layer pixmap is device-resolution, so
          // scale the kernel by DPR to keep the perceived softness.
          let effective_pixmap = if blur_radius > 0.0 {
            sun_box_blur_pixmap(
              layer_pixmap,
              blur_radius * self.metrics.scale_factor,
            )
          } else {
            layer_pixmap
          }
          match self.canvas_stack.pop() {
            Some(parent_canvas) => {
              self.canvas = parent_canvas
              // Apply color filter at the pixmap level instead of
              // per-pixel fill_rect calls to avoid w*h Paint allocations
              // and per-pixel clip/transform overhead.
              // Skip the pixmap copy when the filter is identity (common
              // for blur-only PushFilter scopes).
              let composited = match filter {
                Some(paint_filter) =>
                  if paint_filter.is_identity() {
                    effective_pixmap
                  } else {
                    sun_filter_pixmap(effective_pixmap, paint_filter)
                  }
                None => effective_pixmap
              }
              self.canvas.draw_pixmap(
                composited,
                0,
                0,
                @sun_graphics.Paint::new().set_opacity(opacity),
              )
            }
            None =>
              self.record_unsupported_command(
                "PopFilter", "PopFilter has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          match filter {
            Some(f) => self.filter_stack.push(f)
            None => ()
          }
          match blur_radius_entry {
            Some(radius) => self.blur_radius_stack.push(radius)
            None => ()
          }
          self.record_unsupported_command(
            "PopFilter",
            "pop did not match active \{@render_common.plan_scope_name(other)} scope",
          )
        }
        None => {
          match filter {
            Some(f) => self.filter_stack.push(f)
            None => ()
          }
          match blur_radius_entry {
            Some(radius) => self.blur_radius_stack.push(radius)
            None => ()
          }
          self.record_unsupported_command(
            "PopFilter", "pop has no matching push scope",
          )
        }
      }
    }
    DrawPath(path) => self.draw_path(path, opacity)
    DrawShaderEffect(spec) => self.draw_shader_effect(spec, opacity)
    BeginRetainedLayer(_) =>
      self.record_unsupported_command(
        "BeginRetainedLayer", "cached layer scope not intercepted by render_cached_command_range",
      )
    EndRetainedLayer(_) =>
      self.record_unsupported_command(
        "EndRetainedLayer", "cached layer scope intercepted by render_cached_command_range",
      )
  }
}

///|
fn SunRasterRenderer::fill_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  let start = if sun_profile_enabled() {
    Some(@bench.monotonic_clock_start())
  } else {
    None
  }
  self.canvas.fill_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_paint(brush, opacity),
  )
  match start {
    Some(s) => {
      let bucket = if brush is @core.Brush::Solid(_) { 32 } else { 33 }
      sun_profile_add(bucket, @bench.monotonic_clock_end(s))
    }
    None => ()
  }
}

///|
fn SunRasterRenderer::stroke_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  self.canvas.stroke_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_stroke_paint(brush, width, opacity),
  )
}

///|
fn SunRasterRenderer::draw_path(
  self : SunRasterRenderer,
  path : @core.PathSpec,
  opacity : Double,
) -> Unit {
  let sun_path = sun_path(path)
  match path.fill {
    Some(brush) =>
      self.canvas.fill_path(sun_path, sun_brush_paint(brush, opacity))
    None => ()
  }
  match path.stroke {
    Some(brush) =>
      self.canvas.stroke_path(
        sun_path,
        sun_brush_stroke_paint(
          brush,
          path.stroke_width,
          opacity,
          cap=path.stroke_cap,
          join=path.stroke_join,
        ),
      )
    None => ()
  }
}

///|
fn SunRasterRenderer::pop_canvas_scope(
  self : SunRasterRenderer,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  opacity_stack : Array[Double],
  expected : @render_common.PlanScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        match actual {
          Opacity => ignore(opacity_stack.pop())
          _ => ignore(self.canvas.restore())
        }
      } else {
        canvas_scopes.push(actual)
        self.record_unsupported_command(
          @render_common.plan_scope_pop_command(expected),
          "pop did not match active \{@render_common.plan_scope_name(actual)} scope",
        )
      }
    None =>
      self.record_unsupported_command(
        @render_common.plan_scope_pop_command(expected),
        "pop has no matching push scope",
      )
  }
}

///|
fn SunRasterRenderer::record_unsupported_command(
  self : SunRasterRenderer,
  command : String,
  reason : String,
) -> Unit {
  self.unsupported_command_count = self.unsupported_command_count + 1
  self.unsupported_command_diagnostics.push({ command, reason, })
}

///|
fn sun_dim_to_int(value : Double) -> Int32 {
  value.ceil().max(1.0).to_int()
}

///|
fn sun_color(color : @core.Color) -> @sun_graphics.Color {
  @sun_graphics.Color::new(
    r=sun_channel(color.r),
    g=sun_channel(color.g),
    b=sun_channel(color.b),
    a=sun_channel(color.a),
  )
}

///|
fn sun_channel(value : Double) -> Byte {
  (sun_clamp_unit(value) * 255.0 + 0.5).to_int().max(0).min(255).to_byte()
}

///|
fn sun_clamp_unit(value : Double) -> Double {
  guard value == value else { return 0.0 }
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn sun_current_opacity(opacity_stack : Array[Double]) -> Double {
  let mut opacity = 1.0
  for item in opacity_stack {
    opacity = opacity * item
  }
  opacity
}

///|
fn sun_paint(color : @core.Color, opacity : Double) -> @sun_graphics.Paint {
  @sun_graphics.Paint::new().set_color(sun_color(color)).set_opacity(opacity)
}

///|
fn sun_stroke_paint(
  color : @core.Color,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_paint(color, opacity).set_style(Stroke).set_stroke_width(width)
}

///|
fn sun_brush_paint(
  brush : @core.Brush,
  opacity : Double,
) -> @sun_graphics.Paint {
  let paint = @sun_graphics.Paint::new().set_opacity(opacity)
  match brush {
    Solid(color) => paint.set_color(sun_color(color))
    LinearGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.start_color))
      .set_shader(
        @sun_graphics.PaintShader::linear_gradient(
          x0=gradient.start.x,
          y0=gradient.start.y,
          x1=gradient.end.x,
          y1=gradient.end.y,
          start_color=sun_color(gradient.start_color),
          end_color=sun_color(gradient.end_color),
        ),
      )
    RadialGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.center_color))
      .set_shader(
        @sun_graphics.PaintShader::radial_gradient(
          cx=gradient.center.x,
          cy=gradient.center.y,
          radius=gradient.radius,
          start_color=sun_color(gradient.center_color),
          end_color=sun_color(gradient.edge_color),
        ),
      )
    StopsGradient(spec) => {
      let stops = spec
        .srgb_stops()
        .map(stop => {
          @sun_graphics.PaintGradientStop::new(
            offset=stop.at,
            color=sun_color(stop.color),
          )
        })
      let (first, _) = spec.edge_colors()
      let base = paint.set_color(sun_color(first))
      match spec.axis {
        @core.LinearAxis(start, end) =>
          base.set_shader(
            @sun_graphics.PaintShader::linear_gradient_stops(
              x0=start.x,
              y0=start.y,
              x1=end.x,
              y1=end.y,
              stops~,
            ),
          )
        @core.RadialAxis(center, radius) =>
          base.set_shader(
            @sun_graphics.PaintShader::radial_gradient_stops(
              cx=center.x,
              cy=center.y,
              radius~,
              stops~,
            ),
          )
        @core.ConicAxis(center, angle_degrees) => {
          let start_angle = angle_degrees * @math.PI / 180.0 - @math.PI / 2.0
          base.set_shader(
            @sun_graphics.PaintShader::sweep_gradient_stops(
              cx=center.x,
              cy=center.y,
              start_angle~,
              sweep_angle=2.0 * @math.PI,
              stops~,
            ),
          )
        }
      }
    }
  }
}

///|
fn sun_stroke_cap(cap : @core.StrokeCap) -> @sun_graphics.StrokeCap {
  match cap {
    @core.Butt => @sun_graphics.Butt
    @core.Round => @sun_graphics.Round
    @core.Square => @sun_graphics.Square
  }
}

///|
fn sun_stroke_join(join : @core.StrokeJoin) -> @sun_graphics.StrokeJoin {
  match join {
    @core.Miter => @sun_graphics.Miter
    @core.Round => @sun_graphics.Round
    @core.Bevel => @sun_graphics.Bevel
  }
}

///|
fn sun_brush_stroke_paint(
  brush : @core.Brush,
  width : Double,
  opacity : Double,
  cap~ : @core.StrokeCap? = None,
  join~ : @core.StrokeJoin? = None,
) -> @sun_graphics.Paint {
  let paint = sun_brush_paint(brush, opacity)
    .set_style(Stroke)
    .set_stroke_width(width)
    .set_stroke_cap(
      match cap {
        Some(cap) => sun_stroke_cap(cap)
        None => Round
      },
    )
    .set_stroke_join(
      match join {
        Some(join) => sun_stroke_join(join)
        None => Round
      },
    )
  paint
}

///|
fn sun_transform(transform : @core.Transform2D) -> @sun_graphics.Transform {
  @sun_graphics.Transform::affine(
    a=transform.a,
    b=transform.b,
    c=transform.c,
    d=transform.d,
    tx=transform.tx,
    ty=transform.ty,
  )
}

///|
fn sun_path(path : @core.PathSpec) -> @sun_graphics.Path {
  let out = @sun_graphics.Path::new()
  for verb in path.verbs {
    match verb {
      MoveTo(point) => ignore(out.move_to(point.x, point.y))
      LineTo(point) => ignore(out.line_to(point.x, point.y))
      QuadTo(control, point) =>
        ignore(out.quad_to(control.x, control.y, point.x, point.y))
      CubicTo(control1, control2, point) =>
        ignore(
          out.cubic_to(
            control1.x,
            control1.y,
            control2.x,
            control2.y,
            point.x,
            point.y,
          ),
        )
      Close => ignore(out.close())
    }
  }
  out
}

///|
fn SunRasterRenderer::draw_shader_effect(
  self : SunRasterRenderer,
  spec : @core.ShaderEffectSpec,
  opacity : Double,
) -> Unit {
  let frame = spec.frame
  match spec.name {
    "solid" => self.fill_shader_effect_frame(frame, spec.fallback, opacity)
    "checker" =>
      self.draw_checker_effect(frame, spec.fallback, spec.uniforms, opacity)
    "linear-gradient-debug" =>
      self.canvas.fill_rect(
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        sun_linear_gradient_debug_paint(frame, spec.fallback, opacity),
      )
    "vignette" =>
      self.draw_vignette_effect(frame, spec.fallback, spec.uniforms, opacity)
    "backdrop-blur" => self.draw_backdrop_blur_effect(frame, spec, opacity)
    _ => {
      let fallback_paint = sun_brush_paint(spec.fallback, opacity)
      self.canvas.fill_rect(
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        fallback_paint,
      )
      self.record_unsupported_command(
        "DrawShaderEffect",
        "unknown shader effect '\{spec.name}' used fallback brush",
      )
    }
  }
}

///|
fn sun_filter_effect(effect : @core.FilterEffect) -> @sun_graphics.PaintFilter {
  match effect {
    Blur(_) => @sun_graphics.PaintFilter::identity()
    Saturate(factor) => @sun_graphics.PaintFilter::saturate(factor)
    Brightness(factor) => @sun_graphics.PaintFilter::brightness(factor)
    Contrast(factor) => @sun_graphics.PaintFilter::contrast(factor)
    ColorMatrix(values) => @sun_graphics.PaintFilter::color_matrix(values)
  }
}

///|
fn sun_box_blur_pixmap(
  src : @sun_graphics.Pixmap,
  radius : Double,
) -> @sun_graphics.Pixmap {
  let r = radius.max(0.0).to_int()
  guard r > 0 else { return src }
  let w = src.get_width()
  let h = src.get_height()
  guard w > 0 && h > 0 else { return src }
  // Three-pass box blur approximates a Gaussian kernel, producing much smoother
  // falloff than a single pass while keeping the same effective blur spread.
  // All six directional passes run over the raw interleaved byte buffer with
  // integer sliding windows and a sum → channel lookup table, and the two
  // scratch pixmaps are allocated once for the whole chain. The earlier form
  // allocated two pixmaps per pass and moved every pixel through `Color`
  // get/set with double sums, which made a single popup shadow cost ~200 ms
  // in a debug build.
  let k = 2 * r + 1
  let lut = sun_blur_lut(k, r)
  let scratch_a = @sun_graphics.Pixmap::new(w, h)
  let scratch_b = @sun_graphics.Pixmap::new(w, h)
  let a = scratch_a.get_pixels()
  let b = scratch_b.get_pixels()
  let mut source = src.get_pixels()
  for _pass in 0..<3 {
    sun_box_blur_horizontal(source, a, w, h, r, lut)
    sun_box_blur_vertical(a, b, w, h, r, lut)
    source = b
  }
  scratch_b
}

///|
/// Window sum → rounded channel byte, clamped to `0 .. 255`.
///
/// The old per-pixel path computed `floor(sum / k + 0.5)` in doubles. For a
/// non-negative integer sum and odd `k = 2r + 1`, `floor(sum / k + 0.5)` equals
/// the integer division `(sum + r) / k`, so the table is bit-exact for every
/// reachable sum (`0 .. 255 * k`).
fn sun_blur_lut(k : Int32, half : Int32) -> FixedArray[Byte] {
  let size = 255 * k + 1
  let lut : FixedArray[Byte] = FixedArray::make(size, 0)
  for sum in 0..<size {
    lut[sum] = ((sum + half) / k).to_byte()
  }
  lut
}

///|
/// Horizontal box-blur pass: per row, a sliding window over raw RGBA bytes.
fn sun_box_blur_horizontal(
  src : FixedArray[Byte],
  dst : FixedArray[Byte],
  w : Int32,
  h : Int32,
  r : Int32,
  lut : FixedArray[Byte],
) -> Unit {
  let last_x = w - 1
  for y in 0..<h {
    let row = y * w * 4
    let mut sum_r = 0
    let mut sum_g = 0
    let mut sum_b = 0
    let mut sum_a = 0
    for dx in (0 - r)..<(r + 1) {
      let offset = row + dx.max(0).min(last_x) * 4
      sum_r = sum_r + src[offset].to_int()
      sum_g = sum_g + src[offset + 1].to_int()
      sum_b = sum_b + src[offset + 2].to_int()
      sum_a = sum_a + src[offset + 3].to_int()
    }
    let mut out = row
    dst[out] = lut[sum_r]
    dst[out + 1] = lut[sum_g]
    dst[out + 2] = lut[sum_b]
    dst[out + 3] = lut[sum_a]
    for x in 1..<w {
      let leave = row + (x - 1 - r).max(0) * 4
      let enter = row + (x + r).min(last_x) * 4
      sum_r = sum_r + src[enter].to_int() - src[leave].to_int()
      sum_g = sum_g + src[enter + 1].to_int() - src[leave + 1].to_int()
      sum_b = sum_b + src[enter + 2].to_int() - src[leave + 2].to_int()
      sum_a = sum_a + src[enter + 3].to_int() - src[leave + 3].to_int()
      out = row + x * 4
      dst[out] = lut[sum_r]
      dst[out + 1] = lut[sum_g]
      dst[out + 2] = lut[sum_b]
      dst[out + 3] = lut[sum_a]
    }
  }
}

///|
/// Vertical box-blur pass: per column, a sliding window over raw RGBA bytes.
fn sun_box_blur_vertical(
  src : FixedArray[Byte],
  dst : FixedArray[Byte],
  w : Int32,
  h : Int32,
  r : Int32,
  lut : FixedArray[Byte],
) -> Unit {
  let last_y = h - 1
  let stride = w * 4
  for x in 0..<w {
    let column = x * 4
    let mut sum_r = 0
    let mut sum_g = 0
    let mut sum_b = 0
    let mut sum_a = 0
    for dy in (0 - r)..<(r + 1) {
      let offset = dy.max(0).min(last_y) * stride + column
      sum_r = sum_r + src[offset].to_int()
      sum_g = sum_g + src[offset + 1].to_int()
      sum_b = sum_b + src[offset + 2].to_int()
      sum_a = sum_a + src[offset + 3].to_int()
    }
    let mut out = column
    dst[out] = lut[sum_r]
    dst[out + 1] = lut[sum_g]
    dst[out + 2] = lut[sum_b]
    dst[out + 3] = lut[sum_a]
    for y in 1..<h {
      let leave = (y - 1 - r).max(0) * stride + column
      let enter = (y + r).min(last_y) * stride + column
      sum_r = sum_r + src[enter].to_int() - src[leave].to_int()
      sum_g = sum_g + src[enter + 1].to_int() - src[leave + 1].to_int()
      sum_b = sum_b + src[enter + 2].to_int() - src[leave + 2].to_int()
      sum_a = sum_a + src[enter + 3].to_int() - src[leave + 3].to_int()
      out = y * stride + column
      dst[out] = lut[sum_r]
      dst[out + 1] = lut[sum_g]
      dst[out + 2] = lut[sum_b]
      dst[out + 3] = lut[sum_a]
    }
  }
}

///|
fn sun_filter_pixmap(
  src : @sun_graphics.Pixmap,
  filter : @sun_graphics.PaintFilter,
) -> @sun_graphics.Pixmap {
  let w = src.get_width()
  let h = src.get_height()
  let dst = @sun_graphics.Pixmap::new(w, h)
  let pixels = src.get_pixels()
  for y in 0..<h {
    for x in 0..<w {
      let offset = (y * w + x) * 4
      let src_color = @sun_graphics.Color::new(
        r=pixels[offset],
        g=pixels[offset + 1],
        b=pixels[offset + 2],
        a=pixels[offset + 3],
      )
      dst.set_pixel(x, y, filter.apply(src_color))
    }
  }
  dst
}

///|
fn sun_blend_mode(mode : @core.BlendMode) -> @sun_graphics.BlendMode {
  match mode {
    SourceOver => SourceOver
    Multiply => Multiply
    Screen => Screen
    Overlay => Overlay
    Darken => Darken
    Lighten => Lighten
    Add => Add
    Difference => Difference
    Exclusion => Exclusion
    HardLight => HardLight
    SoftLight => SoftLight
    ColorDodge => ColorDodge
    ColorBurn => ColorBurn
    Source => Source
  }
}
