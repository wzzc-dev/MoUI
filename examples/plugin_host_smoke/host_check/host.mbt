///|
/// A minimal plugin host: N independent runtimes, each rendering its own view,
/// plus a compositor that offsets their command streams into one frame.
///
/// This is the shape the isolated-plugin design needs (P2.5 decision gate). In
/// production each runtime lives in its own wasm instance and the commands cross
/// as JSON; here they are in-process so the *geometry and lifecycle* questions
/// can be answered without build-system work.

///|
/// One hosted plugin instance.
pub(all) struct HostedPlugin {
  id : String
  /// Where this plugin's frame lands in host coordinates.
  origin : @geometry.Point
  size : @geometry.Size
}

///|
pub fn HostedPlugin::new(
  id : String,
  origin : @geometry.Point,
  size : @geometry.Size,
) -> HostedPlugin {
  { id, origin, size, }
}

///|
/// Render one plugin to its command stream, sized to its own panel.
pub fn[Msg] render_plugin(
  plugin : HostedPlugin,
  view : @moui.View[Msg],
) -> Array[@core.DrawCommand] {
  let runtime = @runtime.new_view(
    root=view,
    size=@geometry.Size::new(width=plugin.size.width, height=plugin.size.height),
  )
  runtime.draw_commands()
}

// ---------------------------------------------------------------------------
// NOTE: the helpers below are a **verbatim copy** of
// `moui_studio/kernel/plugin_compose.mbt`. `examples/` is a separate MoonBit
// module and cannot import `moui_studio`, so the smoke cannot call the kernel
// implementation. Keep them byte-identical (aside from the `@geometry.` type
// aliases): a drifting copy would make this smoke prove nothing.
// `tools/moui/validate_studio_plugin_boundary` checks the two stay in sync.
// ---------------------------------------------------------------------------

///|
/// Offset a command stream by `by`, for compositing into the host frame.
///
/// Every variant that carries a coordinate moves; the clip and transform stack
/// moves too, otherwise a plugin's clip would cut host content in the wrong
/// place. Variants with no geometry pass through untouched.
pub fn offset_commands(
  commands : Array[@core.DrawCommand],
  by : @core.Point,
) -> Array[@core.DrawCommand] {
  let out : Array[@core.DrawCommand] = []
  for command in commands {
    out.push(shift_command(command, by))
  }
  out
}

///|
fn shift_command(
  command : @core.DrawCommand,
  by : @core.Point,
) -> @core.DrawCommand {
  match command {
    @core.Clear(color) => @core.Clear(color)
    @core.FillRect(rect, color) => @core.FillRect(shift_rect(rect, by), color)
    @core.StrokeRect(rect, color, width) =>
      @core.StrokeRect(shift_rect(rect, by), color, width)
    @core.FillRoundedRect(rounded, color) =>
      @core.FillRoundedRect(shift_rounded(rounded, by), color)
    @core.StrokeRoundedRect(rounded, color, width) =>
      @core.StrokeRoundedRect(shift_rounded(rounded, by), color, width)
    @core.FillRoundedRectBrush(rounded, brush) =>
      @core.FillRoundedRectBrush(shift_rounded(rounded, by), brush)
    @core.StrokeRoundedRectBrush(rounded, brush, width) =>
      @core.StrokeRoundedRectBrush(shift_rounded(rounded, by), brush, width)
    @core.DrawShadow(spec) =>
      @core.DrawShadow({
        ..spec,
        rect: shift_rounded(spec.rect, by),
        offset: @core.Point::new(x=spec.offset.x + by.x, y=spec.offset.y + by.y),
      })
    @core.DrawText(run) =>
      @core.DrawText({ ..run, frame: shift_rect(run.frame, by), })
    @core.DrawImage(run) =>
      @core.DrawImage({ ..run, frame: shift_rect(run.frame, by), })
    @core.PushClip(rect) => @core.PushClip(shift_rect(rect, by))
    @core.PopClip => @core.PopClip
    @core.PushRoundedClip(rounded) =>
      @core.PushRoundedClip(shift_rounded(rounded, by))
    @core.PopRoundedClip => @core.PopRoundedClip
    @core.PushTransform(transform) =>
      @core.PushTransform({
        ..transform,
        tx: transform.tx + by.x,
        ty: transform.ty + by.y,
      })
    @core.PopTransform => @core.PopTransform
    @core.PushOpacity(value) => @core.PushOpacity(value)
    @core.PopOpacity => @core.PopOpacity
    @core.PushLayer(spec) =>
      @core.PushLayer({ ..spec, mask: shift_mask(spec.mask, by), })
    @core.PopLayer => @core.PopLayer
    @core.BeginRetainedLayer(spec) =>
      @core.BeginRetainedLayer({ ..spec, frame: shift_rect(spec.frame, by), })
    @core.EndRetainedLayer(key) => @core.EndRetainedLayer(key)
    @core.PushFilter(effect) => @core.PushFilter(effect)
    @core.PopFilter => @core.PopFilter
    @core.DrawPath(spec) =>
      @core.DrawPath({ ..spec, verbs: shift_verbs(spec.verbs, by), })
    @core.DrawShaderEffect(spec) =>
      @core.DrawShaderEffect({ ..spec, frame: shift_rect(spec.frame, by), })
  }
}

