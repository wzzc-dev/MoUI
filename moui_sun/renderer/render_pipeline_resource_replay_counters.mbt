///|
priv struct RenderPipelineImageCacheReplayCounters {
  mut keyed_image_count : Int32
  mut image_cache_hit_count : Int32
  mut image_cache_insert_count : Int32
}

///|
fn RenderPipelineImageCacheReplayCounters::new() -> RenderPipelineImageCacheReplayCounters {
  {
    keyed_image_count: 0,
    image_cache_hit_count: 0,
    image_cache_insert_count: 0,
  }
}

///|
fn RenderPipelineImageCacheReplayCounters::record_cached_image(
  self : RenderPipelineImageCacheReplayCounters,
  did_hit_cache : Bool,
) -> Unit {
  if did_hit_cache {
    self.image_cache_hit_count += 1
  } else {
    self.image_cache_insert_count += 1
  }
  self.keyed_image_count += 1
}

///|
fn record_bmp_resource_image_replay_result(
  replay_state : RenderPipelineResourceReplayState,
  resource_key : String,
  result : Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError],
) -> Result[Int32, RenderPipelineResourceReplayError] {
  match result {
    Ok(result) => {
      replay_state.image_cache_counters.record_cached_image(
        result.did_hit_cache(),
      )
      Ok(1)
    }
    Err(error) => Err(ImageDecodeFailed(resource_key, error))
  }
}

///|
fn record_png_resource_image_replay_result(
  replay_state : RenderPipelineResourceReplayState,
  resource_key : String,
  result : Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError],
) -> Result[Int32, RenderPipelineResourceReplayError] {
  match result {
    Ok(result) => {
      replay_state.image_cache_counters.record_cached_image(
        result.did_hit_cache(),
      )
      Ok(1)
    }
    Err(error) => Err(ImageDecodeFailed(resource_key, error))
  }
}

///|
fn record_rgba_resource_image_replay_result(
  replay_state : RenderPipelineResourceReplayState,
  resource_key : String,
  result : Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError],
) -> Result[Int32, RenderPipelineResourceReplayError] {
  match result {
    Ok(result) => {
      replay_state.image_cache_counters.record_cached_image(
        result.did_hit_cache(),
      )
      Ok(1)
    }
    Err(error) => Err(ImageDecodeFailed(resource_key, error))
  }
}

///|
priv struct RenderPipelineTextCacheReplayCounters {
  mut keyed_text_count : Int32
  mut text_cache_hit_count : Int32
  mut text_mask_render_count : Int32
}

///|
fn RenderPipelineTextCacheReplayCounters::new() -> RenderPipelineTextCacheReplayCounters {
  { keyed_text_count: 0, text_cache_hit_count: 0, text_mask_render_count: 0, }
}

///|
fn RenderPipelineTextCacheReplayCounters::record_cached_text_mask(
  self : RenderPipelineTextCacheReplayCounters,
  did_hit_cache : Bool,
) -> Unit {
  if did_hit_cache {
    self.text_cache_hit_count += 1
  } else {
    self.text_mask_render_count += 1
  }
  self.keyed_text_count += 1
}

///|
fn RenderPipelineTextCacheReplayCounters::record_cached_text_spans(
  self : RenderPipelineTextCacheReplayCounters,
  cache_hit_count : Int32,
  render_count : Int32,
  drawn_span_count : Int32,
) -> Unit {
  self.text_cache_hit_count += cache_hit_count
  self.text_mask_render_count += render_count
  self.keyed_text_count += drawn_span_count
}

///|
priv struct RenderPipelineFontCacheReplayCounters {
  mut keyed_font_count : Int32
  mut font_cache_hit_count : Int32
  mut font_parse_count : Int32
}

///|
fn RenderPipelineFontCacheReplayCounters::new() -> RenderPipelineFontCacheReplayCounters {
  { keyed_font_count: 0, font_cache_hit_count: 0, font_parse_count: 0, }
}

///|
fn RenderPipelineFontCacheReplayCounters::record_font_lookup(
  self : RenderPipelineFontCacheReplayCounters,
  did_hit_cache : Bool,
) -> Unit {
  if did_hit_cache {
    self.font_cache_hit_count += 1
  } else {
    self.font_parse_count += 1
  }
  self.keyed_font_count += 1
}

