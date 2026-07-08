///|
fn ShowcaseModel::text_media_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  self.section_panel(
    theme,
    "Text & Media",
    "Text, image, rich text editor, and Markdown editor share one app state.",
    column(
      [
        row(
          [
            text("Label text", width=136.0, height=28.0)
            .font(theme.typography.body)
            .foreground(theme.palette.foreground),
            image(
              showcase_image_source(),
              width=120.0,
              height=72.0,
              opacity~,
              fit=@graphics.ImageFit::Cover,
            ).clip(),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
        text_field(
          self.draft,
          on_input=value => DraftChanged(value),
          placeholder="Editable text",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=320.0,
        ),
        showcase_rich_text_editor(
          self.draft,
          showcase_format_rich_text,
          on_input=value => DraftChanged(value),
          placeholder="Rich text preview",
          width=320.0,
          height=78.0,
          variant=@views.TextFieldVariant::Filled,
          theme~,
        ),
        showcase_markdown_editor(
          self.draft,
          on_input=value => DraftChanged(value),
          placeholder="Markdown preview",
          width=320.0,
          height=78.0,
          variant=@views.TextFieldVariant::Outline,
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
