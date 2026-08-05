///|
fn SkiaRasterRenderer::record_unsupported_command(
  self : SkiaRasterRenderer,
  command : String,
  reason : String,
) -> Unit {
  self.unsupported_command_count = self.unsupported_command_count + 1
  self.unsupported_command_diagnostics.push({ command, reason })
}

///|
fn SkiaRasterRenderer::render_command(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  command : @render_common.PlanOp,
  canvas_scopes : Array[@render_common.PlanScopeKind],
) -> Unit {
  match command {
    @render_common.PlanOp::Clear(color) => canvas.clear(skia_color(color))
    @render_common.PlanOp::FillRect(rect, color) =>
      canvas.draw_rect(skia_rect(rect), skia_paint(color))
    @render_common.PlanOp::StrokeRect(rect, color, width) =>
      canvas.draw_rect(skia_rect(rect), skia_stroke_paint(color, width))
    @render_common.PlanOp::FillRoundedRect(rounded, color) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_paint(color),
      )
    @render_common.PlanOp::StrokeRoundedRect(rounded, color, width) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_stroke_paint(color, width),
      )
    @render_common.PlanOp::FillRoundedRectBrush(rounded, brush) =>
      self.draw_brush_rounded_rect(canvas, rounded, brush, stroke_width=None)
    @render_common.PlanOp::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.draw_brush_rounded_rect(
        canvas,
        rounded,
        brush,
        stroke_width=Some(width),
      )
    @render_common.PlanOp::DrawShadow(shadow) =>
      self.draw_shadow(canvas, shadow)
    @render_common.PlanOp::DrawText(run) => self.draw_text(canvas, run)
    @render_common.PlanOp::DrawImage(run) => self.draw_image(canvas, run)
    @render_common.PlanOp::PushClip(rect) => {
      ignore(canvas.save())
      canvas_scopes.push(@render_common.PlanScopeKind::Clip)
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @render_common.PlanOp::PopClip =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Clip,
      )
    @render_common.PlanOp::PushRoundedClip(rounded) => {
      ignore(canvas.save())
      canvas_scopes.push(@render_common.PlanScopeKind::RoundedClip)
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
    @render_common.PlanOp::PopRoundedClip =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::RoundedClip,
      )
    @render_common.PlanOp::PushTransform(transform) => {
      ignore(canvas.save())
      canvas_scopes.push(@render_common.PlanScopeKind::Transform)
      canvas.concat(skia_matrix(transform))
    }
    @render_common.PlanOp::PopTransform =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Transform,
      )
    @render_common.PlanOp::PushOpacity(opacity) => {
      ignore(canvas.save_layer(paint=skia_opacity_paint(opacity)))
      canvas_scopes.push(@render_common.PlanScopeKind::Opacity)
    }
    @render_common.PlanOp::PopOpacity =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Opacity,
      )
    @render_common.PlanOp::PushLayer(layer) => {
      self.push_layer(canvas, layer)
      canvas_scopes.push(@render_common.PlanScopeKind::Layer)
    }
    @render_common.PlanOp::PopLayer =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Layer,
      )
    @render_common.PlanOp::BeginCachedLayer(spec) => {
      self.push_layer(
        canvas,
        @core.LayerSpec::new(
          mask=@core.LayerMask::RectMask(spec.frame),
          offscreen=true,
        ),
      )
      canvas_scopes.push(@render_common.PlanScopeKind::Layer)
    }
    @render_common.PlanOp::EndCachedLayer(_) =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Layer,
      )
    @render_common.PlanOp::DrawCachedLayer(spec) =>
      self.record_unsupported_command(
        "DrawCachedLayer",
        "renderer-local cached layer was requested without a host-expanded cache entry: \{spec.key}",
      )
    @render_common.PlanOp::PushFilter(filter) => {
      self.push_filter(canvas, filter)
      canvas_scopes.push(@render_common.PlanScopeKind::Filter)
    }
    @render_common.PlanOp::PopFilter =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        @render_common.PlanScopeKind::Filter,
      )
    @render_common.PlanOp::DrawPath(path) => self.draw_path(canvas, path)
    @render_common.PlanOp::DrawShaderEffect(spec) =>
      self.draw_shader_effect(canvas, spec)
  }
}

