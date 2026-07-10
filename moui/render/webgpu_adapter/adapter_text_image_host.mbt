///|
fn host_measure_text_layout(
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let measured_width = host_measure_text_width(
    host_string(input.text),
    host_string(input.font.css_family()),
    host_string(input.font.css_style()),
    input.font.size,
    input.font.weight,
  )
  host_text_layout_from_measured_width(input, measured_width)
}

///|
fn host_text_layout_from_measured_width(
  input : @core.TextLayoutInput,
  measured_width : Double,
) -> @core.TextLayoutResult {
  let fallback = @core.TextSystem::fallback().measure_text({
    ..input,
    max_width: None,
  })
  let resolved_width = if measured_width > 0.0 || input.text == "" {
    measured_width.max(0.0)
  } else {
    fallback.size.width
  }
  let scale = if fallback.size.width > 0.0 {
    resolved_width / fallback.size.width
  } else {
    1.0
  }
  let carets : Array[Double] = []
  for caret in fallback.caret_positions {
    let scaled = caret * scale
    carets.push(
      match input.max_width {
        Some(max_width) => scaled.min(max_width.max(0.0))
        None => scaled
      },
    )
  }
  let width = match input.max_width {
    Some(max_width) => resolved_width.min(max_width.max(0.0))
    None => resolved_width
  }
  {
    size: @core.Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn host_image_resource_record(
  renderer : HostWebGpuRenderer,
  source : String,
) -> @render.ImageResourceRecord? {
  let source_handle = host_string(source)
  match host_image_resource_status(renderer, source_handle) {
    1 => Some(@render.ImageResourceRecord::loading(source))
    2 =>
      Some(
        @render.ImageResourceRecord::ready(
          source,
          width=host_image_resource_width(renderer, source_handle),
          height=host_image_resource_height(renderer, source_handle),
        ),
      )
    3 =>
      Some(
        @render.ImageResourceRecord::failed(
          source,
          diagnostic="browser image load failed",
        ),
      )
    _ => None
  }
}
