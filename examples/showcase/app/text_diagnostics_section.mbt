///|
fn ShowcaseModel::text_diagnostics_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  self.section_panel(
    theme,
    "Text Diagnostics",
    "CJK, bidi, emoji, wrapping, Markdown, and rich text diagnostics.",
    grid(
      [
        text_diagnostic_card(
          theme, "CJK", "MoUI 中文混排 mixed with English 123", card_width,
        ),
        text_diagnostic_card(
          theme, "RTL / Bidi", "שלום עולם MoUI 123 اتجاه النص",
          card_width,
        ),
        text_diagnostic_card(
          theme, "Emoji", "Text 🙂 👩‍💻 ☕️ native partial\nweb partial",
          card_width,
        ),
        text_diagnostic_card(
          theme, "Wrapping", "A deliberately long diagnostic sentence is clipped inside a fixed card so layout bounds stay visible.",
          card_width,
        ),
        text_frame_clip_card(theme, card_width),
        showcase_soft_card(
          theme,
          column(
            [
              text("Markdown/Rich Text", width=card_width - 32.0, height=24.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              showcase_markdown_editor(
                self.draft,
                on_input=value => DraftChanged(value),
                placeholder="Markdown diagnostic",
                width=card_width - 32.0,
                height=76.0,
                variant=@views.TextFieldVariant::Outline,
                theme~,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Start,
          ),
          width=card_width,
          height=132.0,
          padding=theme.spacing_scale.md,
        ),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn text_frame_clip_sample() -> String {
  "Sphinx of black quartz, judge my vexing MoUI layout preview."
}

///|
fn text_frame_clip_card(
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  let frame_width = 96.0
  showcase_soft_card(
    theme,
    column(
      [
        text("Text Frame Clip", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        surface(
          text(text_frame_clip_sample(), width=frame_width - 16.0, height=28.0)
          .font(theme.typography.body)
          .foreground(theme.palette.foreground),
          width=frame_width,
          height=42.0,
          background=theme.palette.background,
          corner_radius=theme.radius_scale.sm,
          theme~,
          padding=8.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=124.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn text_diagnostic_card(
  theme : @core.Theme,
  title : String,
  sample : String,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        scroll_view(
          text(sample, width=width - 52.0, height=64.0)
          .font(theme.typography.body)
          .foreground(theme.palette.muted),
          width=width - 32.0,
          height=68.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=124.0,
    padding=theme.spacing_scale.md,
  )
}

///|
