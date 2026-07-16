///|
fn WebGpuLayerCommandCache::new() -> WebGpuLayerCommandCache {
  { entries: [], tick: 0 }
}

///|
fn WebGpuLayerCommandCache::expand_frame_commands(
  self : WebGpuLayerCommandCache,
  commands : Array[@core.DrawCommand],
) -> WebGpuLayerCommandExpansion {
  self.tick = self.tick + 1
  let output : Array[@core.DrawCommand] = []
  let captures : Array[WebGpuLayerCommandCapture] = []
  let missing : Array[String] = []
  let mut hits = 0
  let mut misses = 0
  let mut updates = 0
  for command in commands {
    match command {
      @core.DrawCommand::BeginCachedLayer(spec) => {
        let layer = @core.DrawCommand::PushLayer(
          @core.LayerSpec::new(
            mask=@core.LayerMask::RectMask(spec.frame),
            offscreen=true,
          ),
        )
        append_webgpu_layer_cache_command(output, captures, layer)
        captures.push({ spec, commands: [layer] })
      }
      @core.DrawCommand::EndCachedLayer(key) => {
        append_webgpu_layer_cache_command(
          output,
          captures,
          @core.DrawCommand::PopLayer,
        )
        match captures.pop() {
          Some(capture) =>
            if capture.spec.key == key {
              // Store in local coordinates relative to the capture frame so a
              // later DrawCachedLayer can re-place the same content at a new
              // origin (scroll/move) without replaying stale absolute frames.
              let origin = capture.spec.frame.origin
              let local_commands = capture.commands.map(command => {
                webgpu_offset_draw_command(command, dx=-origin.x, dy=-origin.y)
              })
              self.store(capture.spec.key, local_commands)
              updates = updates + 1
            }
          None => ()
        }
      }
      @core.DrawCommand::DrawCachedLayer(spec) =>
        match self.lookup(spec.key) {
          Some(cached) => {
            hits = hits + 1
            let origin = spec.frame.origin
            for cached_command in cached {
              append_webgpu_layer_cache_command(
                output,
                captures,
                webgpu_offset_draw_command(
                  cached_command,
                  dx=origin.x,
                  dy=origin.y,
                ),
              )
            }
          }
          None => {
            misses = misses + 1
            missing.push(spec.key)
          }
        }
      _ => append_webgpu_layer_cache_command(output, captures, command)
    }
  }
  {
    commands: output,
    cache_hit_count: hits,
    cache_miss_count: misses,
    cache_update_count: updates,
    missing_layer_keys: missing,
  }
}

///|
fn append_webgpu_layer_cache_command(
  output : Array[@core.DrawCommand],
  captures : Array[WebGpuLayerCommandCapture],
  command : @core.DrawCommand,
) -> Unit {
  output.push(command)
  for capture in captures {
    capture.commands.push(command)
  }
}

///|
fn WebGpuLayerCommandCache::lookup(
  self : WebGpuLayerCommandCache,
  key : String,
) -> Array[@core.DrawCommand]? {
  for entry in self.entries {
    if entry.key == key {
      return Some(entry.commands)
    }
  }
  None
}

///|
fn WebGpuLayerCommandCache::store(
  self : WebGpuLayerCommandCache,
  key : String,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.commands.clear()
      entry.commands.append(commands)
      return ()
    }
  }
  self.entries.push({ key, commands })
}

