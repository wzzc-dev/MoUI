///|
fn render_pipeline_add_command_dirty(
  dirty_region : @graphics.DirtyRegion,
  canvas_bounds : @graphics.PixelRect,
  command : RenderCommand,
  width : Int,
  height : Int,
) -> Unit {
  match render_command_estimated_dirty_rect(command, width, height) {
    Some(rect) => dirty_region.add_clipped_rect(rect, canvas_bounds)
    None => ()
  }
}

///|
fn render_pipeline_make_batch(
  kind : RenderPipelineBatchKind,
  start_index : Int,
  command_count : Int,
  dirty_region : @graphics.DirtyRegion,
) -> RenderPipelineBatch {
  { kind, start_index, command_count, dirty_region }
}

///|
fn render_command_batch_kind(
  command : RenderCommand,
) -> RenderPipelineBatchKind {
  match command {
    RenderCommand::Clear(_) => RenderPipelineBatchKind::Clear
    RenderCommand::FillRect(_, _, _, _, _) | RenderCommand::FillPath(_, _) =>
      RenderPipelineBatchKind::Fill
    RenderCommand::StrokeRect(_, _, _, _, _)
    | RenderCommand::StrokePath(_, _) => RenderPipelineBatchKind::Stroke
    RenderCommand::DrawPixmap(_, _, _, _)
    | RenderCommand::DrawPixmapKeyed(_, _, _, _, _)
    | RenderCommand::DrawBmpBytesKeyed(_, _, _, _, _)
    | RenderCommand::DrawPngBytesKeyed(_, _, _, _, _)
    | RenderCommand::DrawRgbaBytesKeyed(_, _, _, _, _, _, _)
    | RenderCommand::DrawSampledBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawSampledPngBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawSampledRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityPngBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawQualityRgbaBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedSampledBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedQualityBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedSampledPngBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedQualityPngBytesKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawSampledBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawSampledPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawSampledRgbaBytesRectKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawBmpBytesRectKeyed(_, _, _, _, _, _)
    | RenderCommand::DrawPngBytesRectKeyed(_, _, _, _, _, _)
    | RenderCommand::DrawRgbaBytesRectKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTiledBmpBytesRectKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTiledPngBytesRectKeyed(_, _, _, _, _, _, _, _)
    | RenderCommand::DrawTiledRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawNinePatchBmpBytesKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawNinePatchPngBytesKeyed(_, _, _, _, _, _, _, _, _)
    | RenderCommand::DrawNinePatchRgbaBytesKeyed(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | RenderCommand::DrawPixmapRect(_, _, _, _, _)
    | RenderCommand::DrawPixmapRectKeyed(_, _, _, _, _, _) =>
      RenderPipelineBatchKind::Image
    RenderCommand::DrawTextFace(_, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawTextFaceKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawFontBytesKeyed(_, _, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawFontBytesAtlasKeyed(_, _, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawFontBytesFallbackKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawFontBytesFallbackAtlasKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawLoadedFontKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawLoadedFontFallbackKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawLoadedFontFallbackAtlasKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
    RenderCommand::DrawLoadedFontAtlasKeyed(_, _, _, _, _, _, _) =>
      RenderPipelineBatchKind::Text
  }
}
