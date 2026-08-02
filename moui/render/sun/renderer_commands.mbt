///|
fn SunRasterRenderer::render_command(
  self : SunRasterRenderer,
  command : @render.PlanOp,
  canvas_scopes : Array[@render.PlanScopeKind],
  opacity_stack : Array[Double],
  blend_mode_stack : Array[@sun_graphics.BlendMode],
  layer_spec_stack : Array[SunLayerScope],
  rounded_clip_transform_stack : Array[@sun_graphics.Transform],
) -> Unit {
  let opacity = sun_current_opacity(opacity_stack)
  match command {
    @render.PlanOp::Clear(color) => self.canvas.clear(sun_color(color))
    @render.PlanOp::FillRect(rect, color) =>
      self.canvas.fill_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_paint(color, opacity),
      )
    @render.PlanOp::StrokeRect(rect, color, width) =>
      self.canvas.stroke_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_stroke_paint(color, width, opacity),
      )
    @render.PlanOp::FillRoundedRect(rounded, color) =>
      self.fill_rounded_rect(rounded, @core.Brush::solid(color), opacity)
    @render.PlanOp::StrokeRoundedRect(rounded, color, width) =>
      self.stroke_rounded_rect(
        rounded,
        @core.Brush::solid(color),
        width,
        opacity,
      )
    @render.PlanOp::FillRoundedRectBrush(rounded, brush) =>
      self.fill_rounded_rect(rounded, brush, opacity)
    @render.PlanOp::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.stroke_rounded_rect(rounded, brush, width, opacity)
    @render.PlanOp::DrawShadow(shadow) => self.draw_shadow(shadow, opacity)
    @render.PlanOp::DrawText(run) => self.draw_text(run, opacity)
    @render.PlanOp::DrawImage(image) => self.draw_image(image, opacity)
    @render.PlanOp::PushClip(rect) => {
      self.canvas.save()
      canvas_scopes.push(@render.PlanScopeKind::Clip)
      self.canvas.intersect_clip_rect(
        sun_transformed_rect_bounds(self.canvas.get_transform(), rect),
      )
    }
    @render.PlanOp::PopClip =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        @render.PlanScopeKind::Clip,
      )
    @render.PlanOp::PushRoundedClip(rounded) => {
      self.rounded_clip_stack.push(rounded)
      rounded_clip_transform_stack.push(self.canvas.get_transform())
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(@render.PlanScopeKind::RoundedClip)
    }
    @render.PlanOp::PopRoundedClip =>
      match canvas_scopes.pop() {
        Some(@render.PlanScopeKind::RoundedClip) => {
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
            "pop did not match active \{@render.plan_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopRoundedClip", "pop has no matching push scope",
          )
      }
    @render.PlanOp::PushTransform(transform) => {
      self.canvas.save()
      canvas_scopes.push(@render.PlanScopeKind::Transform)
      self.canvas.concat_transform(sun_transform(transform))
    }
    @render.PlanOp::PopTransform =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        @render.PlanScopeKind::Transform,
      )
    @render.PlanOp::PushOpacity(opacity) => {
      canvas_scopes.push(@render.PlanScopeKind::Opacity)
      opacity_stack.push(sun_clamp_unit(opacity))
    }
    @render.PlanOp::PopOpacity =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        @render.PlanScopeKind::Opacity,
      )
    @render.PlanOp::PushLayer(spec) => {
      blend_mode_stack.push(sun_blend_mode(spec.blend_mode))
      layer_spec_stack.push({ spec, transform: self.canvas.get_transform() })
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(@render.PlanScopeKind::Layer)
    }
    @render.PlanOp::PopLayer =>
      match canvas_scopes.pop() {
        Some(@render.PlanScopeKind::Layer) => {
          let layer_pixmap = self.canvas.get_pixmap()
          let layer_blend = match blend_mode_stack.pop() {
            Some(m) => m
            None => @sun_graphics.BlendMode::SourceOver
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
            "pop did not match active \{@render.plan_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopLayer", "pop has no matching push scope",
          )
      }
    @render.PlanOp::PushFilter(effect) => {
      self.filter_stack.push(sun_filter_effect(effect))
      match effect {
        @core.FilterEffect::Blur(radius) =>
          self.blur_radius_stack.push(radius.max(0.0))
        _ => self.blur_radius_stack.push(0.0)
      }
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(@render.PlanScopeKind::Filter)
    }
    @render.PlanOp::PopFilter => {
      let filter = self.filter_stack.pop()
      let blur_radius_entry = self.blur_radius_stack.pop()
      let blur_radius = blur_radius_entry.unwrap_or(0.0)
      match canvas_scopes.pop() {
        Some(@render.PlanScopeKind::Filter) => {
          let layer_pixmap = self.canvas.get_pixmap()
          let effective_pixmap = if blur_radius > 0.0 {
            sun_box_blur_pixmap(layer_pixmap, blur_radius)
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
            "pop did not match active \{@render.plan_scope_name(other)} scope",
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
    @render.PlanOp::DrawPath(path) => self.draw_path(path, opacity)
    @render.PlanOp::DrawShaderEffect(spec) =>
      self.draw_shader_effect(spec, opacity)
    @render.PlanOp::BeginCachedLayer(_) =>
      self.record_unsupported_command(
        "BeginCachedLayer", "cached layer scope not intercepted by render_cached_command_range",
      )
    @render.PlanOp::EndCachedLayer(_) =>
      self.record_unsupported_command(
        "EndCachedLayer", "cached layer scope intercepted by render_cached_command_range",
      )
    @render.PlanOp::DrawCachedLayer(_) =>
      self.record_unsupported_command(
        "DrawCachedLayer", "cached layer draw not intercepted by render_cached_command_range",
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
  self.canvas.fill_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_paint(brush, opacity),
  )
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
        sun_brush_stroke_paint(brush, path.stroke_width, opacity),
      )
    None => ()
  }
}

///|
fn SunRasterRenderer::pop_canvas_scope(
  self : SunRasterRenderer,
  canvas_scopes : Array[@render.PlanScopeKind],
  opacity_stack : Array[Double],
  expected : @render.PlanScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        match actual {
          @render.PlanScopeKind::Opacity => ignore(opacity_stack.pop())
          _ => ignore(self.canvas.restore())
        }
      } else {
        canvas_scopes.push(actual)
        self.record_unsupported_command(
          @render.plan_scope_pop_command(expected),
          "pop did not match active \{@render.plan_scope_name(actual)} scope",
        )
      }
    None =>
      self.record_unsupported_command(
        @render.plan_scope_pop_command(expected),
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
  self.unsupported_command_diagnostics.push({ command, reason })
}

///|
fn sun_dim_to_int(value : Double) -> Int {
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
  sun_paint(color, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
}

///|
fn sun_brush_paint(
  brush : @core.Brush,
  opacity : Double,
) -> @sun_graphics.Paint {
  let paint = @sun_graphics.Paint::new().set_opacity(opacity)
  match brush {
    @core.Brush::Solid(color) => paint.set_color(sun_color(color))
    @core.Brush::LinearGradient(gradient) =>
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
    @core.Brush::RadialGradient(gradient) =>
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
  }
}

///|
fn sun_brush_stroke_paint(
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_brush_paint(brush, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
  .set_stroke_cap(@sun_graphics.StrokeCap::Round)
  .set_stroke_join(@sun_graphics.StrokeJoin::Round)
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
      @core.PathVerb::MoveTo(point) => ignore(out.move_to(point.x, point.y))
      @core.PathVerb::LineTo(point) => ignore(out.line_to(point.x, point.y))
      @core.PathVerb::QuadTo(control, point) =>
        ignore(out.quad_to(control.x, control.y, point.x, point.y))
      @core.PathVerb::CubicTo(control1, control2, point) =>
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
      @core.PathVerb::Close => ignore(out.close())
    }
  }
  out
}

///|
fn SunRasterRenderer::draw_shadow(
  self : SunRasterRenderer,
  shadow : @core.ShadowSpec,
  opacity : Double,
) -> Unit {
  let rect = shadow.rect.rect
  let corner_radius = shadow.rect.radius.max(0.0)
  let base_color = shadow.color
  let spread = shadow.spread.max(0.0)
  let blur_r = shadow.blur_radius.max(0.0)
  guard opacity > 0.0 else { return }
  guard base_color.a > 0.0 else { return }
  let pad = (blur_r * 2.0).ceil().to_int().max(1)
  let inner_w = rect.size.width + spread * 2.0
  let inner_h = rect.size.height + spread * 2.0
  let shadow_w = inner_w.ceil().to_int().max(1) + pad * 2
  let shadow_h = inner_h.ceil().to_int().max(1) + pad * 2
  let shadow_pixmap = @sun_graphics.Pixmap::new(shadow_w, shadow_h)
  let shadow_color = @sun_graphics.Color::new(
    r=sun_channel(base_color.r),
    g=sun_channel(base_color.g),
    b=sun_channel(base_color.b),
    a=sun_channel(sun_clamp_unit(base_color.a * opacity)),
  )
  let cx = pad.to_double() + inner_w * 0.5
  let cy = pad.to_double() + inner_h * 0.5
  let hx = inner_w * 0.5
  let hy = inner_h * 0.5
  let scaled_radius = corner_radius.min(hx).min(hy)
  for sy in 0..<shadow_h {
    for sx in 0..<shadow_w {
      let px = sx.to_double() + 0.5
      let py = sy.to_double() + 0.5
      let qx = (px - cx).abs() - (hx - scaled_radius)
      let qy = (py - cy).abs() - (hy - scaled_radius)
      let outside_dist = if qx > 0.0 && qy > 0.0 {
        (qx * qx + qy * qy).sqrt()
      } else if qx > 0.0 {
        qx
      } else if qy > 0.0 {
        qy
      } else {
        0.0
      }
      let d = outside_dist - scaled_radius
      if d < 0.5 {
        shadow_pixmap.set_pixel(sx, sy, shadow_color)
      }
    }
  }
  let blurred = if blur_r > 0.5 {
    sun_box_blur_pixmap(shadow_pixmap, blur_r)
  } else {
    shadow_pixmap
  }
  let draw_x = rect.origin.x + shadow.offset.x - spread - pad.to_double()
  let draw_y = rect.origin.y + shadow.offset.y - spread - pad.to_double()
  self.canvas.draw_pixmap(
    blurred,
    draw_x.to_int(),
    draw_y.to_int(),
    @sun_graphics.Paint::new().set_opacity(1.0),
  )
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
    @core.FilterEffect::Blur(_) => @sun_graphics.PaintFilter::identity()
    @core.FilterEffect::Saturate(factor) =>
      @sun_graphics.PaintFilter::saturate(factor)
    @core.FilterEffect::Brightness(factor) =>
      @sun_graphics.PaintFilter::brightness(factor)
    @core.FilterEffect::Contrast(factor) =>
      @sun_graphics.PaintFilter::contrast(factor)
    @core.FilterEffect::ColorMatrix(values) =>
      @sun_graphics.PaintFilter::color_matrix(values)
  }
}

///|
fn sun_box_blur_pixmap(
  src : @sun_graphics.Pixmap,
  radius : Double,
) -> @sun_graphics.Pixmap {
  let r = radius.max(0.0).to_int()
  guard r > 0 else { return src }
  // Three-pass box blur approximates a Gaussian kernel, producing
  // much smoother falloff than a single pass while keeping the same
  // effective blur spread (each pass uses the full integer radius).
  let pass1 = sun_single_box_blur(src, r)
  let pass2 = sun_single_box_blur(pass1, r)
  sun_single_box_blur(pass2, r)
}

///|
fn sun_single_box_blur(
  src : @sun_graphics.Pixmap,
  r : Int,
) -> @sun_graphics.Pixmap {
  let w = src.get_width()
  let h = src.get_height()
  guard w > 0 && h > 0 else { return src }
  let k = 2 * r + 1
  let temp = @sun_graphics.Pixmap::new(w, h)
  // Horizontal pass with sliding window
  for y in 0..<h {
    let mut sum_r = 0.0
    let mut sum_g = 0.0
    let mut sum_b = 0.0
    let mut sum_a = 0.0
    for dx in (0 - r)..<(r + 1) {
      let c = src.get_pixel(dx.max(0).min(w - 1), y)
      sum_r = sum_r + c.r.to_int().to_double()
      sum_g = sum_g + c.g.to_int().to_double()
      sum_b = sum_b + c.b.to_int().to_double()
      sum_a = sum_a + c.a.to_int().to_double()
    }
    temp.set_pixel(
      0,
      y,
      @sun_graphics.Color::new(
        r=sun_blur_channel(sum_r, k),
        g=sun_blur_channel(sum_g, k),
        b=sun_blur_channel(sum_b, k),
        a=sun_blur_channel(sum_a, k),
      ),
    )
    for x in 1..<w {
      let leave = src.get_pixel((x - 1 - r).max(0), y)
      let enter = src.get_pixel((x + r).min(w - 1), y)
      sum_r = sum_r +
        enter.r.to_int().to_double() -
        leave.r.to_int().to_double()
      sum_g = sum_g +
        enter.g.to_int().to_double() -
        leave.g.to_int().to_double()
      sum_b = sum_b +
        enter.b.to_int().to_double() -
        leave.b.to_int().to_double()
      sum_a = sum_a +
        enter.a.to_int().to_double() -
        leave.a.to_int().to_double()
      temp.set_pixel(
        x,
        y,
        @sun_graphics.Color::new(
          r=sun_blur_channel(sum_r, k),
          g=sun_blur_channel(sum_g, k),
          b=sun_blur_channel(sum_b, k),
          a=sun_blur_channel(sum_a, k),
        ),
      )
    }
  }
  let dst = @sun_graphics.Pixmap::new(w, h)
  // Vertical pass with sliding window
  for x in 0..<w {
    let mut sum_r = 0.0
    let mut sum_g = 0.0
    let mut sum_b = 0.0
    let mut sum_a = 0.0
    for dy in (0 - r)..<(r + 1) {
      let c = temp.get_pixel(x, dy.max(0).min(h - 1))
      sum_r = sum_r + c.r.to_int().to_double()
      sum_g = sum_g + c.g.to_int().to_double()
      sum_b = sum_b + c.b.to_int().to_double()
      sum_a = sum_a + c.a.to_int().to_double()
    }
    dst.set_pixel(
      x,
      0,
      @sun_graphics.Color::new(
        r=sun_blur_channel(sum_r, k),
        g=sun_blur_channel(sum_g, k),
        b=sun_blur_channel(sum_b, k),
        a=sun_blur_channel(sum_a, k),
      ),
    )
    for y in 1..<h {
      let leave = temp.get_pixel(x, (y - 1 - r).max(0))
      let enter = temp.get_pixel(x, (y + r).min(h - 1))
      sum_r = sum_r +
        enter.r.to_int().to_double() -
        leave.r.to_int().to_double()
      sum_g = sum_g +
        enter.g.to_int().to_double() -
        leave.g.to_int().to_double()
      sum_b = sum_b +
        enter.b.to_int().to_double() -
        leave.b.to_int().to_double()
      sum_a = sum_a +
        enter.a.to_int().to_double() -
        leave.a.to_int().to_double()
      dst.set_pixel(
        x,
        y,
        @sun_graphics.Color::new(
          r=sun_blur_channel(sum_r, k),
          g=sun_blur_channel(sum_g, k),
          b=sun_blur_channel(sum_b, k),
          a=sun_blur_channel(sum_a, k),
        ),
      )
    }
  }
  dst
}

///|
fn sun_blur_channel(sum : Double, count : Int) -> Byte {
  (sum / count.to_double() + 0.5).to_int().max(0).min(255).to_byte()
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
    @core.BlendMode::SourceOver => @sun_graphics.BlendMode::SourceOver
    @core.BlendMode::Multiply => @sun_graphics.BlendMode::Multiply
    @core.BlendMode::Screen => @sun_graphics.BlendMode::Screen
    @core.BlendMode::Overlay => @sun_graphics.BlendMode::Overlay
    @core.BlendMode::Darken => @sun_graphics.BlendMode::Darken
    @core.BlendMode::Lighten => @sun_graphics.BlendMode::Lighten
  }
}
