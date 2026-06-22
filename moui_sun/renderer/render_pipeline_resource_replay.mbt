///|
/// Replay all queued commands through resources, preserving checked replay errors.
pub fn RenderPipeline::replay_with_renderer_resources_result(
  self : RenderPipeline,
  renderer : Renderer,
  resources : RendererResources,
) -> Result[
  RenderPipelineResourceReplayResult,
  RenderPipelineResourceReplayError,
] {
  let canvas = renderer.get_canvas()
  let replay_state = RenderPipelineResourceReplayState::new()
  for command in self.commands {
    match command {
      RenderCommand::Clear(color) => {
        canvas.clear(color)
        replay_state.clear_count += 1
      }
      RenderCommand::FillRect(x, y, width, height, paint) => {
        canvas.fill_rect(x, y, width, height, paint)
        replay_state.fill_count += 1
      }
      RenderCommand::StrokeRect(x, y, width, height, paint) => {
        canvas.stroke_rect(x, y, width, height, paint)
        replay_state.stroke_count += 1
      }
      RenderCommand::FillPath(path, paint) => {
        canvas.fill_path(path, paint)
        replay_state.fill_count += 1
      }
      RenderCommand::StrokePath(path, paint) => {
        canvas.stroke_path(path, paint)
        replay_state.stroke_count += 1
      }
      RenderCommand::DrawPixmap(pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        replay_state.image_count += 1
      }
      RenderCommand::DrawPixmapKeyed(resource_key, pixmap, x, y, paint) => {
        let result = renderer.draw_pixmap_cached_with_renderer_resources(
          pixmap, x, y, resources, resource_key, paint,
        )
        replay_state.image_cache_counters.record_cached_image(
          result.did_hit_cache(),
        )
        replay_state.image_count += 1
      }
      RenderCommand::DrawBmpBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPngBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_png_bytes_cached_with_renderer_resources(
              image_data, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, insets, resources, resource_key, paint,
              sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, insets, resources, resource_key, paint,
              sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, insets,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPixmapRect(pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        replay_state.image_count += 1
      }
      RenderCommand::DrawPixmapRectKeyed(
        resource_key,
        pixmap,
        src_rect,
        x,
        y,
        paint
      ) => {
        let result = renderer.draw_pixmap_rect_cached_with_renderer_resources(
          pixmap, src_rect, x, y, resources, resource_key, paint,
        )
        replay_state.image_cache_counters.record_cached_image(
          result.did_hit_cache(),
        )
        replay_state.image_count += 1
      }
      RenderCommand::DrawTextFace(face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        replay_state.text_count += 1
      }
      RenderCommand::DrawTextFaceKeyed(
        resource_key,
        face,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let result = renderer.draw_text_face_cached_with_renderer_resources(
          face, text, x, y, config, resources, resource_key, paint,
        )
        replay_state.text_cache_counters.record_cached_text_mask(
          result.did_hit_cache(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesKeyed(
        font_key,
        font_data,
        text_key,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_cached_with_renderer_resources(
            font_data, text, x, y, config, resources, font_key, text_key, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.text_cache_counters.record_cached_text_mask(
              result.did_hit_text_cache(),
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                font_key, error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesAtlasKeyed(
        font_key,
        font_data,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_atlas_with_renderer_resources(
            font_data, text, x, y, config, resources, font_key, glyph_key_prefix,
            paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.atlas_cache_counters.record_atlas_text(
              result.get_cache_hit_count(),
              result.get_rasterized_glyph_count(),
              result.get_atlas_hit_count(),
              result.get_atlas_inserted_count(),
              result.did_clear_atlas(),
              1,
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                font_key, error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackKeyed(
        sources,
        text_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_fallback_line_cached_with_renderer_resources(
            sources, text, x, y, config, resources, text_key_prefix, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookups(
              sources.length(),
              result.get_font_cache_hit_count(),
              result.get_parsed_font_count(),
            )
            replay_state.text_cache_counters.record_cached_text_spans(
              result.get_text_cache_hit_count(),
              result.get_rendered_mask_count(),
              result.get_drawn_span_count(),
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                render_pipeline_first_font_source_key(sources),
                error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        sources,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_fallback_line_atlas_with_renderer_resources(
            sources, text, x, y, config, resources, glyph_key_prefix, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookups(
              sources.length(),
              result.get_font_cache_hit_count(),
              result.get_parsed_font_count(),
            )
            replay_state.atlas_cache_counters.record_atlas_text(
              result.get_cache_hit_count(),
              result.get_rasterized_glyph_count(),
              result.get_atlas_hit_count(),
              result.get_atlas_inserted_count(),
              result.did_clear_atlas(),
              result.get_drawn_span_count(),
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                render_pipeline_first_font_source_key(sources),
                error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawLoadedFontKeyed(font_key, _, _, _, _, _, _) =>
        return Err(
          RenderPipelineResourceReplayError::FontLoaderRequired(font_key),
        )
      RenderCommand::DrawLoadedFontFallbackKeyed(font_keys, _, _, _, _, _, _) =>
        return Err(
          RenderPipelineResourceReplayError::FontLoaderRequired(
            render_pipeline_first_font_key(font_keys),
          ),
        )
      RenderCommand::DrawLoadedFontFallbackAtlasKeyed(
        font_keys,
        _,
        _,
        _,
        _,
        _,
        _
      ) =>
        return Err(
          RenderPipelineResourceReplayError::FontLoaderRequired(
            render_pipeline_first_font_key(font_keys),
          ),
        )
      RenderCommand::DrawLoadedFontAtlasKeyed(font_key, _, _, _, _, _, _) =>
        return Err(
          RenderPipelineResourceReplayError::FontLoaderRequired(font_key),
        )
    }
  }
  Ok(replay_state.to_result(self.commands.length()))
}

///|
fn render_pipeline_first_font_source_key(
  sources : Array[FontBytesFallbackSource],
) -> String {
  match sources.get(0) {
    Some(source) => source.get_font_key()
    None => ""
  }
}

///|
fn render_pipeline_font_load_error_to_resource_replay_error(
  error : @text.FontLoadError,
) -> RenderPipelineResourceReplayError {
  match error {
    @text.FontLoadError::MissingFontData(font_key) =>
      RenderPipelineResourceReplayError::FontDataMissing(font_key)
    @text.FontLoadError::FontFileReadFailed(font_key, path) =>
      RenderPipelineResourceReplayError::FontFileReadFailed(font_key, path)
    @text.FontLoadError::FontParseFailed(font_key, error) =>
      RenderPipelineResourceReplayError::FontParseFailed(font_key, error)
  }
}

///|
/// Replay all queued commands through resources and a font loader, preserving checked replay errors.
pub fn[L : @text.FontLoader] RenderPipeline::replay_with_font_loader_resources_result(
  self : RenderPipeline,
  renderer : Renderer,
  resources : RendererResources,
  loader : L,
) -> Result[
  RenderPipelineResourceReplayResult,
  RenderPipelineResourceReplayError,
] {
  let canvas = renderer.get_canvas()
  let replay_state = RenderPipelineResourceReplayState::new()
  for command in self.commands {
    match command {
      RenderCommand::Clear(color) => {
        canvas.clear(color)
        replay_state.clear_count += 1
      }
      RenderCommand::FillRect(x, y, width, height, paint) => {
        canvas.fill_rect(x, y, width, height, paint)
        replay_state.fill_count += 1
      }
      RenderCommand::StrokeRect(x, y, width, height, paint) => {
        canvas.stroke_rect(x, y, width, height, paint)
        replay_state.stroke_count += 1
      }
      RenderCommand::FillPath(path, paint) => {
        canvas.fill_path(path, paint)
        replay_state.fill_count += 1
      }
      RenderCommand::StrokePath(path, paint) => {
        canvas.stroke_path(path, paint)
        replay_state.stroke_count += 1
      }
      RenderCommand::DrawPixmap(pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        replay_state.image_count += 1
      }
      RenderCommand::DrawPixmapKeyed(resource_key, pixmap, x, y, paint) => {
        let result = renderer.draw_pixmap_cached_with_renderer_resources(
          pixmap, x, y, resources, resource_key, paint,
        )
        replay_state.image_cache_counters.record_cached_image(
          result.did_hit_cache(),
        )
        replay_state.image_count += 1
      }
      RenderCommand::DrawBmpBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPngBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_png_bytes_cached_with_renderer_resources(
              image_data, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_quality_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_sampled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTiledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, insets, resources, resource_key, paint,
              sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, insets, resources, resource_key, paint,
              sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawNinePatchRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_nine_patch_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, insets,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPixmapRect(pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        replay_state.image_count += 1
      }
      RenderCommand::DrawPixmapRectKeyed(
        resource_key,
        pixmap,
        src_rect,
        x,
        y,
        paint
      ) => {
        let result = renderer.draw_pixmap_rect_cached_with_renderer_resources(
          pixmap, src_rect, x, y, resources, resource_key, paint,
        )
        replay_state.image_cache_counters.record_cached_image(
          result.did_hit_cache(),
        )
        replay_state.image_count += 1
      }
      RenderCommand::DrawTextFace(face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        replay_state.text_count += 1
      }
      RenderCommand::DrawTextFaceKeyed(
        resource_key,
        face,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let result = renderer.draw_text_face_cached_with_renderer_resources(
          face, text, x, y, config, resources, resource_key, paint,
        )
        replay_state.text_cache_counters.record_cached_text_mask(
          result.did_hit_cache(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesKeyed(
        font_key,
        font_data,
        text_key,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_cached_with_renderer_resources(
            font_data, text, x, y, config, resources, font_key, text_key, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.text_cache_counters.record_cached_text_mask(
              result.did_hit_text_cache(),
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                font_key, error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesAtlasKeyed(
        font_key,
        font_data,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_font_bytes_atlas_with_renderer_resources(
            font_data, text, x, y, config, resources, font_key, glyph_key_prefix,
            paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.atlas_cache_counters.record_atlas_text(
              result.get_cache_hit_count(),
              result.get_rasterized_glyph_count(),
              result.get_atlas_hit_count(),
              result.get_atlas_inserted_count(),
              result.did_clear_atlas(),
              1,
            )
          }
          Err(error) =>
            return Err(
              RenderPipelineResourceReplayError::FontParseFailed(
                font_key, error,
              ),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackKeyed(
        sources,
        text_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let faces : Array[@text.FontFace] = []
        let mut command_font_parse_count = 0
        let mut command_font_cache_hit_count = 0
        for source in sources {
          match
            resources
            .get_font_face_cache()
            .get_or_parse_result(source.get_font_key(), source.get_font_data()) {
            Ok(parse_result) => {
              faces.push(parse_result.get_face())
              if parse_result.did_parse() {
                command_font_parse_count += 1
              } else {
                command_font_cache_hit_count += 1
              }
            }
            Err(error) =>
              return Err(
                RenderPipelineResourceReplayError::FontParseFailed(
                  source.get_font_key(),
                  error,
                ),
              )
          }
        }
        let result = renderer.draw_text_fallback_line_cached_with_renderer_resources(
          faces, text, x, y, config, resources, text_key_prefix, paint,
        )
        replay_state.font_cache_counters.record_font_lookups(
          sources.length(),
          command_font_cache_hit_count,
          command_font_parse_count,
        )
        replay_state.text_cache_counters.record_cached_text_spans(
          result.get_cache_hit_count(),
          result.get_rendered_mask_count(),
          result.get_drawn_span_count(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        sources,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let faces : Array[@text.FontFace] = []
        let mut command_font_parse_count = 0
        let mut command_font_cache_hit_count = 0
        for source in sources {
          match
            resources
            .get_font_face_cache()
            .get_or_parse_result(source.get_font_key(), source.get_font_data()) {
            Ok(parse_result) => {
              faces.push(parse_result.get_face())
              if parse_result.did_parse() {
                command_font_parse_count += 1
              } else {
                command_font_cache_hit_count += 1
              }
            }
            Err(error) =>
              return Err(
                RenderPipelineResourceReplayError::FontParseFailed(
                  source.get_font_key(),
                  error,
                ),
              )
          }
        }
        let result = renderer.draw_text_fallback_line_atlas_with_renderer_resources(
          faces, text, x, y, config, resources, glyph_key_prefix, paint,
        )
        replay_state.font_cache_counters.record_font_lookups(
          sources.length(),
          command_font_cache_hit_count,
          command_font_parse_count,
        )
        replay_state.atlas_cache_counters.record_atlas_text(
          result.get_cache_hit_count(),
          result.get_rasterized_glyph_count(),
          result.get_atlas_hit_count(),
          result.get_atlas_inserted_count(),
          result.did_clear_atlas(),
          result.get_drawn_span_count(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawTransformedSampledBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityBmpBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_bmp_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_bmp_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_bmp_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        sampling
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_sampled_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, sampling,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_rgba_bytes_cached_with_renderer_resources(
              image_data, image_width, image_height, x, y, width, height, resources,
              resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
        resource_key,
        image_data,
        image_width,
        image_height,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_rgba_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_rgba_bytes_rect_cached_with_renderer_resources(
              image_data, image_width, image_height, src_rect, x, y, width, height,
              resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityPngBytesKeyed(
        resource_key,
        image_data,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_png_bytes_cached_with_renderer_resources(
              image_data, x, y, width, height, resources, resource_key, paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
        resource_key,
        image_data,
        src_rect,
        x,
        y,
        width,
        height,
        paint,
        quality
      ) =>
        match
          record_png_resource_image_replay_result(
            replay_state,
            resource_key,
            renderer.draw_transformed_quality_png_bytes_rect_cached_with_renderer_resources(
              image_data, src_rect, x, y, width, height, resources, resource_key,
              paint, quality,
            ),
          ) {
          Ok(count) => replay_state.image_count += count
          Err(error) => return Err(error)
        }
      RenderCommand::DrawLoadedFontKeyed(
        font_key,
        text_key,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_loaded_font_cached_with_renderer_resources(
            loader, text, x, y, config, resources, font_key, text_key, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.text_cache_counters.record_cached_text_mask(
              result.did_hit_text_cache(),
            )
          }
          Err(error) =>
            return Err(
              render_pipeline_font_load_error_to_resource_replay_error(error),
            )
        }
        replay_state.text_count += 1
      }
      RenderCommand::DrawLoadedFontFallbackKeyed(
        font_keys,
        text_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let faces : Array[@text.FontFace] = []
        let mut command_font_parse_count = 0
        let mut command_font_cache_hit_count = 0
        for font_key in font_keys {
          match
            resources.get_font_face_cache().get_or_load_result(font_key, loader) {
            Ok(load_result) => {
              faces.push(load_result.get_face())
              if load_result.did_parse() {
                command_font_parse_count += 1
              } else {
                command_font_cache_hit_count += 1
              }
            }
            Err(error) =>
              return Err(
                render_pipeline_font_load_error_to_resource_replay_error(error),
              )
          }
        }
        let result = renderer.draw_text_fallback_line_cached_with_renderer_resources(
          faces, text, x, y, config, resources, text_key_prefix, paint,
        )
        replay_state.font_cache_counters.record_font_lookups(
          font_keys.length(),
          command_font_cache_hit_count,
          command_font_parse_count,
        )
        replay_state.text_cache_counters.record_cached_text_spans(
          result.get_cache_hit_count(),
          result.get_rendered_mask_count(),
          result.get_drawn_span_count(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawLoadedFontFallbackAtlasKeyed(
        font_keys,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        let faces : Array[@text.FontFace] = []
        let mut command_font_parse_count = 0
        let mut command_font_cache_hit_count = 0
        for font_key in font_keys {
          match
            resources.get_font_face_cache().get_or_load_result(font_key, loader) {
            Ok(load_result) => {
              faces.push(load_result.get_face())
              if load_result.did_parse() {
                command_font_parse_count += 1
              } else {
                command_font_cache_hit_count += 1
              }
            }
            Err(error) =>
              return Err(
                render_pipeline_font_load_error_to_resource_replay_error(error),
              )
          }
        }
        let result = renderer.draw_text_fallback_line_atlas_with_renderer_resources(
          faces, text, x, y, config, resources, glyph_key_prefix, paint,
        )
        replay_state.font_cache_counters.record_font_lookups(
          font_keys.length(),
          command_font_cache_hit_count,
          command_font_parse_count,
        )
        replay_state.atlas_cache_counters.record_atlas_text(
          result.get_cache_hit_count(),
          result.get_rasterized_glyph_count(),
          result.get_atlas_hit_count(),
          result.get_atlas_inserted_count(),
          result.did_clear_atlas(),
          result.get_drawn_span_count(),
        )
        replay_state.text_count += 1
      }
      RenderCommand::DrawLoadedFontAtlasKeyed(
        font_key,
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          renderer.draw_loaded_font_atlas_with_renderer_resources(
            loader, text, x, y, config, resources, font_key, glyph_key_prefix, paint,
          ) {
          Ok(result) => {
            replay_state.font_cache_counters.record_font_lookup(
              result.did_hit_font_cache(),
            )
            replay_state.atlas_cache_counters.record_atlas_text(
              result.get_cache_hit_count(),
              result.get_rasterized_glyph_count(),
              result.get_atlas_hit_count(),
              result.get_atlas_inserted_count(),
              result.did_clear_atlas(),
              1,
            )
          }
          Err(error) =>
            return Err(
              render_pipeline_font_load_error_to_resource_replay_error(error),
            )
        }
        replay_state.text_count += 1
      }
    }
  }
  Ok(replay_state.to_result(self.commands.length()))
}
