///|
/// Users call methods instead of constructing `DrawCommand` variants directly./// Drawing context that collects `DrawCommand`s internally.
pub(all) struct PaintContext {
  commands : Array[@core.DrawCommand]
}

///|
pub fn PaintContext::new() -> PaintContext {
  { commands: [], }
}

///|
pub fn PaintContext::finish(self : PaintContext) -> Array[@core.DrawCommand] {
  self.commands
}

// === Basic drawing ===

///|
pub fn clear(ctx : PaintContext, color : @core.Color) -> Unit {
  ctx.commands.push(Clear(color))
}

///|
pub fn fill_rect(
  ctx : PaintContext,
  rect : @core.Rect,
  color : @core.Color,
) -> Unit {
  ctx.commands.push(FillRect(rect, color))
}

///|
pub fn stroke_rect(
  ctx : PaintContext,
  rect : @core.Rect,
  color : @core.Color,
  width : Double,
) -> Unit {
  ctx.commands.push(StrokeRect(rect, color, width))
}

///|
pub fn fill_rounded_rect(
  ctx : PaintContext,
  rect : @core.RoundedRect,
  brush : @core.Brush,
) -> Unit {
  ctx.commands.push(FillRoundedRectBrush(rect, brush))
}

///|
pub fn stroke_rounded_rect(
  ctx : PaintContext,
  rect : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
) -> Unit {
  ctx.commands.push(StrokeRoundedRectBrush(rect, brush, width))
}

///|
pub fn draw_shadow(ctx : PaintContext, spec : @core.ShadowSpec) -> Unit {
  ctx.commands.push(DrawShadow(spec))
}

///|
pub fn draw_text(ctx : PaintContext, run : @core.TextRun) -> Unit {
  ctx.commands.push(DrawText(run))
}

///|
pub fn draw_image(ctx : PaintContext, image : @core.ImageRun) -> Unit {
  ctx.commands.push(DrawImage(image))
}

///|
pub fn draw_path(ctx : PaintContext, spec : @core.PathSpec) -> Unit {
  ctx.commands.push(DrawPath(spec))
}

///|
pub fn draw_shader_effect(
  ctx : PaintContext,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  ctx.commands.push(DrawShaderEffect(spec))
}

// === Clip ===

///|
pub fn push_clip(ctx : PaintContext, rect : @core.Rect) -> Unit {
  ctx.commands.push(PushClip(rect))
}

///|
pub fn pop_clip(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopClip)
}

///|
pub fn push_rounded_clip(ctx : PaintContext, rect : @core.RoundedRect) -> Unit {
  ctx.commands.push(PushRoundedClip(rect))
}

///|
pub fn pop_rounded_clip(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopRoundedClip)
}

// === Transform ===

///|
pub fn push_transform(
  ctx : PaintContext,
  transform : @core.Transform2D,
) -> Unit {
  ctx.commands.push(PushTransform(transform))
}

///|
pub fn pop_transform(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopTransform)
}

///|
pub fn push_opacity(ctx : PaintContext, opacity : Double) -> Unit {
  ctx.commands.push(PushOpacity(opacity))
}

///|
pub fn pop_opacity(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopOpacity)
}

// === Layer ===

///|
pub fn push_layer(ctx : PaintContext, spec : @core.LayerSpec) -> Unit {
  ctx.commands.push(PushLayer(spec))
}

///|
pub fn pop_layer(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopLayer)
}

// === Filter ===

///|
pub fn push_filter(ctx : PaintContext, effect : @core.FilterEffect) -> Unit {
  ctx.commands.push(PushFilter(effect))
}

///|
pub fn pop_filter(ctx : PaintContext) -> Unit {
  ctx.commands.push(PopFilter)
}
