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
      Clear(color) => {
        canvas.clear(color)
        clear_count += 1
      }
      FillRect(x, y, width, height, paint) => {
        canvas.fill_rect(x, y, width, height, paint)
        fill_count += 1
      }
      StrokeRect(x, y, width, height, paint) => {
        canvas.stroke_rect(x, y, width, height, paint)
        stroke_count += 1
      }
      FillPath(path, paint) => {
        canvas.fill_path(path, paint)
        fill_count += 1
      }
      StrokePath(path, paint) => {
        canvas.stroke_path(path, paint)
        stroke_count += 1
      }
      DrawPixmap(pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        image_count += 1
      }
      DrawPixmapKeyed(_, pixmap, x, y, paint) => {
        canvas.draw_pixmap(pixmap, x, y, paint)
        image_count += 1
      }
      DrawBmpBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_result(
            canvas,
            resource_key,
            Bmp(image_data),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawPngBytesKeyed(resource_key, image_data, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_result(
            canvas,
            resource_key,
            Png(image_data),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawSampledBmpBytesKeyed(
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
            Bmp(image_data),
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
      DrawSampledPngBytesKeyed(
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
            Png(image_data),
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
      DrawSampledRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawQualityBmpBytesKeyed(
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
            Bmp(image_data),
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
      DrawQualityBmpBytesRectKeyed(
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
            Bmp(image_data),
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
      DrawQualityPngBytesKeyed(
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
            Png(image_data),
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
      DrawQualityPngBytesRectKeyed(
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
            Png(image_data),
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
      DrawQualityRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawQualityRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawTransformedSampledBmpBytesKeyed(
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
            Bmp(image_data),
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
      DrawTransformedSampledBmpBytesRectKeyed(
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
            Bmp(image_data),
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
      DrawTransformedQualityBmpBytesKeyed(
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
            Bmp(image_data),
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
      DrawTransformedQualityBmpBytesRectKeyed(
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
            Bmp(image_data),
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
      DrawTransformedSampledPngBytesKeyed(
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
            Png(image_data),
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
      DrawTransformedSampledPngBytesRectKeyed(
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
            Png(image_data),
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
      DrawTransformedQualityPngBytesKeyed(
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
            Png(image_data),
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
      DrawTransformedQualityPngBytesRectKeyed(
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
            Png(image_data),
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
      DrawTransformedSampledRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawTransformedSampledRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawTransformedQualityRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawTransformedQualityRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawSampledBmpBytesRectKeyed(
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
            Bmp(image_data),
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
      DrawSampledPngBytesRectKeyed(
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
            Png(image_data),
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
      DrawSampledRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawBmpBytesRectKeyed(resource_key, image_data, src_rect, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_rect_result(
            canvas,
            resource_key,
            Bmp(image_data),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawPngBytesRectKeyed(resource_key, image_data, src_rect, x, y, paint) =>
        match
          render_pipeline_draw_image_bytes_rect_result(
            canvas,
            resource_key,
            Png(image_data),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
            src_rect,
            x,
            y,
            paint,
          ) {
          Ok(_) => image_count += 1
          Err(error) => return Err(error)
        }
      DrawTiledBmpBytesRectKeyed(
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
            Bmp(image_data),
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
      DrawTiledPngBytesRectKeyed(
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
            Png(image_data),
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
      DrawTiledRgbaBytesRectKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawNinePatchBmpBytesKeyed(
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
            Bmp(image_data),
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
      DrawNinePatchPngBytesKeyed(
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
            Png(image_data),
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
      DrawNinePatchRgbaBytesKeyed(
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
            Rgba(image_data, image_width, image_height),
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
      DrawPixmapRect(pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        image_count += 1
      }
      DrawPixmapRectKeyed(_, pixmap, src_rect, x, y, paint) => {
        canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
        image_count += 1
      }
      DrawTextFace(face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        text_count += 1
      }
      DrawTextFaceKeyed(_, face, text, x, y, config, paint) => {
        renderer.draw_text_face(face, text, x, y, config, paint)
        text_count += 1
      }
      DrawFontBytesKeyed(font_key, font_data, _, text, x, y, config, paint) => {
        match @text.FontFace::from_bytes(font_data) {
          Ok(face) => renderer.draw_text_face(face, text, x, y, config, paint)
          Err(error) => return Err(FontParseFailed(font_key, error))
        }
        text_count += 1
      }
      DrawFontBytesAtlasKeyed(font_key, font_data, _, text, x, y, config, paint) => {
        match @text.FontFace::from_bytes(font_data) {
          Ok(face) => renderer.draw_text_face(face, text, x, y, config, paint)
          Err(error) => return Err(FontParseFailed(font_key, error))
        }
        text_count += 1
      }
      DrawFontBytesFallbackKeyed(sources, _, text, x, y, config, paint) => {
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
      DrawFontBytesFallbackAtlasKeyed(sources, _, text, x, y, config, paint) => {
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
      DrawLoadedFontKeyed(font_key, _, _, _, _, _, _) =>
        return Err(FontLoaderRequired(font_key))
      DrawLoadedFontFallbackKeyed(font_keys, _, _, _, _, _, _) =>
        return Err(
          FontLoaderRequired(render_pipeline_first_font_key(font_keys)),
        )
      DrawLoadedFontFallbackAtlasKeyed(font_keys, _, _, _, _, _, _) =>
        return Err(
          FontLoaderRequired(render_pipeline_first_font_key(font_keys)),
        )
      DrawLoadedFontAtlasKeyed(font_key, _, _, _, _, _, _) =>
        return Err(FontLoaderRequired(font_key))
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
