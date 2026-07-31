///|
pub using @common {type PaintContext}

// === Basic drawing ===

///|
pub fn clear(ctx : PaintContext, color : @core.Color) -> Unit {
  ctx.commands.push(@core.DrawCommand::Clear(color))
}

///|
pub fn fill_rect(
  ctx : PaintContext,
  rect : @core.Rect,
  color : @core.Color,
) -> Unit {
  ctx.commands.push(@core.DrawCommand::FillRect(rect, color))
}

///|
pub fn stroke_rect(
  ctx : PaintContext,
  rect : @core.Rect,
  color : @core.Color,
  width : Double,
) -> Unit {
  ctx.commands.push(@core.DrawCommand::StrokeRect(rect, color, width))
}

///|
pub fn fill_rounded_rect(
  ctx : PaintContext,
  rect : @core.RoundedRect,
  brush : @core.Brush,
) -> Unit {
  ctx.commands.push(@core.DrawCommand::FillRoundedRectBrush(rect, brush))
}

///|
pub fn stroke_rounded_rect(
  ctx : PaintContext,
  rect : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
) -> Unit {
  ctx.commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(rect, brush, width),
  )
}

///|
pub fn draw_shadow(ctx : PaintContext, spec : @core.ShadowSpec) -> Unit {
  ctx.commands.push(@core.DrawCommand::DrawShadow(spec))
}

///|
pub fn draw_text(ctx : PaintContext, run : @core.TextRun) -> Unit {
  ctx.commands.push(@core.DrawCommand::DrawText(run))
}

///|
pub fn draw_image(ctx : PaintContext, image : @core.ImageRun) -> Unit {
  ctx.commands.push(@core.DrawCommand::DrawImage(image))
}

///|
pub fn draw_path(ctx : PaintContext, spec : @core.PathSpec) -> Unit {
  ctx.commands.push(@core.DrawCommand::DrawPath(spec))
}

///|
pub fn draw_shader_effect(
  ctx : PaintContext,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  ctx.commands.push(@core.DrawCommand::DrawShaderEffect(spec))
}

// === Clip ===

///|
pub fn push_clip(ctx : PaintContext, rect : @core.Rect) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushClip(rect))
}

///|
pub fn pop_clip(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopClip)
}

///|
pub fn push_rounded_clip(ctx : PaintContext, rect : @core.RoundedRect) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushRoundedClip(rect))
}

///|
pub fn pop_rounded_clip(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopRoundedClip)
}

// === Transform ===

///|
pub fn push_transform(
  ctx : PaintContext,
  transform : @core.Transform2D,
) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushTransform(transform))
}

///|
pub fn pop_transform(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopTransform)
}

///|
pub fn push_opacity(ctx : PaintContext, opacity : Double) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushOpacity(opacity))
}

///|
pub fn pop_opacity(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopOpacity)
}

// === Layer ===

///|
pub fn push_layer(ctx : PaintContext, spec : @core.LayerSpec) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushLayer(spec))
}

///|
pub fn pop_layer(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopLayer)
}

// === Filter ===

///|
pub fn push_filter(ctx : PaintContext, effect : @core.FilterEffect) -> Unit {
  ctx.commands.push(@core.DrawCommand::PushFilter(effect))
}

///|
pub fn pop_filter(ctx : PaintContext) -> Unit {
  ctx.commands.push(@core.DrawCommand::PopFilter)
}
