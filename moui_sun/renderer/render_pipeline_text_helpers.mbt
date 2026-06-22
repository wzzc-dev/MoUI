///|
fn render_pipeline_parse_font_bytes_fallback_sources_result(
  sources : Array[FontBytesFallbackSource],
) -> Result[Array[@text.FontFace], RenderPipelineReplayError] {
  let faces : Array[@text.FontFace] = []
  for source in sources {
    match @text.FontFace::from_bytes(source.get_font_data()) {
      Ok(face) => faces.push(face)
      Err(error) =>
        return Err(
          RenderPipelineReplayError::FontParseFailed(
            source.get_font_key(),
            error,
          ),
        )
    }
  }
  Ok(faces)
}

///|
fn render_pipeline_first_font_key(font_keys : Array[String]) -> String {
  match font_keys.get(0) {
    Some(font_key) => font_key
    None => ""
  }
}

///|
fn render_pipeline_fallback_text_width(
  text : String,
  config : @text.LayoutConfig,
) -> Double {
  if config.max_width > 0.0 {
    config.max_width
  } else {
    text.length().to_double() * config.font_size.max(1.0)
  }
}
