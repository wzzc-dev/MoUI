///|
/// Estimate the dirty region and command categories without replaying.
pub fn RenderPipeline::analyze(
  self : RenderPipeline,
  width : Int,
  height : Int,
) -> RenderPipelineAnalysis {
  let dirty_region = @graphics.DirtyRegion::new()
  let canvas_bounds = @graphics.PixelRect::new(x=0, y=0, width~, height~)
  let mut clear_count = 0
  let mut fill_count = 0
  let mut stroke_count = 0
  let mut image_count = 0
  let mut text_count = 0
  for command in self.commands {
    match render_command_batch_kind(command) {
      RenderPipelineBatchKind::Clear => clear_count += 1
      RenderPipelineBatchKind::Fill => fill_count += 1
      RenderPipelineBatchKind::Stroke => stroke_count += 1
      RenderPipelineBatchKind::Image => image_count += 1
      RenderPipelineBatchKind::Text => text_count += 1
    }
    match render_command_estimated_dirty_rect(command, width, height) {
      Some(rect) => dirty_region.add_clipped_rect(rect, canvas_bounds)
      None => ()
    }
  }
  {
    command_count: self.commands.length(),
    clear_count,
    fill_count,
    stroke_count,
    image_count,
    text_count,
    dirty_region,
  }
}

///|
/// Build a present plan from the pipeline's estimated dirty region.
pub fn RenderPipeline::dirty_present_plan(
  self : RenderPipeline,
  width : Int,
  height : Int,
  max_rects : Int,
) -> @graphics.DirtyPresentPlan {
  self.analyze(width, height).get_present_plan(width, height, max_rects)
}

///|
/// Group contiguous commands by scheduling category and estimate batch dirties.
pub fn RenderPipeline::batch_plan(
  self : RenderPipeline,
  width : Int,
  height : Int,
) -> RenderPipelineBatchPlan {
  let batches = []
  let plan_dirty_region = @graphics.DirtyRegion::new()
  let canvas_bounds = @graphics.PixelRect::new(x=0, y=0, width~, height~)
  let mut has_current_batch = false
  let mut current_kind = RenderPipelineBatchKind::Clear
  let mut current_start = 0
  let mut current_count = 0
  let mut current_dirty_region = @graphics.DirtyRegion::new()
  for index in 0..<self.commands.length() {
    let command = self.commands[index]
    let kind = render_command_batch_kind(command)
    if has_current_batch && current_kind != kind {
      batches.push(
        render_pipeline_make_batch(
          current_kind, current_start, current_count, current_dirty_region,
        ),
      )
      current_start = index
      current_count = 0
      current_dirty_region = @graphics.DirtyRegion::new()
    } else if !has_current_batch {
      has_current_batch = true
      current_start = index
      current_count = 0
      current_dirty_region = @graphics.DirtyRegion::new()
    }
    current_kind = kind
    current_count += 1
    render_pipeline_add_command_dirty(
      current_dirty_region, canvas_bounds, command, width, height,
    )
    render_pipeline_add_command_dirty(
      plan_dirty_region, canvas_bounds, command, width, height,
    )
  }
  if has_current_batch {
    batches.push(
      render_pipeline_make_batch(
        current_kind, current_start, current_count, current_dirty_region,
      ),
    )
  }
  {
    command_count: self.commands.length(),
    batches,
    dirty_region: plan_dirty_region,
  }
}

