///|
fn ShowcaseModel::text_diagnostics_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
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
              text(
                "RichText doc spans: " + showcase_format_rich_text("sample").blocks.length().to_string(),
                width=card_width - 32.0,
                height=20.0,
              )
                .font(theme.typography.caption)
                .foreground(theme.palette.muted),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Start,
          ),
          width=card_width,
          height=132.0,
          padding=theme.spacing_scale.md,
        ),
        showcase_soft_card(
          theme,
          column(
            [
              text("Gallery membership", width=card_width - 32.0, height=24.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              row(
                {
                  let chips : Array[@moui.View[ShowcaseMsg]] = []
                  for item in gallery_items() {
                    let hit = showcase_string_array_contains(["atlas", "catalog"], item)
                    let label = if hit { item + " ✓" } else { item + " ·" }
                    chips.push(
                      text(label, width=84.0, height=24.0)
                        .font(theme.typography.caption)
                        .foreground(if hit {
                          theme.palette.primary
                        } else {
                          theme.palette.muted
                        }),
                    )
                  }
                  chips
                },
                spacing=theme.spacing_scale.xs,
                align=@views.CrossAlign::Center,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Start,
          ),
          width=card_width,
          height=88.0,
          padding=theme.spacing_scale.md,
        ),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
    eyebrow=showcase_route_eyebrow("text-diagnostics"),
  )
}

///|
fn text_frame_clip_sample() -> String {
  "Sphinx of black quartz, judge my vexing MoUI layout preview."
}

///|
fn text_frame_clip_card(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let frame_width = 96.0
  showcase_soft_card(
    theme,
    column(
      [
        text("Text Frame Clip", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        container(
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
  theme : @moui.Theme,
  title : String,
  sample : String,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
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
