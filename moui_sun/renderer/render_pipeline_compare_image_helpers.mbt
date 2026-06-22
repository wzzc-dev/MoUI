///|
fn render_point_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    // Unkeyed pixmap commands depend on mutable/external resources.
    // Treat them as changed unless a stable key can prove identity.
    (
      RenderCommand::DrawPixmap(_, _, _, _),
      RenderCommand::DrawPixmap(_, _, _, _),
    ) => Some(false)
    (
      RenderCommand::DrawPixmapKeyed(a_key, _, ax, ay, a_paint),
      RenderCommand::DrawPixmapKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawBmpBytesKeyed(a_key, _, ax, ay, a_paint),
      RenderCommand::DrawBmpBytesKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawPngBytesKeyed(a_key, _, ax, ay, a_paint),
      RenderCommand::DrawPngBytesKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawRgbaBytesKeyed(
        a_key,
        _,
        a_width,
        a_height,
        ax,
        ay,
        a_paint
      ),
      RenderCommand::DrawRgbaBytesKeyed(
        b_key,
        _,
        b_width,
        b_height,
        bx,
        by,
        b_paint
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_point_is_same(
          a_key, b_key, a_width, a_height, b_width, b_height, ax, ay, bx, by, a_paint,
          b_paint,
        ),
      )
    (
      RenderCommand::DrawBmpBytesRectKeyed(a_key, _, a_src, ax, ay, a_paint),
      RenderCommand::DrawBmpBytesRectKeyed(b_key, _, b_src, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_source_point_is_same(
          a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawPngBytesRectKeyed(a_key, _, a_src, ax, ay, a_paint),
      RenderCommand::DrawPngBytesRectKeyed(b_key, _, b_src, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_source_point_is_same(
          a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawRgbaBytesRectKeyed(
        a_key,
        _,
        a_width,
        a_height,
        a_src,
        ax,
        ay,
        a_paint
      ),
      RenderCommand::DrawRgbaBytesRectKeyed(
        b_key,
        _,
        b_width,
        b_height,
        b_src,
        bx,
        by,
        b_paint
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_source_point_is_same(
          a_key, b_key, a_width, a_height, b_width, b_height, a_src, b_src, ax, ay,
          bx, by, a_paint, b_paint,
        ),
      )
    _ => None
  }
}

///|
fn render_sampled_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    (
      RenderCommand::DrawSampledBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledBmpBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawSampledPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledPngBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawSampledRgbaBytesKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledRgbaBytesKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawSampledBmpBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledBmpBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawSampledPngBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledPngBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawSampledRgbaBytesRectKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawSampledRgbaBytesRectKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_source_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    _ => None
  }
}

///|
fn render_quality_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    (
      RenderCommand::DrawQualityBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityBmpBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawQualityBmpBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityBmpBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawQualityPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityPngBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawQualityPngBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityPngBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawQualityRgbaBytesKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityRgbaBytesKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawQualityRgbaBytesRectKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawQualityRgbaBytesRectKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_source_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    _ => None
  }
}

///|
fn render_transformed_sampled_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    (
      RenderCommand::DrawTransformedSampledBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledBmpBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawTransformedSampledPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledPngBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_dimensions_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_sampling
      ),
    ) =>
      Some(
        render_keyed_transformed_image_dimensions_source_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    _ => None
  }
}

///|
fn render_transformed_quality_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    (
      RenderCommand::DrawTransformedQualityBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityBmpBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawTransformedQualityPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityPngBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_dimensions_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint,
        b_quality
      ),
    ) =>
      Some(
        render_keyed_transformed_image_dimensions_source_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    _ => None
  }
}

///|
fn render_tiled_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    (
      RenderCommand::DrawTiledBmpBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint
      ),
      RenderCommand::DrawTiledBmpBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawTiledPngBytesRectKeyed(
        a_key,
        _,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint
      ),
      RenderCommand::DrawTiledPngBytesRectKeyed(
        b_key,
        _,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint
      ),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ),
      )
    (
      RenderCommand::DrawTiledRgbaBytesRectKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        a_src,
        ax,
        ay,
        aw,
        ah,
        a_paint
      ),
      RenderCommand::DrawTiledRgbaBytesRectKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        b_src,
        bx,
        by,
        bw,
        bh,
        b_paint
      ),
    ) =>
      Some(
        render_keyed_image_dimensions_source_rect_is_same(
          a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
          a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ),
      )
    _ => None
  }
}

