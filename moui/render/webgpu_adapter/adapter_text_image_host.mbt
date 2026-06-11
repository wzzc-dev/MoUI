///|
fn host_measure_text_layout(
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let text_chars = input.text.to_array()
  let carets : Array[Double] = [0.0]
  let prefix_chars : Array[Char] = []
  for ch in text_chars {
    prefix_chars.push(ch)
    let prefix = String::from_array(prefix_chars)
    carets.push(host_measure_text_width_for_input(input, prefix))
  }
  let measured_width = host_measure_text_width_for_input(input, input.text)
  let width = match input.max_width {
    Some(max_width) => measured_width.min(max_width)
    None => measured_width
  }
  match input.max_width {
    Some(max_width) =>
      for index in 0..<carets.length() {
        carets[index] = carets[index].min(max_width)
      }
    None => ()
  }
  {
    size: @core.Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn host_measure_text_width_for_input(
  input : @core.TextLayoutInput,
  text : String,
) -> Double {
  let measured = host_measure_text_width(
    host_string(text),
    host_string(input.font.css_family()),
    host_string(input.font.css_style()),
    input.font.size,
    input.font.weight,
  )
  if measured > 0.0 {
    measured
  } else {
    @core.TextSystem::fallback().measure_text({ ..input, text, }).size.width
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
