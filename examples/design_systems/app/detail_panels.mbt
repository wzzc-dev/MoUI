///|
fn DesignSystemsModel::sickle_palette_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  ignore(self)
  design_panel(
    theme,
    "Semantic palette roles",
    [
      row(
        [
          design_swatch(theme, "foreground", theme.palette.foreground),
          design_swatch(theme, "primary", theme.palette.primary),
          design_swatch(theme, "success", theme.palette.success),
          design_swatch(theme, "warning", theme.palette.warning),
          design_swatch(theme, "danger", theme.palette.danger),
          design_swatch(theme, "info", theme.palette.info),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      design_metric_row(theme, "Role rows", "6"),
      design_metric_row(theme, "Role gaps", "0"),
      design_metric_row(theme, "Source imports", "first-party"),
    ],
    width=448.0,
    height=210.0,
  )
}

///|
fn DesignSystemsModel::sickle_typography_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  ignore(self)
  design_panel(
    theme,
    "Typography specimen",
    [
      text(
        "Title role",
        role=@views.TextRole::Title,
        theme~,
        width=390.0,
        height=34.0,
      ),
      text(
        "Body role: precision typography with compact control rhythm.",
        theme~,
        width=390.0,
        height=30.0,
      ),
      text(
        "Caption role / control role",
        role=@views.TextRole::Caption,
        theme~,
        width=390.0,
        height=24.0,
      ),
      design_metric_row(
        theme,
        "Body size",
        theme.typography.body.size.to_string(),
      ),
      design_metric_row(theme, "Typography gaps", "0"),
    ],
    width=448.0,
    height=210.0,
  )
}

