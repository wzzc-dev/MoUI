///|
pub fn draw_commands_to_host_calls(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> Array[WebGpuHostCall] {
  let calls : Array[WebGpuHostCall] = [BeginFrame(size)]
  for command in commands {
    match command {
      Clear(color) => calls.push(Clear(color))
      FillRect(rect, color) => calls.push(FillRect(rect, color))
      StrokeRect(rect, color, width) =>
        calls.push(StrokeRect(rect, color, width))
      FillRoundedRect(rect, color) => calls.push(FillRoundedRect(rect, color))
      StrokeRoundedRect(rect, color, width) =>
        calls.push(StrokeRoundedRect(rect, color, width))
      FillRoundedRectBrush(rect, brush) =>
        calls.push(FillRoundedRectBrush(rect, brush))
      StrokeRoundedRectBrush(rect, brush, width) =>
        calls.push(StrokeRoundedRectBrush(rect, brush, width))
      DrawShadow(shadow) => calls.push(DrawShadow(shadow))
      DrawText(run) => calls.push(DrawText(run))
      DrawImage(run) => calls.push(DrawImage(run))
      DrawPath(path) => calls.push(DrawPath(path))
      PushClip(rect) => calls.push(PushClip(rect))
      PopClip => calls.push(PopClip)
      PushRoundedClip(rect) => calls.push(PushRoundedClip(rect))
      PopRoundedClip => calls.push(PopRoundedClip)
      PushTransform(transform) => calls.push(PushTransform(transform))
      PopTransform => calls.push(PopTransform)
      PushOpacity(opacity) => calls.push(PushOpacity(opacity))
      PopOpacity => calls.push(PopOpacity)
      PushLayer(layer) => calls.push(PushLayer(layer))
      PopLayer => calls.push(PopLayer)
      BeginRetainedLayer(spec) =>
        calls.push(
          PushLayer(
            @core.LayerSpec::new(mask=RectMask(spec.frame), offscreen=true),
          ),
        )
      EndRetainedLayer(_) => calls.push(PopLayer)
      PushFilter(filter) => calls.push(PushFilter(filter))
      PopFilter => calls.push(PopFilter)
      DrawShaderEffect(spec) => calls.push(DrawShaderEffect(spec))
    }
  }
  calls.push(Present)
  calls
}

///|
fn ensure_required_capabilities(
  capabilities : WebGpuHostCapabilities,
) -> Unit raise WebGpuHostError {
  if !capabilities.webgpu_available() {
    raise Unavailable
  }
  if !capabilities.adapter_ready() {
    raise AdapterUnavailable
  }
  if !capabilities.can_render() {
    raise PipelineUnavailable
  }
}

///|
fn submit_host_calls(
  renderer : HostWebGpuRenderer,
  calls : Array[WebGpuHostCall],
) -> Unit raise WebGpuHostError {
  for call in calls {
    match call {
      BeginFrame(size) =>
        raise_for_host_status(
          host_begin_frame(renderer, size.width, size.height),
        )
      Clear(color) =>
        raise_for_host_status(
          host_clear(renderer, color.r, color.g, color.b, color.a),
        )
      FillRect(rect, color) =>
        raise_for_host_status(
          host_fill_rect(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            color.r,
            color.g,
            color.b,
            color.a,
          ),
        )
      StrokeRect(rect, color, width) =>
        raise_for_host_status(
          host_stroke_rect(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            color.r,
            color.g,
            color.b,
            color.a,
            width,
          ),
        )
      FillRoundedRect(rounded, color) =>
        raise_for_host_status(
          host_fill_rounded_rect(
            renderer,
            rounded.rect.origin.x,
            rounded.rect.origin.y,
            rounded.rect.size.width,
            rounded.rect.size.height,
            rounded.radius,
            color.r,
            color.g,
            color.b,
            color.a,
          ),
        )
      StrokeRoundedRect(rounded, color, width) =>
        raise_for_host_status(
          host_stroke_rounded_rect(
            renderer,
            rounded.rect.origin.x,
            rounded.rect.origin.y,
            rounded.rect.size.width,
            rounded.rect.size.height,
            rounded.radius,
            color.r,
            color.g,
            color.b,
            color.a,
            width,
          ),
        )
      FillRoundedRectBrush(rounded, brush) =>
        submit_fill_rounded_rect_brush(renderer, rounded, brush)
      StrokeRoundedRectBrush(rounded, brush, width) =>
        submit_stroke_rounded_rect_brush(renderer, rounded, brush, width)
      DrawShadow(shadow) =>
        raise_for_host_status(
          host_draw_shadow(
            renderer,
            shadow.rect.rect.origin.x,
            shadow.rect.rect.origin.y,
            shadow.rect.rect.size.width,
            shadow.rect.rect.size.height,
            shadow.rect.radius,
            shadow.offset.x,
            shadow.offset.y,
            shadow.blur_radius,
            shadow.spread,
            shadow.color.r,
            shadow.color.g,
            shadow.color.b,
            shadow.color.a,
          ),
        )
      DrawText(run) =>
        raise_for_host_status(
          host_draw_text(
            renderer,
            host_string(run.text),
            run.frame.origin.x,
            run.frame.origin.y,
            run.frame.size.width,
            run.frame.size.height,
            host_string(run.font.css_family()),
            host_string(run.font.css_style()),
            run.font.size,
            run.font.weight,
            run.color.r,
            run.color.g,
            run.color.b,
            run.color.a,
            text_align_host_code(run.align),
          ),
        )
      DrawImage(run) =>
        raise_for_host_status(
          host_draw_image(
            renderer,
            host_string(run.source),
            run.frame.origin.x,
            run.frame.origin.y,
            run.frame.size.width,
            run.frame.size.height,
            run.opacity,
            image_fit_host_code(run.fit),
          ),
        )
      DrawPath(path) => submit_draw_path(renderer, path)
      PushClip(rect) =>
        raise_for_host_status(
          host_push_clip(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
          ),
        )
      PopClip => raise_for_host_status(host_pop_clip(renderer))
      PushRoundedClip(rounded) => submit_push_rounded_clip(renderer, rounded)
      PopRoundedClip => raise_for_host_status(host_pop_layer(renderer))
      PushTransform(transform) =>
        raise_for_host_status(
          host_push_transform(
            renderer,
            transform.a,
            transform.b,
            transform.c,
            transform.d,
            transform.tx,
            transform.ty,
          ),
        )
      PopTransform => raise_for_host_status(host_pop_transform(renderer))
      PushOpacity(opacity) =>
        raise_for_host_status(host_push_opacity(renderer, opacity))
      PopOpacity => raise_for_host_status(host_pop_opacity(renderer))
      PushLayer(layer) => submit_push_layer(renderer, layer)
      PopLayer => raise_for_host_status(host_pop_layer(renderer))
      PushFilter(filter) => submit_push_filter(renderer, filter)
      PopFilter => raise_for_host_status(host_pop_filter(renderer))
      DrawShaderEffect(spec) => submit_draw_shader_effect(renderer, spec)
      Present => raise_for_host_status(host_present(renderer))
    }
  }
}

///|
fn submit_push_layer(
  renderer : HostWebGpuRenderer,
  layer : @core.LayerSpec,
) -> Unit raise WebGpuHostError {
  let mask = layer_mask_payload(layer.mask)
  raise_for_host_status(
    host_push_layer(
      renderer,
      layer.opacity,
      blend_mode_host_code(layer.blend_mode),
      mask.kind,
      mask.rect.origin.x,
      mask.rect.origin.y,
      mask.rect.size.width,
      mask.rect.size.height,
      mask.radius,
      layer.offscreen,
    ),
  )
}

///|
fn submit_push_rounded_clip(
  renderer : HostWebGpuRenderer,
  rounded : @core.RoundedRect,
) -> Unit raise WebGpuHostError {
  let mask = layer_mask_payload(RoundedMask(rounded))
  raise_for_host_status(
    host_push_layer(
      renderer,
      1.0,
      blend_mode_host_code(SourceOver),
      mask.kind,
      mask.rect.origin.x,
      mask.rect.origin.y,
      mask.rect.size.width,
      mask.rect.size.height,
      mask.radius,
      true,
    ),
  )
}

///|
fn submit_push_filter(
  renderer : HostWebGpuRenderer,
  filter : @core.FilterEffect,
) -> Unit raise WebGpuHostError {
  let payload = filter_effect_payload(filter)
  raise_for_host_status(
    host_push_filter(
      renderer,
      payload.kind,
      payload.amount,
      host_string(payload.matrix_values),
    ),
  )
}

///|
fn submit_draw_shader_effect(
  renderer : HostWebGpuRenderer,
  spec : @core.ShaderEffectSpec,
) -> Unit raise WebGpuHostError {
  let fallback = brush_payload(spec.fallback, spec.frame)
  raise_for_host_status(
    host_draw_shader_effect(
      renderer,
      host_string(spec.name),
      spec.frame.origin.x,
      spec.frame.origin.y,
      spec.frame.size.width,
      spec.frame.size.height,
      host_string(double_array_string(spec.uniforms)),
      fallback.start.x,
      fallback.start.y,
      fallback.end.x,
      fallback.end.y,
      fallback.start_color.r,
      fallback.start_color.g,
      fallback.start_color.b,
      fallback.start_color.a,
      fallback.end_color.r,
      fallback.end_color.g,
      fallback.end_color.b,
      fallback.end_color.a,
    ),
  )
}

///|
fn submit_draw_path(
  renderer : HostWebGpuRenderer,
  path : @core.PathSpec,
) -> Unit raise WebGpuHostError {
  let mesh = @render_common.tessellate_path(path)
  raise_for_host_status(
    host_draw_path_mesh(renderer, host_string(path_mesh_payload(mesh))),
  )
}