///|
/// Pre-resolve image and parsed-font text resource uses before replay.
pub fn RenderPipeline::resource_plan(
  self : RenderPipeline,
) -> RenderPipelineResourcePlan {
  let font_dependencies = []
  let image_dependencies = []
  let text_dependencies = []
  for index in 0..<self.commands.length() {
    let command = self.commands[index]
    match command {
      RenderCommand::DrawPixmap(pixmap, _, _, _) =>
        image_dependencies.push(
          render_pipeline_make_image_dependency(
            index,
            None,
            pixmap.get_width(),
            pixmap.get_height(),
          ),
        )
      RenderCommand::DrawPixmapKeyed(resource_key, pixmap, _, _, _) =>
        image_dependencies.push(
          render_pipeline_make_image_dependency(
            index,
            Some(resource_key),
            pixmap.get_width(),
            pixmap.get_height(),
          ),
        )
      RenderCommand::DrawBmpBytesKeyed(resource_key, image_data, _, _, _) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawPngBytesKeyed(resource_key, image_data, _, _, _) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawSampledBmpBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawSampledPngBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawQualityBmpBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawQualityPngBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawTransformedSampledBmpBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTransformedQualityBmpBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTransformedSampledPngBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTransformedQualityPngBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawTiledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTiledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_rect_image_dependency(
            index, resource_key, image_data, src_rect,
          ),
        )
      RenderCommand::DrawTiledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_rect_image_dependency(
            index, resource_key, image_data, image_width, image_height, src_rect,
          ),
        )
      RenderCommand::DrawNinePatchBmpBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_bmp_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawNinePatchPngBytesKeyed(
        resource_key,
        image_data,
        _,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_png_bytes_image_dependency(
            index, resource_key, image_data,
          ),
        )
      RenderCommand::DrawNinePatchRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        _,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rgba_bytes_image_dependency(
            index, resource_key, image_data, image_width, image_height,
          ),
        )
      RenderCommand::DrawPixmapRect(pixmap, src_rect, _, _, _) =>
        image_dependencies.push(
          render_pipeline_make_rect_image_dependency(
            index,
            None,
            pixmap,
            src_rect,
          ),
        )
      RenderCommand::DrawPixmapRectKeyed(
        resource_key,
        pixmap,
        src_rect,
        _,
        _,
        _
      ) =>
        image_dependencies.push(
          render_pipeline_make_rect_image_dependency(
            index,
            Some(resource_key),
            pixmap,
            src_rect,
          ),
        )
      RenderCommand::DrawTextFace(face, text, _, _, config, _) =>
        text_dependencies.push(
          render_pipeline_make_text_dependency(index, None, face, text, config),
        )
      RenderCommand::DrawTextFaceKeyed(
        resource_key,
        face,
        text,
        _,
        _,
        config,
        _
      ) =>
        text_dependencies.push(
          render_pipeline_make_text_dependency(
            index,
            Some(resource_key),
            face,
            text,
            config,
          ),
        )
      RenderCommand::DrawFontBytesKeyed(
        font_key,
        font_data,
        text_key,
        text,
        _,
        _,
        config,
        _
      ) => {
        font_dependencies.push(
          render_pipeline_make_font_dependency(index, font_key, font_data),
        )
        text_dependencies.push(
          render_pipeline_make_font_bytes_text_dependency(
            index, text_key, font_data, text, config,
          ),
        )
      }
      RenderCommand::DrawFontBytesAtlasKeyed(
        font_key,
        font_data,
        glyph_key_prefix,
        text,
        _,
        _,
        config,
        _
      ) => {
        font_dependencies.push(
          render_pipeline_make_font_dependency(index, font_key, font_data),
        )
        text_dependencies.push(
          render_pipeline_make_font_bytes_text_dependency(
            index, glyph_key_prefix, font_data, text, config,
          ),
        )
      }
      RenderCommand::DrawFontBytesFallbackKeyed(
        sources,
        text_key_prefix,
        text,
        _,
        _,
        _,
        _
      ) => {
        for source in sources {
          font_dependencies.push(
            render_pipeline_make_font_dependency(
              index,
              source.get_font_key(),
              source.get_font_data(),
            ),
          )
        }
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(text_key_prefix),
            text,
          ),
        )
      }
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        sources,
        glyph_key_prefix,
        text,
        _,
        _,
        _,
        _
      ) => {
        for source in sources {
          font_dependencies.push(
            render_pipeline_make_font_dependency(
              index,
              source.get_font_key(),
              source.get_font_data(),
            ),
          )
        }
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(glyph_key_prefix),
            text,
          ),
        )
      }
      RenderCommand::DrawLoadedFontKeyed(font_key, text_key, text, _, _, _, _) => {
        font_dependencies.push(
          render_pipeline_make_loaded_font_dependency(index, font_key),
        )
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(text_key),
            text,
          ),
        )
      }
      RenderCommand::DrawLoadedFontFallbackKeyed(
        font_keys,
        text_key_prefix,
        text,
        _,
        _,
        _,
        _
      ) => {
        for font_key in font_keys {
          font_dependencies.push(
            render_pipeline_make_loaded_font_dependency(index, font_key),
          )
        }
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(text_key_prefix),
            text,
          ),
        )
      }
      RenderCommand::DrawLoadedFontFallbackAtlasKeyed(
        font_keys,
        glyph_key_prefix,
        text,
        _,
        _,
        _,
        _
      ) => {
        for font_key in font_keys {
          font_dependencies.push(
            render_pipeline_make_loaded_font_dependency(index, font_key),
          )
        }
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(glyph_key_prefix),
            text,
          ),
        )
      }
      RenderCommand::DrawLoadedFontAtlasKeyed(
        font_key,
        glyph_key_prefix,
        text,
        _,
        _,
        _,
        _
      ) => {
        font_dependencies.push(
          render_pipeline_make_loaded_font_dependency(index, font_key),
        )
        text_dependencies.push(
          render_pipeline_make_unresolved_text_dependency(
            index,
            Some(glyph_key_prefix),
            text,
          ),
        )
      }
      _ => ()
    }
  }
  {
    command_count: self.commands.length(),
    font_dependencies,
    image_dependencies,
    text_dependencies,
  }
}