///|
fn DesignSystemsModel::sickle_spacing_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  ignore(self)
  design_panel(
    theme,
    "Spacing and density",
    [
      row(
        [
          spacing_tile(theme, "xs", theme.spacing_scale.xs),
          spacing_tile(theme, "sm", theme.spacing_scale.sm),
          spacing_tile(theme, "md", theme.spacing_scale.md),
          spacing_tile(theme, "lg", theme.spacing_scale.lg),
          spacing_tile(theme, "xl", theme.spacing_scale.xl),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      design_metric_row(
        theme,
        "Style mode",
        @sickle.SickleStyleMode::Hybrid.label(),
      ),
      design_metric_row(theme, "Density", "theme-defined"),
      design_metric_row(theme, "Density gaps", "n/a"),
    ],
    width=448.0,
    height=234.0,
  )
}

///|
fn DesignSystemsModel::sickle_component_matrix_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  design_panel(
    theme,
    "Component token matrix",
    [
      picker(
        [
          picker_item("button", "Button"),
          picker_item("field", "Field"),
          picker_item("toolbar", "Toolbar"),
          picker_item("row", "Data row"),
        ],
        selected=self.selected_component,
        on_select=id => SelectComponent(id),
        theme~,
        max_height=160.0,
      ).frame(width=240.0, height=40.0),
      row(
        [
          button(
            "Primary",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::Primary,
            theme~,
            width=96.0,
            height=36.0,
          ),
          button(
            "Tonal",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=88.0,
            height=36.0,
          ),
          button(
            "Outline",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=96.0,
            height=36.0,
          ),
          button(
            "Ghost",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=80.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      row(
        [
          button(
            "Subtle",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::Subtle,
            theme~,
            width=88.0,
            height=36.0,
          ),
          button(
            "Subtle brand",
            on_click=ToggleCustom,
            variant=@views.ButtonVariant::SubtleBrand,
            theme~,
            width=128.0,
            height=36.0,
          ),
          text_field(
            self.draft,
            on_input=value => DraftChanged(value),
            placeholder="Layered field",
            theme~,
            width=200.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      design_metric_row(theme, "Button", "hybrid flat+skeuo"),
      design_metric_row(theme, "TextField", "layered control states"),
      design_metric_row(theme, "Surface", "raised tactile layers"),
    ],
    width=620.0,
    height=296.0,
  )
}

///|
fn DesignSystemsModel::customization_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  let custom_label = if self.custom_enabled {
    "Custom override on"
  } else {
    "Custom override off"
  }
  if self.preset == DesignSystemChoice::Sickle {
    design_panel(
      theme,
      "Custom inheritance and coverage",
      [
        row(
          [
            button(
              custom_label,
              on_click=ToggleCustom,
              variant=if self.custom_enabled {
                @views.ButtonVariant::Primary
              } else {
                @views.ButtonVariant::Outline
              },
              theme~,
              width=180.0,
              height=38.0,
            ),
            status_badge(
              "first-party theme",
              tone=@views.BadgeTone::Accent,
              theme~,
              width=152.0,
            ),
            status_badge(
              "not source-mapped",
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=152.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        design_metric_row(theme, "Custom APIs", "theme/palette/mode"),
        design_metric_row(theme, "Custom gaps", "0"),
        design_metric_row(theme, "Report rows", "n/a"),
      ],
      width=920.0,
      height=164.0,
    )
  } else {
    design_panel(
      theme,
      "Custom inheritance and coverage",
      [
        row(
          [
            button(
              custom_label,
              on_click=ToggleCustom,
              variant=if self.custom_enabled {
                @views.ButtonVariant::Primary
              } else {
                @views.ButtonVariant::Outline
              },
              theme~,
              width=180.0,
              height=38.0,
            ),
            status_badge(
              "source-mapped preview",
              tone=@views.BadgeTone::Warning,
              theme~,
              width=152.0,
            ),
            status_badge(
              "not official complete",
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=152.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        design_metric_row(
          theme,
          "Custom APIs",
          design_customization_report_count(self.preset).to_string(),
        ),
        design_metric_row(
          theme,
          "Custom gaps",
          design_customization_capability_gap_count(self.preset).to_string(),
        ),
        design_metric_row(
          theme,
          "Report rows",
          design_report_for(
            self.preset,
            scheme=self.tokens().scheme,
            system_scheme=self.scheme,
            density=self.density,
          )
          .evidence_row_count()
          .to_string(),
        ),
      ],
      width=920.0,
      height=164.0,
    )
  }
}

///|
fn design_panel(
  theme : @moui.Theme,
  title : String,
  children : Array[@moui.View[DesignSystemsMsg]],
  width~ : Double,
  height~ : Double,
) -> @moui.View[DesignSystemsMsg] {
  let rows : Array[@moui.View[DesignSystemsMsg]] = [
    text(
      title,
      role=@views.TextRole::Control,
      theme~,
      width=width - 32.0,
      height=28.0,
    ),
  ]
  for child in children {
    rows.push(child)
  }
  container(
    column(rows, spacing=theme.spacing_scale.sm, align=@views.CrossAlign::Start),
    width~,
    height~,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn design_metric_row(
  theme : @moui.Theme,
  label : String,
  value : String,
) -> @moui.View[DesignSystemsMsg] {
  row(
    [
      text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=170.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      text(
        value,
        role=@views.TextRole::Caption,
        theme~,
        width=210.0,
        height=24.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn design_swatch(
  theme : @moui.Theme,
  label : String,
  color : @graphics.Color,
) -> @moui.View[DesignSystemsMsg] {
  container(
    text(label, role=@views.TextRole::Caption, theme~, width=76.0, height=24.0).foreground(
      theme.palette.on_primary,
    ),
    width=88.0,
    height=48.0,
    background=color,
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn spacing_tile(
  theme : @moui.Theme,
  label : String,
  value : Double,
) -> @moui.View[DesignSystemsMsg] {
  container(
    column(
      [
        text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=54.0,
          height=20.0,
        ),
        text(
          value.to_string(),
          role=@views.TextRole::Caption,
          theme~,
          width=54.0,
          height=20.0,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    width=66.0,
    height=54.0,
    background=theme.palette.primary.multiply_alpha(0.18),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn design_status_label(status : @audit.DesignTokenStatus) -> String {
  match status {
    @audit.DesignTokenStatus::NotMapped => "not mapped"
    @audit.DesignTokenStatus::SourceMapped => "source mapped"
    @audit.DesignTokenStatus::PreviewMapped => "preview"
    @audit.DesignTokenStatus::ThemeMapped => "theme mapped"
    @audit.DesignTokenStatus::ComponentMapped => "component"
    @audit.DesignTokenStatus::OfficialComplete => "official"
  }
}

///|
fn design_status_tone(status : @audit.DesignTokenStatus) -> @views.BadgeTone {
  match status {
    @audit.DesignTokenStatus::OfficialComplete => @views.BadgeTone::Success
    @audit.DesignTokenStatus::ThemeMapped
    | @audit.DesignTokenStatus::ComponentMapped => @views.BadgeTone::Accent
    @audit.DesignTokenStatus::NotMapped => @views.BadgeTone::Danger
    _ => @views.BadgeTone::Warning
  }
}

///|
fn design_preset_id(preset : DesignSystemChoice) -> String {
  match preset {
    Material => "material"
    Carbon => "carbon"
    Primer => "primer"
    Fluent => "fluent"
    Sickle => "sickle"
  }
}

///|
fn design_preset_from_id(id : String) -> DesignSystemChoice {
  match id {
    "carbon" => DesignSystemChoice::Carbon
    "primer" => DesignSystemChoice::Primer
    "fluent" => DesignSystemChoice::Fluent
    "sickle" => DesignSystemChoice::Sickle
    _ => DesignSystemChoice::Material
  }
}

///|
fn source_mapped_preset(preset : DesignSystemChoice) -> @common.DesignPreset? {
  match preset {
    Material => Some(@material.preset())
    Carbon => Some(@carbon.preset())
    Primer => Some(@primer.preset())
    Fluent => Some(@fluent.preset())
    Sickle => None
  }
}

///|
fn required_source_mapped_preset(
  preset : DesignSystemChoice,
) -> @common.DesignPreset {
  match source_mapped_preset(preset) {
    Some(value) => value
    None =>
      abort("Sickle is a first-party theme addon, not a source-mapped preset")
  }
}

///|
fn design_tokens_for(
  preset : DesignSystemChoice,
  variant~ : @common.DesignSchemeVariant,
  system_scheme~ : @state.ColorScheme,
  density~ : @common.DesignDensity,
) -> @common.DesignSystemTokens {
  required_source_mapped_preset(preset).tokens_for_variant(
    variant~,
    system_scheme~,
    density~,
  )
}

///|
fn design_report_for(
  preset : DesignSystemChoice,
  scheme~ : @state.ColorScheme,
  system_scheme~ : @state.ColorScheme,
  density~ : @common.DesignDensity,
) -> @audit.DesignSystemReport {
  @audit.design_system_report(
    required_source_mapped_preset(preset),
    scheme~,
    system_scheme~,
    density~,
  )
}

///|
fn design_source_imported_token_count(preset : DesignSystemChoice) -> Int {
  @audit.source_imported_token_count(required_source_mapped_preset(preset))
}

///|
fn design_density_resolver_gap_count(preset : DesignSystemChoice) -> Int {
  @audit.density_resolver_gap_count(required_source_mapped_preset(preset))
}

///|
fn design_component_token_matrix(
  preset : DesignSystemChoice,
) -> Array[@audit.DesignComponentTokenMatrixRecord] {
  @audit.component_token_matrix(required_source_mapped_preset(preset))
}

///|
fn design_customization_report_count(preset : DesignSystemChoice) -> Int {
  @audit.customization_report_count(required_source_mapped_preset(preset))
}

///|
fn design_customization_capability_gap_count(
  preset : DesignSystemChoice,
) -> Int {
  @audit.customization_capability_gap_count(
    required_source_mapped_preset(preset),
  )
}

///|
fn design_scheme_id(scheme : @state.ColorScheme) -> String {
  match scheme {
    @state.ColorScheme::Light => "light"
    @state.ColorScheme::Dark => "dark"
  }
}

///|
fn design_scheme_from_id(id : String) -> @state.ColorScheme {
  match id {
    "dark" => @state.ColorScheme::Dark
    _ => @state.ColorScheme::Light
  }
}

///|
fn design_variant_id(variant : @common.DesignSchemeVariant) -> String {
  match variant {
    @common.DesignSchemeVariant::SchemeLight => "light"
    @common.DesignSchemeVariant::SchemeDark => "dark"
    @common.DesignSchemeVariant::SchemeHighContrast => "high"
    @common.DesignSchemeVariant::SchemeSystem => "system"
  }
}

///|
fn design_variant_from_id(id : String) -> @common.DesignSchemeVariant {
  match id {
    "dark" => @common.DesignSchemeVariant::SchemeDark
    "high" => @common.DesignSchemeVariant::SchemeHighContrast
    "system" => @common.DesignSchemeVariant::SchemeSystem
    _ => @common.DesignSchemeVariant::SchemeLight
  }
}

///|
fn design_density_id(density : @common.DesignDensity) -> String {
  match density {
    @common.DesignDensity::Compact => "compact"
    @common.DesignDensity::Standard => "standard"
    @common.DesignDensity::Comfortable => "comfortable"
  }
}

///|
fn design_density_from_id(id : String) -> @common.DesignDensity {
  match id {
    "compact" => @common.DesignDensity::Compact
    "comfortable" => @common.DesignDensity::Comfortable
    _ => @common.DesignDensity::Standard
  }
}

///|
pub fn DesignSystemsApp::program(
  self : DesignSystemsApp,
) -> @moui.Program[DesignSystemsModel, DesignSystemsMsg] {
  ignore(self)
  program()
}

///|
pub fn program() -> @moui.Program[DesignSystemsModel, DesignSystemsMsg] {
  DesignSystemsModel::new().program()
}

///|
pub fn DesignSystemsModel::program(
  self : DesignSystemsModel,
) -> @moui.Program[DesignSystemsModel, DesignSystemsMsg] {
  @moui.Program::simple(init=self, update~, view~)
}