///|
fn SkiaRasterRenderer::pop_canvas_scope(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  expected : @render_common.PlanScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        canvas.restore()
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
fn SkiaRasterRenderer::push_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  filter : @core.FilterEffect,
) -> Unit {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      match
        @skia_native.ImageFilter::blur(
          Float::from_double(radius.max(0.0)),
          Float::from_double(radius.max(0.0)),
        ) {
        Some(image_filter) =>
          ignore(canvas.save_layer(image_filter=Some(image_filter)))
        None => {
          ignore(canvas.save_layer())
          self.record_unsupported_command(
            "PushFilter", "Skia blur image filter unavailable; used unfiltered layer",
          )
        }
      }
    @core.FilterEffect::Saturate(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::saturation(Float::from_double(amount)),
      )
    @core.FilterEffect::Brightness(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::brightness(Float::from_double(amount)),
      )
    @core.FilterEffect::Contrast(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::contrast(Float::from_double(amount)),
      )
    @core.FilterEffect::ColorMatrix(values) =>
      self.push_color_filter(canvas, skia_color_filter_matrix(values))
  }
}

///|
fn SkiaRasterRenderer::push_color_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  color_filter : @skia_native.ColorFilter?,
) -> Unit {
  match color_filter {
    Some(color_filter) =>
      ignore(canvas.save_layer(color_filter=Some(color_filter)))
    None => {
      ignore(canvas.save_layer())
      self.record_unsupported_command(
        "PushFilter", "Skia color filter unavailable; used unfiltered layer",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shadow(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  shadow : @core.ShadowSpec,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  let expanded = skia_shadow_rect(shadow, grow=spread)
  let radius = (shadow.rect.radius + spread).max(0.0)
  if blur > 0.0 {
    match @skia_native.MaskFilter::blur(Float::from_double(blur)) {
      Some(mask_filter) => {
        let saved = canvas.save_layer(
          bounds=Some(
            skia_rect(skia_shadow_rect(shadow, grow=spread + blur * 3.0)),
          ),
          mask_filter=Some(mask_filter),
        )
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        canvas.restore_to_count(saved)
      }
      None => {
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        self.record_unsupported_command(
          "DrawShadow", "Skia mask filter unavailable; drew unblurred shadow",
        )
      }
    }
    return ()
  }
  canvas.draw_round_rect(
    skia_rect(expanded),
    Float::from_double(radius),
    Float::from_double(radius),
    skia_paint(shadow.color),
  )
}

///|
fn skia_shadow_rect(shadow : @core.ShadowSpec, grow~ : Double) -> @core.Rect {
  let rect = shadow.rect.rect
  @core.Rect::new(
    x=rect.origin.x + shadow.offset.x - grow,
    y=rect.origin.y + shadow.offset.y - grow,
    width=rect.size.width + grow * 2.0,
    height=rect.size.height + grow * 2.0,
  )
}

///|
fn SkiaRasterRenderer::draw_brush_rounded_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  stroke_width~ : Double?,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_stroke_paint(color, width),
          )
        None =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(color),
          )
      }
    _ =>
      match skia_brush_shader(brush) {
        Some(shader) =>
          match stroke_width {
            Some(width) =>
              canvas.draw_round_rect_shader(
                skia_rect(rounded.rect),
                Float::from_double(rounded.radius),
                Float::from_double(rounded.radius),
                shader,
                skia_stroke_paint(brush.fallback_color(), width),
              )
            None => {
              ignore(canvas.save())
              canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
              canvas.draw_rect_shader(
                skia_rect(rounded.rect),
                shader,
                @moui_skia.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
          }
        None => {
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(brush.fallback_color()),
          )
          self.record_unsupported_command(
            "FillRoundedRectBrush", "Skia brush shader unavailable; used fallback color",
          )
        }
      }
  }
}