///|
/// Translate absolute draw geometry by `(dx, dy)`. Used to convert a cached
/// layer into local coordinates for storage and back into paint coordinates
/// when replaying at a new frame origin.
fn webgpu_offset_draw_command(
  command : @core.DrawCommand,
  dx~ : Double,
  dy~ : Double,
) -> @core.DrawCommand {
  if dx == 0.0 && dy == 0.0 {
    return command
  }
  match command {
    @core.DrawCommand::Clear(_)
    | @core.DrawCommand::PopClip
    | @core.DrawCommand::PopRoundedClip
    | @core.DrawCommand::PopTransform
    | @core.DrawCommand::PopOpacity
    | @core.DrawCommand::PopLayer
    | @core.DrawCommand::EndCachedLayer(_)
    | @core.DrawCommand::PopFilter
    | @core.DrawCommand::PushOpacity(_)
    | @core.DrawCommand::PushFilter(_) => command
    @core.DrawCommand::FillRect(rect, color) =>
      @core.DrawCommand::FillRect(webgpu_offset_rect(rect, dx~, dy~), color)
    @core.DrawCommand::StrokeRect(rect, color, width) =>
      @core.DrawCommand::StrokeRect(
        webgpu_offset_rect(rect, dx~, dy~),
        color,
        width,
      )
    @core.DrawCommand::FillRoundedRect(rect, color) =>
      @core.DrawCommand::FillRoundedRect(
        webgpu_offset_rounded_rect(rect, dx~, dy~),
        color,
      )
    @core.DrawCommand::StrokeRoundedRect(rect, color, width) =>
      @core.DrawCommand::StrokeRoundedRect(
        webgpu_offset_rounded_rect(rect, dx~, dy~),
        color,
        width,
      )
    @core.DrawCommand::FillRoundedRectBrush(rect, brush) =>
      @core.DrawCommand::FillRoundedRectBrush(
        webgpu_offset_rounded_rect(rect, dx~, dy~),
        webgpu_offset_brush(brush, dx~, dy~),
      )
    @core.DrawCommand::StrokeRoundedRectBrush(rect, brush, width) =>
      @core.DrawCommand::StrokeRoundedRectBrush(
        webgpu_offset_rounded_rect(rect, dx~, dy~),
        webgpu_offset_brush(brush, dx~, dy~),
        width,
      )
    @core.DrawCommand::DrawShadow(shadow) =>
      @core.DrawCommand::DrawShadow({
        ..shadow,
        rect: webgpu_offset_rounded_rect(shadow.rect, dx~, dy~),
      })
    @core.DrawCommand::DrawText(run) =>
      @core.DrawCommand::DrawText({
        ..run,
        frame: webgpu_offset_rect(run.frame, dx~, dy~),
      })
    @core.DrawCommand::DrawImage(run) =>
      @core.DrawCommand::DrawImage({
        ..run,
        frame: webgpu_offset_rect(run.frame, dx~, dy~),
      })
    @core.DrawCommand::PushClip(rect) =>
      @core.DrawCommand::PushClip(webgpu_offset_rect(rect, dx~, dy~))
    @core.DrawCommand::PushRoundedClip(rect) =>
      @core.DrawCommand::PushRoundedClip(
        webgpu_offset_rounded_rect(rect, dx~, dy~),
      )
    @core.DrawCommand::PushTransform(transform) =>
      @core.DrawCommand::PushTransform({
        ..transform,
        tx: transform.tx + dx,
        ty: transform.ty + dy,
      })
    @core.DrawCommand::PushLayer(layer) =>
      @core.DrawCommand::PushLayer({
        ..layer,
        mask: webgpu_offset_layer_mask(layer.mask, dx~, dy~),
      })
    @core.DrawCommand::BeginCachedLayer(spec) =>
      @core.DrawCommand::BeginCachedLayer({
        ..spec,
        frame: webgpu_offset_rect(spec.frame, dx~, dy~),
      })
    @core.DrawCommand::DrawCachedLayer(spec) =>
      @core.DrawCommand::DrawCachedLayer({
        ..spec,
        frame: webgpu_offset_rect(spec.frame, dx~, dy~),
      })
    @core.DrawCommand::DrawPath(path) =>
      @core.DrawCommand::DrawPath({
        ..path,
        verbs: path.verbs.map(verb => webgpu_offset_path_verb(verb, dx~, dy~)),
        fill: webgpu_offset_optional_brush(path.fill, dx~, dy~),
        stroke: webgpu_offset_optional_brush(path.stroke, dx~, dy~),
      })
    @core.DrawCommand::DrawShaderEffect(spec) =>
      @core.DrawCommand::DrawShaderEffect({
        ..spec,
        frame: webgpu_offset_rect(spec.frame, dx~, dy~),
        fallback: webgpu_offset_brush(spec.fallback, dx~, dy~),
      })
  }
}

///|
fn webgpu_offset_rect(
  rect : @core.Rect,
  dx~ : Double,
  dy~ : Double,
) -> @core.Rect {
  rect.offset(dx~, dy~)
}

///|
fn webgpu_offset_point(
  point : @core.Point,
  dx~ : Double,
  dy~ : Double,
) -> @core.Point {
  @core.Point::new(x=point.x + dx, y=point.y + dy)
}

///|
fn webgpu_offset_rounded_rect(
  rect : @core.RoundedRect,
  dx~ : Double,
  dy~ : Double,
) -> @core.RoundedRect {
  { ..rect, rect: webgpu_offset_rect(rect.rect, dx~, dy~) }
}

///|
fn webgpu_offset_layer_mask(
  mask : @core.LayerMask,
  dx~ : Double,
  dy~ : Double,
) -> @core.LayerMask {
  match mask {
    @core.LayerMask::NoMask => mask
    @core.LayerMask::RectMask(rect) =>
      @core.LayerMask::RectMask(webgpu_offset_rect(rect, dx~, dy~))
    @core.LayerMask::RoundedMask(rect) =>
      @core.LayerMask::RoundedMask(webgpu_offset_rounded_rect(rect, dx~, dy~))
  }
}

///|
fn webgpu_offset_path_verb(
  verb : @core.PathVerb,
  dx~ : Double,
  dy~ : Double,
) -> @core.PathVerb {
  match verb {
    @core.PathVerb::Close => verb
    @core.PathVerb::MoveTo(point) =>
      @core.PathVerb::MoveTo(webgpu_offset_point(point, dx~, dy~))
    @core.PathVerb::LineTo(point) =>
      @core.PathVerb::LineTo(webgpu_offset_point(point, dx~, dy~))
    @core.PathVerb::QuadTo(c, point) =>
      @core.PathVerb::QuadTo(
        webgpu_offset_point(c, dx~, dy~),
        webgpu_offset_point(point, dx~, dy~),
      )
    @core.PathVerb::CubicTo(c1, c2, point) =>
      @core.PathVerb::CubicTo(
        webgpu_offset_point(c1, dx~, dy~),
        webgpu_offset_point(c2, dx~, dy~),
        webgpu_offset_point(point, dx~, dy~),
      )
  }
}

///|
fn webgpu_offset_brush(
  brush : @core.Brush,
  dx~ : Double,
  dy~ : Double,
) -> @core.Brush {
  match brush {
    @core.Brush::Solid(_) => brush
    @core.Brush::LinearGradient(spec) =>
      @core.Brush::LinearGradient({
        ..spec,
        start: webgpu_offset_point(spec.start, dx~, dy~),
        end: webgpu_offset_point(spec.end, dx~, dy~),
      })
    @core.Brush::RadialGradient(spec) =>
      @core.Brush::RadialGradient({
        ..spec,
        center: webgpu_offset_point(spec.center, dx~, dy~),
      })
  }
}

///|
fn webgpu_offset_optional_brush(
  brush : @core.Brush?,
  dx~ : Double,
  dy~ : Double,
) -> @core.Brush? {
  match brush {
    Some(value) => Some(webgpu_offset_brush(value, dx~, dy~))
    None => None
  }
}
