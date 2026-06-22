///|
/// Replay all queued commands through a renderer, preserving checked replay errors.
pub fn RenderPipeline::replay_result(
  self : RenderPipeline,
  renderer : Renderer,
) -> Result[RenderPipelineReplayResult, RenderPipelineReplayError] {
  let canvas = renderer.get_canvas()
  let mut clear_count = 0
  let mut fill_count = 0
  let mut stroke_count = 0
  let mut image_count = 0
  let mut text_count = 0
  for command in self.commands {
    match command {
      RenderCommand::Clear(color) => {
        canvas.clear(color)
        clear_count += 1
      }
      RenderCommand::FillRect(x, y, width, height, paint) => {
        canvas.fill_rect(x, y, width, height, paint)
        fill_count += 1
      }
      RenderCommand::StrokeRect(x, y, width, height, paint) => {
        canvas.stroke_rect(x, y, width, height, paint)
        stroke_count += 1
      }
      RenderCommand::FillPath(path, paint) => {
        canvas.fill_path(path, paint)
        fill_count += 1
      }
      RenderCommand::StrokePath(path, paint) => {
        canvas.stroke_path(path, paint)
        stroke_count += 1
      }
      RenderCommand::DrawPixmap(pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        image_count += 1
      }
      RenderCommand::DrawPixmapKeyed(_, pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        image_count += 1
      }
      RenderCommand::DrawBmpBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPngBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_transformed_quality_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            quality,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_sampled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_tiled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_tiled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_tiled_image_bytes_rect_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            src_rect,
            x,
            y,
            width,
            height,
            paint,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_nine_patch_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Bmp(image_data),
            x,
            y,
            width,
            height,
            insets,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_nine_patch_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Png(image_data),
            x,
            y,
            width,
            height,
            insets,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
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
          render_pipeline_draw_nine_patch_image_bytes_result(
            canvas,
            resource_key,
            RenderPipelineImageBytes::Rgba(
              image_data, image_width, image_height,
            ),
            x,
            y,
            width,
            height,
            insets,
            paint,
            sampling,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      RenderCommand::DrawPixmapRect(pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        image_count += 1
      }
      RenderCommand::DrawPixmapRectKeyed(_, pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        image_count += 1
      }
      RenderCommand::DrawTextFace(face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        text_count += 1
      }
      RenderCommand::DrawTextFaceKeyed(_, face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        text_count += 1
      }
      RenderCommand::DrawFontBytesKeyed(
        font_key,
        font_data,
        _,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match @text.FontFace::from_bytes(font_data) {
          Ok(face) => renderer.draw_text_face(face, text, x, y, config, paint)
          Err(error) =>
            return Err(
              RenderPipelineReplayError::FontParseFailed(font_key, error),
            )
        }
        text_count += 1
      }
      RenderCommand::DrawFontBytesAtlasKeyed(
        font_key,
        font_data,
        _,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match @text.FontFace::from_bytes(font_data) {
          Ok(face) => renderer.draw_text_face(face, text, x, y, config, paint)
          Err(error) =>
            return Err(
              RenderPipelineReplayError::FontParseFailed(font_key, error),
            )
        }
        text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackKeyed(
        sources,
        _,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          render_pipeline_parse_font_bytes_fallback_sources_result(sources) {
          Ok(faces) =>
            ignore(
              renderer.draw_text_fallback_line(faces, text, x, y, config, paint),
            )
          Err(error) => return Err(error)
        }
        text_count += 1
      }
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        sources,
        _,
        text,
        x,
        y,
        config,
        paint
      ) => {
        match
          render_pipeline_parse_font_bytes_fallback_sources_result(sources) {
          Ok(faces) =>
            ignore(
              renderer.draw_text_fallback_line(faces, text, x, y, config, paint),
            )
          Err(error) => return Err(error)
        }
        text_count += 1
      }
      RenderCommand::DrawLoadedFontKeyed(font_key, _, _, _, _, _, _) =>
        return Err(RenderPipelineReplayError::FontLoaderRequired(font_key))
      RenderCommand::DrawLoadedFontFallbackKeyed(font_keys, _, _, _, _, _, _) =>
        return Err(
          RenderPipelineReplayError::FontLoaderRequired(
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
          RenderPipelineReplayError::FontLoaderRequired(
            render_pipeline_first_font_key(font_keys),
          ),
        )
      RenderCommand::DrawLoadedFontAtlasKeyed(font_key, _, _, _, _, _, _) =>
        return Err(RenderPipelineReplayError::FontLoaderRequired(font_key))
    }
  }
  Ok({
    command_count: self.commands.length(),
    clear_count,
    fill_count,
    stroke_count,
    image_count,
    text_count,
  })
}
