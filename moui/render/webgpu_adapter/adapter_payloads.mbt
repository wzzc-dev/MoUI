///|
fn path_mesh_payload(mesh : @render.PathMesh) -> String {
  let values : Array[String] = []
  for vertex in mesh.vertices() {
    for component in vertex.components() {
      values.push(component.to_string())
    }
  }
  values.join(",")
}

///|
priv struct HostLayerMaskPayload {
  kind : Int
  rect : @core.Rect
  radius : Double
}

///|
fn layer_mask_payload(mask : @core.LayerMask) -> HostLayerMaskPayload {
  match mask {
    @core.LayerMask::NoMask =>
      {
        kind: 0,
        rect: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        radius: 0.0,
      }
    @core.LayerMask::RectMask(rect) => { kind: 1, rect, radius: 0.0 }
    @core.LayerMask::RoundedMask(rounded) =>
      { kind: 2, rect: rounded.rect, radius: rounded.radius }
  }
}

///|
priv struct HostFilterPayload {
  kind : Int
  amount : Double
  matrix_values : String
}

///|
fn filter_effect_payload(filter : @core.FilterEffect) -> HostFilterPayload {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      { kind: 0, amount: radius.max(0.0), matrix_values: "" }
    @core.FilterEffect::Saturate(amount) =>
      { kind: 1, amount, matrix_values: "" }
    @core.FilterEffect::Brightness(amount) =>
      { kind: 2, amount, matrix_values: "" }
    @core.FilterEffect::Contrast(amount) =>
      { kind: 3, amount, matrix_values: "" }
    @core.FilterEffect::ColorMatrix(values) =>
      { kind: 4, amount: 1.0, matrix_values: double_array_string(values) }
  }
}

///|
fn blend_mode_host_code(mode : @core.BlendMode) -> Int {
  match mode {
    @core.BlendMode::SourceOver => 0
    @core.BlendMode::Multiply => 1
    @core.BlendMode::Screen => 2
    @core.BlendMode::Overlay => 3
    @core.BlendMode::Darken => 4
    @core.BlendMode::Lighten => 5
  }
}

///|
fn brush_payload(brush : @core.Brush, frame : @core.Rect) -> HostBrushPayload {
  match brush {
    @core.Brush::Solid(color) =>
      {
        start: frame.origin,
        end: @core.Point::new(x=frame.origin.x + 1.0, y=frame.origin.y),
        start_color: color,
        end_color: color,
      }
    @core.Brush::LinearGradient(gradient) =>
      {
        start: gradient.start,
        end: gradient.end,
        start_color: gradient.start_color,
        end_color: gradient.end_color,
      }
    @core.Brush::RadialGradient(gradient) =>
      {
        start: gradient.center,
        end: @core.Point::new(
          x=gradient.center.x + gradient.radius.max(1.0),
          y=gradient.center.y,
        ),
        start_color: gradient.center_color,
        end_color: gradient.edge_color,
      }
  }
}

///|
fn radial_brush_payload(
  gradient : @core.RadialGradientSpec,
) -> HostRadialBrushPayload {
  {
    center: gradient.center,
    radius: gradient.radius.max(1.0),
    center_color: gradient.center_color,
    edge_color: gradient.edge_color,
  }
}

///|
fn rounded_brush_host_payload(
  brush : @core.Brush,
  frame : @core.Rect,
) -> RoundedBrushHostPayload {
  match brush {
    @core.Brush::Solid(color) => RoundedBrushHostPayload::SolidColor(color)
    @core.Brush::LinearGradient(_) =>
      RoundedBrushHostPayload::LinearGradientPayload(
        brush_payload(brush, frame),
      )
    @core.Brush::RadialGradient(gradient) =>
      RoundedBrushHostPayload::RadialGradientPayload(
        radial_brush_payload(gradient),
      )
  }
}

///|
fn double_array_string(values : Array[Double]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push(value.to_string())
  }
  parts.join(",")
}

///|
fn submit_fill_rounded_rect_brush(
  renderer : HostWebGpuRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
) -> Unit raise WebGpuHostError {
  match rounded_brush_host_payload(brush, rounded.rect) {
    RoundedBrushHostPayload::SolidColor(color) =>
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
    RoundedBrushHostPayload::LinearGradientPayload(payload) =>
      raise_for_host_status(
        host_fill_rounded_rect_gradient(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          payload.start.x,
          payload.start.y,
          payload.end.x,
          payload.end.y,
          payload.start_color.r,
          payload.start_color.g,
          payload.start_color.b,
          payload.start_color.a,
          payload.end_color.r,
          payload.end_color.g,
          payload.end_color.b,
          payload.end_color.a,
        ),
      )
    RoundedBrushHostPayload::RadialGradientPayload(payload) =>
      raise_for_host_status(
        host_fill_rounded_rect_radial(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          payload.center.x,
          payload.center.y,
          payload.radius,
          payload.center_color.r,
          payload.center_color.g,
          payload.center_color.b,
          payload.center_color.a,
          payload.edge_color.r,
          payload.edge_color.g,
          payload.edge_color.b,
          payload.edge_color.a,
        ),
      )
  }
}

///|
fn submit_stroke_rounded_rect_brush(
  renderer : HostWebGpuRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
) -> Unit raise WebGpuHostError {
  match rounded_brush_host_payload(brush, rounded.rect) {
    RoundedBrushHostPayload::SolidColor(color) =>
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
    RoundedBrushHostPayload::LinearGradientPayload(payload) =>
      raise_for_host_status(
        host_stroke_rounded_rect_gradient(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          width,
          payload.start.x,
          payload.start.y,
          payload.end.x,
          payload.end.y,
          payload.start_color.r,
          payload.start_color.g,
          payload.start_color.b,
          payload.start_color.a,
          payload.end_color.r,
          payload.end_color.g,
          payload.end_color.b,
          payload.end_color.a,
        ),
      )
    RoundedBrushHostPayload::RadialGradientPayload(payload) =>
      raise_for_host_status(
        host_stroke_rounded_rect_radial(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          width,
          payload.center.x,
          payload.center.y,
          payload.radius,
          payload.center_color.r,
          payload.center_color.g,
          payload.center_color.b,
          payload.center_color.a,
          payload.edge_color.r,
          payload.edge_color.g,
          payload.edge_color.b,
          payload.edge_color.a,
        ),
      )
  }
}
