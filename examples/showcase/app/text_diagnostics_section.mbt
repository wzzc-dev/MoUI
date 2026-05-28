///|
fn ShowcaseModel::text_diagnostics_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  section_panel(
    theme,
    "Text Diagnostics",
    "CJK, bidi, emoji, wrapping, Markdown, and rich text diagnostics.",
    grid(
      [
        text_diagnostic_card(
          theme, "CJK", "MoUI 閺傚洦婀?mixed with English 123", card_width,
        ),
        text_diagnostic_card(
          theme, "RTL / Bidi", "璩蹭箛涓ㄤ簶涓?MoUI 123 鐮栬瘒璁滆瘣",
          card_width,
        ),
        text_diagnostic_card(
          theme, "Emoji", "Text 棣冩棣冩畬閴? native gap\nweb partial",
          card_width,
        ),
        text_diagnostic_card(
          theme, "Wrapping", "A deliberately long diagnostic sentence is clipped inside a fixed card so layout bounds stay visible.",
          card_width,
        ),
        showcase_soft_card(
          theme,
          column(
            [
              text("Markdown/Rich Text", width=card_width - 32.0, height=24.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              markdown_editor(
                self.draft,
                showcase_format_markdown,
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