///|
fn RenderPipelineFontCacheReplayCounters::record_font_lookups(
  self : RenderPipelineFontCacheReplayCounters,
  keyed_count : Int32,
  cache_hit_count : Int32,
  parse_count : Int32,
) -> Unit {
  self.keyed_font_count += keyed_count
  self.font_cache_hit_count += cache_hit_count
  self.font_parse_count += parse_count
}

///|
priv struct RenderPipelineAtlasCacheReplayCounters {
  mut keyed_atlas_text_count : Int32
  mut glyph_cache_hit_count : Int32
  mut glyph_mask_render_count : Int32
  mut atlas_cache_hit_count : Int32
  mut atlas_insert_count : Int32
  mut atlas_clear_count : Int32
}

///|
fn RenderPipelineAtlasCacheReplayCounters::new() -> RenderPipelineAtlasCacheReplayCounters {
  {
    keyed_atlas_text_count: 0,
    glyph_cache_hit_count: 0,
    glyph_mask_render_count: 0,
    atlas_cache_hit_count: 0,
    atlas_insert_count: 0,
    atlas_clear_count: 0,
  }
}

///|
fn RenderPipelineAtlasCacheReplayCounters::record_atlas_text(
  self : RenderPipelineAtlasCacheReplayCounters,
  glyph_cache_hit_count : Int32,
  glyph_mask_render_count : Int32,
  atlas_cache_hit_count : Int32,
  atlas_insert_count : Int32,
  did_clear_atlas : Bool,
  drawn_span_count : Int32,
) -> Unit {
  self.glyph_cache_hit_count += glyph_cache_hit_count
  self.glyph_mask_render_count += glyph_mask_render_count
  self.atlas_cache_hit_count += atlas_cache_hit_count
  self.atlas_insert_count += atlas_insert_count
  if did_clear_atlas {
    self.atlas_clear_count += 1
  }
  self.keyed_atlas_text_count += drawn_span_count
}

///|
priv struct RenderPipelineResourceReplayState {
  mut clear_count : Int32
  mut fill_count : Int32
  mut stroke_count : Int32
  mut image_count : Int32
  mut text_count : Int32
  image_cache_counters : RenderPipelineImageCacheReplayCounters
  text_cache_counters : RenderPipelineTextCacheReplayCounters
  font_cache_counters : RenderPipelineFontCacheReplayCounters
  atlas_cache_counters : RenderPipelineAtlasCacheReplayCounters
}

///|
fn RenderPipelineResourceReplayState::new() -> RenderPipelineResourceReplayState {
  {
    clear_count: 0,
    fill_count: 0,
    stroke_count: 0,
    image_count: 0,
    text_count: 0,
    image_cache_counters: RenderPipelineImageCacheReplayCounters::new(),
    text_cache_counters: RenderPipelineTextCacheReplayCounters::new(),
    font_cache_counters: RenderPipelineFontCacheReplayCounters::new(),
    atlas_cache_counters: RenderPipelineAtlasCacheReplayCounters::new(),
  }
}

///|
fn RenderPipelineResourceReplayState::to_result(
  self : RenderPipelineResourceReplayState,
  command_count : Int32,
) -> RenderPipelineResourceReplayResult {
  {
    replay_result: {
      command_count,
      clear_count: self.clear_count,
      fill_count: self.fill_count,
      stroke_count: self.stroke_count,
      image_count: self.image_count,
      text_count: self.text_count,
    },
    keyed_font_count: self.font_cache_counters.keyed_font_count,
    font_cache_hit_count: self.font_cache_counters.font_cache_hit_count,
    font_parse_count: self.font_cache_counters.font_parse_count,
    keyed_image_count: self.image_cache_counters.keyed_image_count,
    image_cache_hit_count: self.image_cache_counters.image_cache_hit_count,
    image_cache_insert_count: self.image_cache_counters.image_cache_insert_count,
    keyed_text_count: self.text_cache_counters.keyed_text_count,
    text_cache_hit_count: self.text_cache_counters.text_cache_hit_count,
    text_mask_render_count: self.text_cache_counters.text_mask_render_count,
    keyed_atlas_text_count: self.atlas_cache_counters.keyed_atlas_text_count,
    glyph_cache_hit_count: self.atlas_cache_counters.glyph_cache_hit_count,
    glyph_mask_render_count: self.atlas_cache_counters.glyph_mask_render_count,
    atlas_cache_hit_count: self.atlas_cache_counters.atlas_cache_hit_count,
    atlas_insert_count: self.atlas_cache_counters.atlas_insert_count,
    atlas_clear_count: self.atlas_cache_counters.atlas_clear_count,
  }
}