///|
fn SkiaRasterRenderer::push_layer(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  layer : @core.LayerSpec,
) -> Unit {
  let paint = skia_opacity_paint(layer.opacity).set_blend_mode(
    skia_blend_mode(layer.blend_mode),
  )
  match layer.mask {
    @core.LayerMask::NoMask => ignore(canvas.save_layer(paint~))
    @core.LayerMask::RectMask(rect) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rect)), paint~))
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @core.LayerMask::RoundedMask(rounded) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rounded.rect)), paint~))
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
  }
  if layer.offscreen {
    ignore(layer.offscreen)
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_path(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.PathSpec,
) -> Unit {
  match skia_path(spec) {
    Some(path) => {
      match spec.fill {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_paint(color))
        Some(brush) =>
          self.draw_path_brush(canvas, path, brush, stroke_width=None)
        None => ()
      }
      match spec.stroke {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_stroke_paint(color, spec.stroke_width))
        Some(brush) =>
          self.draw_path_brush(
            canvas,
            path,
            brush,
            stroke_width=Some(spec.stroke_width),
          )
        None => ()
      }
    }
    None =>
      self.record_unsupported_command(
        "DrawPath", "Skia path conversion unavailable; skipped path",
      )
  }
}

///|
fn SkiaRasterRenderer::draw_path_brush(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  path : @skia_native.Path,
  brush : @core.Brush,
  stroke_width~ : Double?,
) -> Unit {
  match skia_brush_shader(brush) {
    Some(shader) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_path_shader(
            path,
            shader,
            skia_stroke_paint(brush.fallback_color(), width),
          )
        None =>
          match path.bounds() {
            Some(bounds) => {
              ignore(canvas.save())
              canvas.clip_path(path, anti_alias=true)
              canvas.draw_rect_shader(
                bounds,
                shader,
                @moui_skia.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
            None => ()
          }
      }
    None => {
      let paint = match stroke_width {
        Some(width) => skia_stroke_paint(brush.fallback_color(), width)
        None => skia_paint(brush.fallback_color())
      }
      canvas.draw_path(path, paint)
      self.record_unsupported_command(
        "DrawPath", "Skia brush shader unavailable; used fallback color",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shader_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  match spec.name {
    "solid" => self.draw_brush_rect(canvas, spec.frame, spec.fallback)
    "checker" => self.draw_checker_effect(canvas, spec)
    "linear-gradient-debug" => self.draw_linear_gradient_debug(canvas, spec)
    "vignette" => self.draw_vignette_effect(canvas, spec)
    _ => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.record_unsupported_command(
        "DrawShaderEffect",
        "unknown shader effect '\{spec.name}' used fallback brush",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_brush_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  frame : @core.Rect,
  brush : @core.Brush,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      canvas.draw_rect(skia_rect(frame), skia_paint(color))
    _ =>
      match skia_brush_shader(brush) {
        Some(shader) =>
          canvas.draw_rect_shader(
            skia_rect(frame),
            shader,
            @moui_skia.Paint::new(anti_alias=true),
          )
        None => {
          canvas.draw_rect(skia_rect(frame), skia_paint(brush.fallback_color()))
          self.record_unsupported_command(
            "FillRectBrush", "Skia brush shader unavailable; used fallback color",
          )
        }
      }
  }
}

///|
fn skia_brush_shader(brush : @core.Brush) -> @skia_native.Shader? {
  match brush {
    @core.Brush::Solid(_) => None
    @core.Brush::LinearGradient(gradient) =>
      @skia_native.Shader::linear_gradient(
        skia_point(gradient.start),
        skia_point(gradient.end),
        skia_color(gradient.start_color),
        skia_color(gradient.end_color),
      )
    @core.Brush::RadialGradient(gradient) =>
      @skia_native.Shader::radial_gradient(
        skia_point(gradient.center),
        Float::from_double(gradient.radius),
        skia_color(gradient.center_color),
        skia_color(gradient.edge_color),
      )
  }
}

///|
fn SkiaRasterRenderer::draw_checker_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let amount = match spec.uniforms.get(0) {
    Some(value) => value.max(1.0)
    None => 8.0
  }
  let (color_a, color_b) = skia_shader_effect_colors(spec.fallback)
  let cell = (spec.frame.size.width.min(spec.frame.size.height) / amount).max(
    1.0,
  )
  let columns = (spec.frame.size.width / cell).ceil().to_int().max(1)
  let rows = (spec.frame.size.height / cell).ceil().to_int().max(1)
  for row in 0..<rows {
    for column in 0..<columns {
      let color = if (row + column) % 2 == 0 { color_a } else { color_b }
      let x = spec.frame.origin.x + column.to_double() * cell
      let y = spec.frame.origin.y + row.to_double() * cell
      canvas.draw_rect(
        skia_rect(
          @core.Rect::new(
            x~,
            y~,
            width=cell.min(spec.frame.origin.x + spec.frame.size.width - x),
            height=cell.min(spec.frame.origin.y + spec.frame.size.height - y),
          ),
        ),
        skia_paint(color),
      )
    }
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_linear_gradient_debug(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (start_color, end_color) = skia_shader_effect_colors(spec.fallback)
  let gradient = @core.LinearGradientSpec::new(
    start=spec.frame.origin,
    end=@core.Point::new(
      x=spec.frame.origin.x + spec.frame.size.width,
      y=spec.frame.origin.y,
    ),
    start_color~,
    end_color~,
  )
  self.draw_brush_rect(
    canvas,
    spec.frame,
    @core.Brush::LinearGradient(gradient),
  )
}

///|
fn SkiaRasterRenderer::draw_vignette_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (color, _) = skia_shader_effect_colors(spec.fallback)
  let center = @core.Point::new(
    x=spec.frame.origin.x + spec.frame.size.width / 2.0,
    y=spec.frame.origin.y + spec.frame.size.height / 2.0,
  )
  let radius = spec.frame.size.width.max(spec.frame.size.height) /
    2.0 *
    skia_vignette_radius_scale(spec)
  let outer_color = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=color.a)
  match
    @skia_native.Shader::radial_gradient(
      skia_point(center),
      Float::from_double(radius),
      skia_color(color),
      skia_color(outer_color),
    ) {
    Some(shader) =>
      canvas.draw_rect_shader(
        skia_rect(spec.frame),
        shader,
        @moui_skia.Paint::new(anti_alias=true),
      )
    None => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.record_unsupported_command(
        "DrawShaderEffect", "Skia radial shader unavailable for vignette; used fallback brush",
      )
    }
  }
}

///|
fn skia_vignette_radius_scale(spec : @core.ShaderEffectSpec) -> Double {
  match spec.uniforms.get(0) {
    Some(amount) => amount.max(0.8)
    None => 0.8
  }
}

///|
fn skia_dim_to_int(value : Double) -> Int {
  value.ceil().max(1.0).to_int()
}

///|
fn skia_color(color : @core.Color) -> @moui_skia.Color {
  @moui_skia.Color::from_argb(
    color_component_byte(color.a),
    color_component_byte(color.r),
    color_component_byte(color.g),
    color_component_byte(color.b),
  )
}

///|
fn color_component_byte(value : Double) -> Byte {
  (value.max(0.0).min(1.0) * 255.0).round().to_int().to_byte()
}

///|
fn skia_paint(color : @core.Color) -> @moui_skia.Paint {
  @moui_skia.Paint::new(color=skia_color(color), anti_alias=true)
}

///|
fn skia_opacity_paint(opacity : Double) -> @moui_skia.Paint {
  @moui_skia.Paint::new(
    color=@moui_skia.Color::white().with_alpha(color_component_byte(opacity)),
    anti_alias=true,
  )
}

///|
fn skia_stroke_paint(color : @core.Color, width : Double) -> @moui_skia.Paint {
  @moui_skia.Paint::new(color=skia_color(color), anti_alias=true)
  .set_stroke(true)
  .set_stroke_width(Float::from_double(width.max(0.0)))
}

///|
fn skia_blend_mode(mode : @core.BlendMode) -> @moui_skia.BlendMode {
  match mode {
    @core.BlendMode::SourceOver => @moui_skia.BlendMode::SrcOver
    @core.BlendMode::Multiply => @moui_skia.BlendMode::Multiply
    @core.BlendMode::Screen => @moui_skia.BlendMode::Screen
    @core.BlendMode::Overlay => @moui_skia.BlendMode::Overlay
    @core.BlendMode::Darken => @moui_skia.BlendMode::Darken
    @core.BlendMode::Lighten => @moui_skia.BlendMode::Lighten
  }
}

///|
fn skia_shader_effect_colors(
  fallback : @core.Brush,
) -> (@core.Color, @core.Color) {
  match fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
    @core.Brush::RadialGradient(gradient) =>
      (gradient.center_color, gradient.edge_color)
  }
}

///|
fn skia_color_filter_matrix(
  values : Array[Double],
) -> @skia_native.ColorFilter? {
  @skia_native.ColorFilter::matrix(skia_color_filter_matrix_values(values))
}

///|
fn skia_color_filter_matrix_values(values : Array[Double]) -> Array[Float] {
  let matrix = skia_identity_color_matrix_values()
  let count = values.length().min(20)
  for index in 0..<count {
    matrix[index] = Float::from_double(values[index])
  }
  matrix
}

///|
fn skia_identity_color_matrix_values() -> Array[Float] {
  let matrix : Array[Float] = []
  for index in 0..<20 {
    matrix.push(
      if index == 0 || index == 6 || index == 12 || index == 18 {
        1.0
      } else {
        0.0
      },
    )
  }
  matrix
}

///|
fn skia_rect(rect : @core.Rect) -> @moui_skia.Rect {
  @moui_skia.Rect::from_xywh(
    Float::from_double(rect.origin.x),
    Float::from_double(rect.origin.y),
    Float::from_double(rect.size.width),
    Float::from_double(rect.size.height),
  )
}

///|
fn skia_point(point : @core.Point) -> @moui_skia.Point {
  @moui_skia.Point::new(
    Float::from_double(point.x),
    Float::from_double(point.y),
  )
}

///|
fn skia_rrect(rounded : @core.RoundedRect) -> @moui_skia.RRect {
  @moui_skia.RRect::from_rect_xy(
    skia_rect(rounded.rect),
    Float::from_double(rounded.radius),
    Float::from_double(rounded.radius),
  )
}

///|
fn skia_matrix(transform : @core.Transform2D) -> @moui_skia.Matrix {
  @moui_skia.Matrix::from_affine([
    Float::from_double(transform.a),
    Float::from_double(transform.c),
    Float::from_double(transform.tx),
    Float::from_double(transform.b),
    Float::from_double(transform.d),
    Float::from_double(transform.ty),
  ]).unwrap_or(@moui_skia.Matrix::identity())
}

///|
fn skia_path(spec : @core.PathSpec) -> @skia_native.Path? {
  match @skia_native.Path::new() {
    Some(path) => {
      for verb in spec.verbs {
        match verb {
          @core.PathVerb::MoveTo(point) => path.move_to(skia_point(point))
          @core.PathVerb::LineTo(point) => path.line_to(skia_point(point))
          @core.PathVerb::QuadTo(control, end) =>
            path.quad_to(skia_point(control), skia_point(end))
          @core.PathVerb::CubicTo(c1, c2, end) =>
            path.cubic_to(skia_point(c1), skia_point(c2), skia_point(end))
          @core.PathVerb::Close => path.close()
        }
      }
      Some(path)
    }
    None => None
  }
}
