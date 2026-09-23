///|
fn render_point_image_commands_are_same(
  a : RenderCommand,
  b : RenderCommand,
) -> Bool? {
  match (a, b) {
    // Unkeyed pixmap commands depend on mutable/external resources.
    // Treat them as changed unless a stable key can prove identity.
    (DrawPixmap(_, _, _, _), DrawPixmap(_, _, _, _)) => Some(false)
    (
      DrawPixmapKeyed(a_key, _, ax, ay, a_paint),
      DrawPixmapKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      DrawBmpBytesKeyed(a_key, _, ax, ay, a_paint),
      DrawBmpBytesKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      DrawPngBytesKeyed(a_key, _, ax, ay, a_paint),
      DrawPngBytesKeyed(b_key, _, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_point_is_same(
          a_key, b_key, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      DrawRgbaBytesKeyed(a_key, _, a_width, a_height, ax, ay, a_paint),
      DrawRgbaBytesKeyed(b_key, _, b_width, b_height, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_dimensions_point_is_same(
          a_key, b_key, a_width, a_height, b_width, b_height, ax, ay, bx, by, a_paint,
          b_paint,
        ),
      )
    (
      DrawBmpBytesRectKeyed(a_key, _, a_src, ax, ay, a_paint),
      DrawBmpBytesRectKeyed(b_key, _, b_src, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_source_point_is_same(
          a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      DrawPngBytesRectKeyed(a_key, _, a_src, ax, ay, a_paint),
      DrawPngBytesRectKeyed(b_key, _, b_src, bx, by, b_paint),
    ) =>
      Some(
        render_keyed_image_source_point_is_same(
          a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
        ),
      )
    (
      DrawRgbaBytesRectKeyed(
        a_key,
        _,
        a_width,
        a_height,
        a_src,
        ax,
        ay,
        a_paint
      ),
      DrawRgbaBytesRectKeyed(
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
      DrawSampledBmpBytesKeyed(a_key, _, ax, ay, aw, ah, a_paint, a_sampling),
      DrawSampledBmpBytesKeyed(b_key, _, bx, by, bw, bh, b_paint, b_sampling),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      DrawSampledPngBytesKeyed(a_key, _, ax, ay, aw, ah, a_paint, a_sampling),
      DrawSampledPngBytesKeyed(b_key, _, bx, by, bw, bh, b_paint, b_sampling),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_sampling == b_sampling,
      )
    (
      DrawSampledRgbaBytesKeyed(
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
      DrawSampledRgbaBytesKeyed(
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
      DrawSampledBmpBytesRectKeyed(
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
      DrawSampledBmpBytesRectKeyed(
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
      DrawSampledPngBytesRectKeyed(
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
      DrawSampledPngBytesRectKeyed(
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
      DrawSampledRgbaBytesRectKeyed(
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
      DrawSampledRgbaBytesRectKeyed(
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
      DrawQualityBmpBytesKeyed(a_key, _, ax, ay, aw, ah, a_paint, a_quality),
      DrawQualityBmpBytesKeyed(b_key, _, bx, by, bw, bh, b_paint, b_quality),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      DrawQualityBmpBytesRectKeyed(
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
      DrawQualityBmpBytesRectKeyed(
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
      DrawQualityPngBytesKeyed(a_key, _, ax, ay, aw, ah, a_paint, a_quality),
      DrawQualityPngBytesKeyed(b_key, _, bx, by, bw, bh, b_paint, b_quality),
    ) =>
      Some(
        render_keyed_image_rect_is_same(
          a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ) &&
        a_quality == b_quality,
      )
    (
      DrawQualityPngBytesRectKeyed(
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
      DrawQualityPngBytesRectKeyed(
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
      DrawQualityRgbaBytesKeyed(
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
      DrawQualityRgbaBytesKeyed(
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
      DrawQualityRgbaBytesRectKeyed(
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
      DrawQualityRgbaBytesRectKeyed(
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
      DrawTransformedSampledBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      DrawTransformedSampledBmpBytesKeyed(
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
      DrawTransformedSampledBmpBytesRectKeyed(
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
      DrawTransformedSampledBmpBytesRectKeyed(
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
      DrawTransformedSampledPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_sampling
      ),
      DrawTransformedSampledPngBytesKeyed(
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
      DrawTransformedSampledPngBytesRectKeyed(
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
      DrawTransformedSampledPngBytesRectKeyed(
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
      DrawTransformedSampledRgbaBytesKeyed(
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
      DrawTransformedSampledRgbaBytesKeyed(
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
      DrawTransformedSampledRgbaBytesRectKeyed(
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
      DrawTransformedSampledRgbaBytesRectKeyed(
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
      DrawTransformedQualityBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      DrawTransformedQualityBmpBytesKeyed(
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
      DrawTransformedQualityBmpBytesRectKeyed(
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
      DrawTransformedQualityBmpBytesRectKeyed(
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
      DrawTransformedQualityPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_paint,
        a_quality
      ),
      DrawTransformedQualityPngBytesKeyed(
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
      DrawTransformedQualityPngBytesRectKeyed(
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
      DrawTransformedQualityPngBytesRectKeyed(
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
      DrawTransformedQualityRgbaBytesKeyed(
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
      DrawTransformedQualityRgbaBytesKeyed(
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
      DrawTransformedQualityRgbaBytesRectKeyed(
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
      DrawTransformedQualityRgbaBytesRectKeyed(
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
      DrawTiledBmpBytesRectKeyed(a_key, _, a_src, ax, ay, aw, ah, a_paint),
      DrawTiledBmpBytesRectKeyed(b_key, _, b_src, bx, by, bw, bh, b_paint),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ),
      )
    (
      DrawTiledPngBytesRectKeyed(a_key, _, a_src, ax, ay, aw, ah, a_paint),
      DrawTiledPngBytesRectKeyed(b_key, _, b_src, bx, by, bw, bh, b_paint),
    ) =>
      Some(
        render_keyed_image_source_rect_is_same(
          a_key, b_key, a_src, b_src, ax, ay, aw, ah, bx, by, bw, bh, a_paint, b_paint,
        ),
      )
    (
      DrawTiledRgbaBytesRectKeyed(
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
      DrawTiledRgbaBytesRectKeyed(
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
