///|
fn ShowcaseModel::advanced_rendering_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let card_width = if metrics.compact { 260.0 } else { 300.0 }
  let cards = [
    advanced_rendering_card(
      theme, "Renderer Smoke", card_width, "renderer-smoke",
    ),
    advanced_rendering_card(
      theme, "Transform Pixel", card_width, "transform-pixel",
    ),
    advanced_rendering_card(theme, "Layer + Blend", card_width, "blend"),
    advanced_rendering_card(theme, "Filter", card_width, "filter"),
    advanced_rendering_card(theme, "Shader", card_width, "shader"),
    advanced_rendering_card(theme, "Path + Transform", card_width, "path"),
  ]
  self.section_panel(
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
  theme : @moui.Theme,
  title : String,
  width : Double,
  mode : String,
) -> @moui.View[ShowcaseMsg] {
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
  theme : @moui.Theme,
  mode : String,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  @views.canvas(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width~, height~))
    },
    draw=(ctx, frame) => {
      let bg = @views.RoundedRect::new(rect=frame, radius=theme.radius_scale.md)
      let inset = 14.0
      let left = frame.origin.x + inset
      let top = frame.origin.y + inset
      let rect_a = @geometry.Rect::new(x=left, y=top, width=88.0, height=58.0)
      let rect_b = @geometry.Rect::new(
        x=left + 42.0,
        y=top + 24.0,
        width=96.0,
        height=58.0,
      )
      let layer_mask = @views.LayerMask::RoundedMask(bg)
      push_clip(ctx, frame)
      fill_rounded_rect(
        ctx,
        bg,
        @graphics.Brush::solid(
          theme.palette.surface_variant.multiply_alpha(0.36),
        ),
      )
      match mode {
        "blend" => {
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(rect=rect_a, radius=12.0),
            @graphics.Brush::solid(theme.palette.primary.multiply_alpha(0.82)),
          )
          push_layer(
            ctx,
            @views.LayerSpec::new(
              opacity=0.86,
              blend_mode=@views.BlendMode::Multiply,
              mask=layer_mask,
              offscreen=true,
            ),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(rect=rect_b, radius=18.0),
            @graphics.Brush::solid(theme.palette.primary.multiply_alpha(0.84)),
          )
          pop_layer(ctx)
          push_layer(
            ctx,
            @views.LayerSpec::new(
              opacity=0.72,
              blend_mode=@views.BlendMode::Screen,
              mask=layer_mask,
              offscreen=true,
            ),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=@geometry.Rect::new(
                x=left + 96.0,
                y=top + 8.0,
                width=58.0,
                height=58.0,
              ),
              radius=29.0,
            ),
            @graphics.Brush::solid(theme.palette.surface.multiply_alpha(0.7)),
          )
          pop_layer(ctx)
          push_layer(
            ctx,
            @views.LayerSpec::new(
              opacity=0.68,
              blend_mode=@views.BlendMode::Overlay,
              mask=layer_mask,
              offscreen=true,
            ),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=@geometry.Rect::new(
                x=left + 18.0,
                y=top + 58.0,
                width=116.0,
                height=26.0,
              ),
              radius=13.0,
            ),
            @graphics.Brush::solid(
              theme.palette.foreground.multiply_alpha(0.36),
            ),
          )
          pop_layer(ctx)
        }
        "filter" => {
          push_filter(ctx, @views.FilterEffect::blur(4.0))
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(rect=rect_a, radius=16.0),
            @graphics.Brush::solid(theme.palette.primary.multiply_alpha(0.66)),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(rect=rect_b, radius=16.0),
            @graphics.Brush::solid(
              theme.palette.foreground.multiply_alpha(0.22),
            ),
          )
          pop_filter(ctx)
        }
        "shader" => {
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=frame.inset(@geometry.Insets::all(14.0)),
              radius=theme.radius_scale.lg,
            ),
            @graphics.Brush::radial_gradient(
              center=@geometry.Point::new(
                x=frame.origin.x + width * 0.62,
                y=frame.origin.y + height * 0.48,
              ),
              radius=width * 0.42,
              center_color=theme.palette.primary.multiply_alpha(0.78),
              edge_color=theme.palette.primary.multiply_alpha(0.12),
            ),
          )
          draw_shader_effect(
            ctx,
            @views.ShaderEffectSpec::new(
              name="checker",
              frame=frame.inset(@geometry.Insets::all(10.0)),
              uniforms=[8.0, 0.6],
              fallback=@graphics.Brush::solid(theme.palette.surface_variant),
            ),
          )
          draw_shader_effect(
            ctx,
            @views.ShaderEffectSpec::new(
              name="vignette",
              frame=frame.inset(@geometry.Insets::all(24.0)),
              uniforms=[0.35],
              fallback=@graphics.Brush::solid(
                theme.palette.primary.multiply_alpha(0.5),
              ),
            ),
          )
        }
        "transform-pixel" => {
          let clip = frame.inset(@geometry.Insets::all(10.0))
          let mask_rect = @geometry.Rect::new(
            x=clip.origin.x + 4.0,
            y=clip.origin.y + 4.0,
            width=clip.size.width - 8.0,
            height=clip.size.height - 8.0,
          )
          push_clip(ctx, clip)
          push_layer(
            ctx,
            @views.LayerSpec::new(
              opacity=0.96,
              blend_mode=@views.BlendMode::SourceOver,
              mask=@views.LayerMask::RoundedMask(
                @views.RoundedRect::new(rect=mask_rect, radius=18.0),
              ),
              offscreen=true,
            ),
          )
          push_filter(ctx, @views.FilterEffect::Saturate(1.08))
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(rect=mask_rect, radius=18.0),
            @graphics.Brush::solid(
              @graphics.Color::rgba(r=0.03, g=0.08, b=0.12),
            ),
          )
          push_transform(
            ctx,
            @views.Transform2D::translation(
              dx=mask_rect.origin.x + 16.0,
              dy=mask_rect.origin.y + 10.0,
            ),
          )
          push_transform(ctx, @views.Transform2D::scale(sx=1.08, sy=0.92))
          draw_path(
            ctx,
            @views.PathSpec::new(
              verbs=[
                @views.PathVerb::MoveTo(@geometry.Point::new(x=0.0, y=60.0)),
                @views.PathVerb::LineTo(@geometry.Point::new(x=34.0, y=4.0)),
                @views.PathVerb::LineTo(@geometry.Point::new(x=78.0, y=54.0)),
                @views.PathVerb::LineTo(@geometry.Point::new(x=42.0, y=44.0)),
                @views.PathVerb::Close,
              ],
              fill=Some(
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=1.0, g=0.04, b=0.46),
                ),
              ),
              stroke=Some(
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=1.0, g=0.78, b=0.08),
                ),
              ),
              stroke_width=3.0,
            ),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=@geometry.Rect::new(x=8.0, y=18.0, width=46.0, height=24.0),
              radius=8.0,
            ),
            @graphics.Brush::solid(@graphics.Color::rgba(r=1.0, g=0.04, b=0.46)),
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=@geometry.Rect::new(x=72.0, y=10.0, width=54.0, height=32.0),
              radius=10.0,
            ),
            @graphics.Brush::solid(@graphics.Color::rgba(r=0.0, g=0.82, b=0.92)),
          )
          draw_image(ctx, @views.ImageRun::{
            source: showcase_image_source(),
            frame: @geometry.Rect::new(x=118.0, y=18.0, width=52.0, height=30.0),
            opacity: 0.95,
            fit: @views.ImageFit::Cover,
          })
          draw_text(
            ctx,
            @text.TextRun::new(
              text="PX",
              frame=@geometry.Rect::new(x=76.0, y=52.0, width=74.0, height=24.0),
              font=theme.typography.caption,
              color=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0),
            ),
          )
          pop_transform(ctx)
          pop_transform(ctx)
          pop_filter(ctx)
          pop_layer(ctx)
          pop_clip(ctx)
        }
        "renderer-smoke" => {
          let smoke_font = @text.FontSpec::new(
            families=@text.FontFamilyStack::new([
              @text.FontFamily::Emoji,
              @text.FontFamily::SystemUi,
            ]),
            size=28.0,
            weight=500,
          )
          let body_font = @text.FontSpec::new(
            families=@text.FontFamilyStack::system_ui(),
            size=14.0,
            weight=600,
          )
          fill_rounded_rect(
            ctx,
            @views.RoundedRect::new(
              rect=@geometry.Rect::new(x=left, y=top, width=78.0, height=78.0),
              radius=18.0,
            ),
            @graphics.Brush::radial_gradient(
              center=@geometry.Point::new(x=left + 24.0, y=top + 24.0),
              radius=64.0,
              center_color=@graphics.Color::rgba(r=1.0, g=0.04, b=0.18),
              edge_color=@graphics.Color::rgba(r=0.02, g=0.2, b=1.0),
            ),
          )
          draw_image(ctx, @views.ImageRun::{
            source: showcase_image_source(),
            frame: @geometry.Rect::new(
              x=left + 92.0,
              y=top + 4.0,
              width=52.0,
              height=32.0,
            ),
            opacity: 1.0,
            fit: @views.ImageFit::Cover,
          })
          draw_text(
            ctx,
            @text.TextRun::new(
              text="👩‍💻",
              frame=@geometry.Rect::new(
                x=left + 154.0,
                y=top + 2.0,
                width=56.0,
                height=36.0,
              ),
              font=smoke_font,
              color=@graphics.Color::black(),
            ),
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text="ABC אבג 123",
              frame=@geometry.Rect::new(
                x=left + 92.0,
                y=top + 42.0,
                width=126.0,
                height=20.0,
              ),
              font=body_font,
              color=@graphics.Color::black(),
              align=@text.TextAlign::TextStart,
            ),
          )
          for index in 0..<3 {
            draw_text(
              ctx,
              @text.TextRun::new(
                text="Smoke wrap line " + (index + 1).to_string(),
                frame=@geometry.Rect::new(
                  x=left + 92.0,
                  y=top + 64.0 + index.to_double() * 16.0,
                  width=126.0,
                  height=16.0,
                ),
                font=body_font,
                color=@graphics.Color::black(),
                align=@text.TextAlign::TextStart,
              ),
            )
          }
        }
        _ => {
          push_opacity(ctx, 0.82)
          push_transform(ctx, @views.Transform2D::translation(dx=18.0, dy=4.0))
          draw_path(
            ctx,
            @views.PathSpec::new(
              verbs=[
                @views.PathVerb::MoveTo(
                  @geometry.Point::new(x=left + 8.0, y=top + 74.0),
                ),
                @views.PathVerb::CubicTo(
                  @geometry.Point::new(x=left + 42.0, y=top - 6.0),
                  @geometry.Point::new(x=left + 104.0, y=top + 14.0),
                  @geometry.Point::new(x=left + 136.0, y=top + 76.0),
                ),
                @views.PathVerb::LineTo(
                  @geometry.Point::new(x=left + 70.0, y=top + 48.0),
                ),
                @views.PathVerb::Close,
              ],
              fill=Some(
                @graphics.Brush::solid(
                  theme.palette.primary.multiply_alpha(0.72),
                ),
              ),
              stroke=Some(
                @graphics.Brush::solid(
                  theme.palette.foreground.multiply_alpha(0.48),
                ),
              ),
              stroke_width=2.0,
            ),
          )
          pop_transform(ctx)
          pop_opacity(ctx)
        }
      }
      pop_clip(ctx)
    },
    semantics_label=mode,
  )
}
