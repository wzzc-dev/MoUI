///|
fn ShowcaseModel::advanced_rendering_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  let card_width = if metrics.compact { 260.0 } else { 300.0 }
  let cards = [
    advanced_rendering_card(theme, "Layer + Blend", card_width, "blend"),
    advanced_rendering_card(theme, "Filter", card_width, "filter"),
    advanced_rendering_card(theme, "Shader", card_width, "shader"),
    advanced_rendering_card(theme, "Path + Transform", card_width, "path"),
  ]
  section_panel(
    theme,
    "Advanced Rendering",
    "Layers, blend modes, filters, shader effects, paths, transforms, and opacity.",
    grid(
      cards,
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn advanced_rendering_card(
  theme : @core.Theme,
  title : String,
  width : Double,
  mode : String,
) -> @core.View[ShowcaseMsg] {
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        advanced_rendering_canvas(theme, mode, width - 32.0, 108.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=158.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn advanced_rendering_canvas(
  theme : @core.Theme,
  mode : String,
  width : Double,
  height : Double,
) -> @core.View[ShowcaseMsg] {
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let bg = @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.md)
      let inset = 14.0
      let left = frame.origin.x + inset
      let top = frame.origin.y + inset
      let rect_a = @core.Rect::new(x=left, y=top, width=88.0, height=58.0)
      let rect_b = @core.Rect::new(
        x=left + 42.0,
        y=top + 24.0,
        width=96.0,
        height=58.0,
      )
      let layer_mask = @core.LayerMask::RoundedMask(bg)
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::PushClip(frame),
        @core.DrawCommand::FillRoundedRectBrush(
          bg,
          @core.Brush::solid(theme.palette.surface_variant.multiply_alpha(0.36)),
        ),
      ]
      match mode {
        "blend" => {
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_a, radius=12.0),
              @core.Brush::solid(theme.palette.primary.multiply_alpha(0.82)),
            ),
          )
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.86,
                blend_mode=@core.BlendMode::Multiply,
                mask=layer_mask,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_b, radius=18.0),
              @core.Brush::solid(theme.accent.multiply_alpha(0.84)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.72,
                blend_mode=@core.BlendMode::Screen,
                mask=layer_mask,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(
                rect=@core.Rect::new(
                  x=left + 96.0,
                  y=top + 8.0,
                  width=58.0,
                  height=58.0,
                ),
                radius=29.0,
              ),
              @core.Brush::solid(theme.palette.surface.multiply_alpha(0.7)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.68,
                blend_mode=@core.BlendMode::Overlay,
                mask=layer_mask,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(
                rect=@core.Rect::new(
                  x=left + 18.0,
                  y=top + 58.0,
                  width=116.0,
                  height=26.0,
                ),
                radius=13.0,
              ),
              @core.Brush::solid(theme.palette.foreground.multiply_alpha(0.36)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
        }
        "filter" => {
          commands.push(
            @core.DrawCommand::PushFilter(@core.FilterEffect::blur(4.0)),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_a, radius=16.0),
              @core.Brush::solid(theme.palette.primary.multiply_alpha(0.66)),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_b, radius=16.0),
              @core.Brush::solid(theme.palette.foreground.multiply_alpha(0.22)),
            ),
          )
          commands.push(@core.DrawCommand::PopFilter)
        }
        "shader" => {
          commands.push(
            @core.DrawCommand::DrawShaderEffect(
              @core.ShaderEffectSpec::new(
                name="checker",
                frame=frame.inset(@core.Insets::all(10.0)),
                uniforms=[8.0, 0.6],
                fallback=@core.Brush::solid(theme.palette.surface_variant),
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawShaderEffect(
              @core.ShaderEffectSpec::new(
                name="vignette",
                frame=frame.inset(@core.Insets::all(24.0)),
                uniforms=[0.35],
                fallback=@core.Brush::solid(
                  theme.palette.primary.multiply_alpha(0.5),
                ),
              ),
            ),
          )
        }
        _ => {
          commands.push(@core.DrawCommand::PushOpacity(0.82))
          commands.push(
            @core.DrawCommand::PushTransform(
              @core.Transform2D::translation(dx=18.0, dy=4.0),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawPath(
              @core.PathSpec::new(
                verbs=[
                  @core.PathVerb::MoveTo(
                    @core.Point::new(x=left + 8.0, y=top + 74.0),
                  ),
                  @core.PathVerb::CubicTo(
                    @core.Point::new(x=left + 42.0, y=top - 6.0),
                    @core.Point::new(x=left + 104.0, y=top + 14.0),
                    @core.Point::new(x=left + 136.0, y=top + 76.0),
                  ),
                  @core.PathVerb::LineTo(
                    @core.Point::new(x=left + 70.0, y=top + 48.0),
                  ),
                  @core.PathVerb::Close,
                ],
                fill=Some(
                  @core.Brush::solid(theme.palette.primary.multiply_alpha(0.72)),
                ),
                stroke=Some(
                  @core.Brush::solid(
                    theme.palette.foreground.multiply_alpha(0.48),
                  ),
                ),
                stroke_width=2.0,
              ),
            ),
          )
          commands.push(@core.DrawCommand::PopTransform)
          commands.push(@core.DrawCommand::PopOpacity)
        }
      }
      commands.push(@core.DrawCommand::PopClip)
      commands
    },
    semantics_label=mode,
  )
}

///|