///|
fn shift_rect(rect : @core.Rect, by : @core.Point) -> @core.Rect {
  @core.Rect::new(
    x=rect.origin.x + by.x,
    y=rect.origin.y + by.y,
    width=rect.size.width,
    height=rect.size.height,
  )
}

///|
fn shift_rounded(
  rounded : @core.RoundedRect,
  by : @core.Point,
) -> @core.RoundedRect {
  { ..rounded, rect: shift_rect(rounded.rect, by), }
}

///|
fn shift_mask(mask : @core.LayerMask, by : @core.Point) -> @core.LayerMask {
  match mask {
    @core.NoMask => @core.NoMask
    @core.RectMask(rect) => @core.RectMask(shift_rect(rect, by))
    @core.RoundedMask(rounded) => @core.RoundedMask(shift_rounded(rounded, by))
  }
}

///|
fn shift_verbs(
  verbs : Array[@core.PathVerb],
  by : @core.Point,
) -> Array[@core.PathVerb] {
  let out : Array[@core.PathVerb] = []
  for verb in verbs {
    out.push(
      match verb {
        @core.MoveTo(point) => @core.MoveTo(shift_point(point, by))
        @core.LineTo(point) => @core.LineTo(shift_point(point, by))
        @core.QuadTo(a, b) =>
          @core.QuadTo(shift_point(a, by), shift_point(b, by))
        @core.CubicTo(a, b, c) =>
          @core.CubicTo(
            shift_point(a, by),
            shift_point(b, by),
            shift_point(c, by),
          )
        @core.Close => @core.Close
      },
    )
  }
  out
}

///|
fn shift_point(point : @core.Point, by : @core.Point) -> @core.Point {
  @core.Point::new(x=point.x + by.x, y=point.y + by.y)
}

///|
/// 一帧插件命令覆盖的区域（宿主坐标系）。
///
/// 这是把插件帧接进宿主 damage 系统的第一步：不需要实例化，只需要每条命令的
/// 包围盒——`DrawCommand::bounds` 已覆盖全部 29 个变体，而 `offset_commands`
/// 已经把坐标平移过了，所以这里得到的是**宿主坐标**。
///
/// **只统计真正上屏的变体。** `DrawCommand::bounds` 对 `PushClip` 也返回矩形
/// （裁剪区变了确实改变可见内容），但压栈本身不画像素——把它算进 damage 会让
/// 每次裁剪变化都重绘一整块区域。`Clear` 与 `PushOpacity`/`PushTransform`
/// 返回 `None`，本来就不贡献。
pub fn frame_damage_rects(
  commands : Array[@core.DrawCommand],
) -> Array[@core.Rect] {
  let out : Array[@core.Rect] = []
  for command in commands {
    if paints_pixels(command) {
      match @core.DrawCommand::bounds(command) {
        Some(bounds) => out.push(bounds)
        None => ()
      }
    }
  }
  out
}

///|
/// 该命令是否真的画像素（相对于改变状态的压栈/弹栈）。
fn paints_pixels(command : @core.DrawCommand) -> Bool {
  match command {
    @core.Clear(_) => false
    @core.FillRect(_, _) => true
    @core.StrokeRect(_, _, _) => true
    @core.FillRoundedRect(_, _) => true
    @core.StrokeRoundedRect(_, _, _) => true
    @core.FillRoundedRectBrush(_, _) => true
    @core.StrokeRoundedRectBrush(_, _, _) => true
    @core.DrawShadow(_) => true
    @core.DrawText(_) => true
    @core.DrawImage(_) => true
    @core.PushClip(_) => false
    @core.PopClip => false
    @core.PushRoundedClip(_) => false
    @core.PopRoundedClip => false
    @core.PushTransform(_) => false
    @core.PopTransform => false
    @core.PushOpacity(_) => false
    @core.PopOpacity => false
    @core.PushLayer(_) => false
    @core.PopLayer => false
    @core.BeginRetainedLayer(_) => false
    @core.EndRetainedLayer(_) => false
    @core.PushFilter(_) => false
    @core.PopFilter => false
    @core.DrawPath(_) => true
    @core.DrawShaderEffect(_) => true
  }
}

///|
/// 一帧插件命令的 damage 区域，裁剪到宿主 surface。
///
/// 用 `DamageRegion::from_rects` 而不是自己合并矩形：它已经负责裁剪到 surface
/// 与跨矩形合并，重复实现会引入与 core 不一致的边界行为。
pub fn frame_damage(
  commands : Array[@core.DrawCommand],
  surface : @core.Rect,
) -> @core.DamageRegion {
  @core.DamageRegion::from_rects(frame_damage_rects(commands), surface)
}