///|
fn render_keyed_image_point_is_same(
  a_key : String,
  b_key : String,
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_key == b_key &&
  ax == bx &&
  ay == by &&
  render_paint_is_same(a_paint, b_paint)
}

///|
fn render_keyed_image_rect_is_same(
  a_key : String,
  b_key : String,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_key == b_key &&
  ax == bx &&
  ay == by &&
  aw == bw &&
  ah == bh &&
  render_paint_is_same(a_paint, b_paint)
}

///|
fn render_keyed_image_dimensions_point_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_image_point_is_same(
    a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
  )
}

///|
fn render_keyed_image_dimensions_rect_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_image_rect_is_same(
    a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_image_source_point_is_same(
  a_key : String,
  b_key : String,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_src == b_src &&
  render_keyed_image_point_is_same(
    a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
  )
}

///|
fn render_keyed_image_source_rect_is_same(
  a_key : String,
  b_key : String,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_src == b_src &&
  render_keyed_image_rect_is_same(
    a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_image_dimensions_source_point_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_image_source_point_is_same(
    a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
  )
}

///|
fn render_keyed_image_dimensions_source_rect_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_image_source_rect_is_same(
    a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_transformed_image_rect_is_same(
  a_key : String,
  b_key : String,
  ax : Double,
  ay : Double,
  aw : Double,
  ah : Double,
  bx : Double,
  by : Double,
  bw : Double,
  bh : Double,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_key == b_key &&
  ax == bx &&
  ay == by &&
  aw == bw &&
  ah == bh &&
  render_paint_is_same(a_paint, b_paint)
}

///|
fn render_keyed_transformed_image_source_rect_is_same(
  a_key : String,
  b_key : String,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Double,
  ay : Double,
  aw : Double,
  ah : Double,
  bx : Double,
  by : Double,
  bw : Double,
  bh : Double,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_src == b_src &&
  render_keyed_transformed_image_rect_is_same(
    a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_transformed_image_dimensions_rect_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  ax : Double,
  ay : Double,
  aw : Double,
  ah : Double,
  bx : Double,
  by : Double,
  bw : Double,
  bh : Double,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_transformed_image_rect_is_same(
    a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_transformed_image_dimensions_source_rect_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  a_src : @graphics.PixelRect,
  b_src : @graphics.PixelRect,
  ax : Double,
  ay : Double,
  aw : Double,
  ah : Double,
  bx : Double,
  by : Double,
  bw : Double,
  bh : Double,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
) -> Bool {
  a_width == b_width &&
  a_height == b_height &&
  render_keyed_transformed_image_source_rect_is_same(
    a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  )
}

///|
fn render_keyed_nine_patch_image_is_same(
  a_key : String,
  b_key : String,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_insets : @graphics.NinePatchInsets,
  b_insets : @graphics.NinePatchInsets,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
  a_sampling : @graphics.ImageSampling,
  b_sampling : @graphics.ImageSampling,
) -> Bool {
  render_keyed_image_rect_is_same(
    a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
  ) &&
  a_insets == b_insets &&
  a_sampling == b_sampling
}

///|
fn render_keyed_nine_patch_image_dimensions_is_same(
  a_key : String,
  b_key : String,
  a_width : Int,
  a_height : Int,
  b_width : Int,
  b_height : Int,
  ax : Int,
  ay : Int,
  aw : Int,
  ah : Int,
  bx : Int,
  by : Int,
  bw : Int,
  bh : Int,
  a_insets : @graphics.NinePatchInsets,
  b_insets : @graphics.NinePatchInsets,
  a_paint : @graphics.Paint,
  b_paint : @graphics.Paint,
  a_sampling : @graphics.ImageSampling,
  b_sampling : @graphics.ImageSampling,
) -> Bool {
  render_keyed_image_dimensions_rect_is_same(
    a_key, b_key, a_width, a_height, b_width, b_height, ax, ay, aw, ah, bx, by, bw,
    bh, a_paint, b_paint,
  ) &&
  a_insets == b_insets &&
  a_sampling == b_sampling
}
