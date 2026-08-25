///|
fn avatar_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let sample_width = if compact { inner } else { (inner - 12.0) / 2.0 }
  component_demo_section(
    "Avatar",
    "Avatars provide identity marks without requiring image assets.",
    responsive_grid(
      [
        container(
          row(
            [
              @views.avatar("Component Gallery", theme~, size=44.0),
              @views.avatar("Android", theme~, size=44.0),
              @views.avatar("iOS", theme~, size=44.0),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Center,
          ),
          width=sample_width,
          height=76.0,
          variant=@views.ContainerVariant::Base,
          background=theme.palette.surface_variant.multiply_alpha(0.45),
          padding=16.0,
          corner_radius=8.0,
          theme~,
        ),
        container(
          @views.avatar_group(
            ["macOS", "Linux", "Windows", "Android", "iOS", "Web"],
            theme~,
            size=36.0,
            max_visible=4,
          ),
          width=sample_width,
          height=76.0,
          variant=@views.ContainerVariant::Base,
          background=theme.palette.surface_variant.multiply_alpha(0.45),
          padding=16.0,
          corner_radius=8.0,
          theme~,
        ),
      ],
      width=inner,
      min_column_width=sample_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn divider_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Divider",
    "A quiet separator gives dense component pages more rhythm.",
    container(
      column(
        [
          text(
            "Before",
            role=@views.TextRole::Control,
            theme~,
            width=inner - 24.0,
            height=26.0,
            align=@text.TextAlign::TextStart,
          ),
          @views.divider(theme~, inset=0.0).frame(
            width=inner - 24.0,
            height=1.0,
          ),
          text(
            "After",
            role=@views.TextRole::Control,
            theme~,
            width=inner - 24.0,
            height=26.0,
            align=@text.TextAlign::TextStart,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
      width=inner,
      variant=@views.ContainerVariant::Base,
      background=theme.palette.surface_variant.multiply_alpha(0.45),
      padding=12.0,
      corner_radius=8.0,
      theme~,
    ),
    theme,
    width,
  )
}

///|
fn toolbar_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Toolbar",
    "Toolbars collect related commands without needing a full navigation shell.",
    column(
      [
        @views.toolbar(
          [
            button(
              "Run",
              on_click=Increment,
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=72.0,
              height=34.0,
            ),
            button(
              "Reset",
              on_click=Reset,
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=84.0,
              height=34.0,
            ),
            button(
              "Docs",
              on_click=Reset,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=74.0,
              height=34.0,
            ),
          ],
          theme~,
          width=inner,
        ),
        @views.command_bar(
          [
            @views.action_item(id="copy", label="Copy", message=Reset),
            @views.action_item(id="format", label="Format", message=Reset),
            @views.action_item(
              id="disabled",
              label="Disabled",
              message=Reset,
              enabled=false,
            ),
          ],
          theme~,
          width=inner,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}

///|
fn status_bar_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Status Bar",
    "Status bars keep compact metadata visible at the edge of a tool surface.",
    @views.status_bar(
      [
        platform_display_name(model.active_platform),
        "\{component_gallery_items().length()} demos",
        density_label(model.selected_density),
      ],
      theme~,
      width=inner,
    ),
    theme,
    width,
  )
}
