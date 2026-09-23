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
  { kind, start_index, command_count, dirty_region, }
}

///|
fn render_command_batch_kind(
  command : RenderCommand,
) -> RenderPipelineBatchKind {
  match command {
    Clear(_) => Clear
    FillRect(_, _, _, _, _) | FillPath(_, _) => Fill
    StrokeRect(_, _, _, _, _) | StrokePath(_, _) => Stroke
    DrawPixmap(_, _, _, _)
    | DrawPixmapKeyed(_, _, _, _, _)
    | DrawBmpBytesKeyed(_, _, _, _, _)
    | DrawPngBytesKeyed(_, _, _, _, _)
    | DrawRgbaBytesKeyed(_, _, _, _, _, _, _)
    | DrawSampledBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawSampledPngBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawSampledRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | DrawQualityBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawQualityBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawQualityPngBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawQualityPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawQualityRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | DrawQualityRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _, _)
    | DrawTransformedSampledBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawTransformedSampledBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawTransformedQualityBmpBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawTransformedQualityBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawTransformedSampledPngBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawTransformedSampledPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawTransformedQualityPngBytesKeyed(_, _, _, _, _, _, _, _)
    | DrawTransformedQualityPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawTransformedSampledRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | DrawTransformedSampledRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _, _)
    | DrawTransformedQualityRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _)
    | DrawTransformedQualityRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _, _)
    | DrawSampledBmpBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawSampledPngBytesRectKeyed(_, _, _, _, _, _, _, _, _)
    | DrawSampledRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _, _)
    | DrawBmpBytesRectKeyed(_, _, _, _, _, _)
    | DrawPngBytesRectKeyed(_, _, _, _, _, _)
    | DrawRgbaBytesRectKeyed(_, _, _, _, _, _, _, _)
    | DrawTiledBmpBytesRectKeyed(_, _, _, _, _, _, _, _)
    | DrawTiledPngBytesRectKeyed(_, _, _, _, _, _, _, _)
    | DrawTiledRgbaBytesRectKeyed(_, _, _, _, _, _, _, _, _, _)
    | DrawNinePatchBmpBytesKeyed(_, _, _, _, _, _, _, _, _)
    | DrawNinePatchPngBytesKeyed(_, _, _, _, _, _, _, _, _)
    | DrawNinePatchRgbaBytesKeyed(_, _, _, _, _, _, _, _, _, _, _)
    | DrawPixmapRect(_, _, _, _, _)
    | DrawPixmapRectKeyed(_, _, _, _, _, _) => Image
    DrawTextFace(_, _, _, _, _, _) => Text
    DrawTextFaceKeyed(_, _, _, _, _, _, _) => Text
    DrawFontBytesKeyed(_, _, _, _, _, _, _, _) => Text
    DrawFontBytesAtlasKeyed(_, _, _, _, _, _, _, _) => Text
    DrawFontBytesFallbackKeyed(_, _, _, _, _, _, _) => Text
    DrawFontBytesFallbackAtlasKeyed(_, _, _, _, _, _, _) => Text
    DrawLoadedFontKeyed(_, _, _, _, _, _, _) => Text
    DrawLoadedFontFallbackKeyed(_, _, _, _, _, _, _) => Text
    DrawLoadedFontFallbackAtlasKeyed(_, _, _, _, _, _, _) => Text
    DrawLoadedFontAtlasKeyed(_, _, _, _, _, _, _) => Text
  }
}
