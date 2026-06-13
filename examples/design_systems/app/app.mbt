///|
using @views {
  button,
  choice_item,
  column,
  picker,
  picker_item,
  row,
  scroll_view,
  segmented_control,
  status_badge,
  surface,
  text,
  text_field,
}

///|
pub struct DesignSystemsApp {
  unit : Unit
}

///|
pub(all) enum DesignSystemChoice {
  Material
  Carbon
  Primer
  Fluent
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemsModel {
  preset : DesignSystemChoice
  scheme : @core.ColorScheme
  variant : @common.DesignSchemeVariant
  density : @common.DesignDensity
  custom_enabled : Bool
  selected_component : String
  draft : String
}

///|
pub(all) enum DesignSystemsMsg {
  SelectPreset(String)
  SelectScheme(String)
  SelectVariant(String)
  SelectDensity(String)
  SelectComponent(String)
  ToggleCustom
  DraftChanged(String)
}

///|
pub fn DesignSystemsApp::new() -> DesignSystemsApp {
  { unit: () }
}

///|
pub fn DesignSystemsModel::new() -> DesignSystemsModel {
  {
    preset: DesignSystemChoice::Material,
    scheme: @core.ColorScheme::Light,
    variant: @common.DesignSchemeVariant::SchemeLight,
    density: @common.DesignDensity::Standard,
    custom_enabled: false,
    selected_component: "button",
    draft: "Token override",
  }
}

///|
pub fn DesignSystemsModel::update(
  self : DesignSystemsModel,
  message : DesignSystemsMsg,
) -> DesignSystemsModel {
  match message {
    SelectPreset(id) => { ..self, preset: design_preset_from_id(id) }
    SelectScheme(id) => { ..self, scheme: design_scheme_from_id(id) }
    SelectVariant(id) => { ..self, variant: design_variant_from_id(id) }
    SelectDensity(id) => { ..self, density: design_density_from_id(id) }
    SelectComponent(id) => { ..self, selected_component: id }
    ToggleCustom => { ..self, custom_enabled: !self.custom_enabled }
    DraftChanged(value) => { ..self, draft: value }
  }
}

///|
pub fn update(
  model : DesignSystemsModel,
  message : DesignSystemsMsg,
) -> DesignSystemsModel {
  model.update(message)
}

///|
pub fn view(model : DesignSystemsModel) -> @core.View[DesignSystemsMsg] {
  model.view()
}

///|
pub fn DesignSystemsModel::tokens(
  self : DesignSystemsModel,
) -> @common.DesignSystemTokens {
  design_tokens_for(
    self.preset,
    variant=self.variant,
    system_scheme=self.scheme,
    density=self.density,
  )
}

///|
pub fn DesignSystemsModel::theme(self : DesignSystemsModel) -> @core.Theme {
  let base = self.tokens().to_theme()
  if self.custom_enabled {
    @common.custom(
      base~,
      accent=@core.Color::rgba(r=0.82, g=0.18, b=0.42),
      spacing=14.0,
      corner_radius=10.0,
    )
  } else {
    base
  }
}

///|
pub fn DesignSystemsModel::view(
  self : DesignSystemsModel,
) -> @core.View[DesignSystemsMsg] {
  let tokens = self.tokens()
  let theme = self.theme()
  let report = design_report_for(
    self.preset,
    scheme=tokens.scheme,
    system_scheme=self.scheme,
    density=self.density,
  )
  let content = column(
    [
      self.hero(theme, report),
      self.switcher_panel(theme),
      row(
        [
          self.palette_panel(theme, tokens, report),
          self.typography_panel(theme, tokens, report),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      row(
        [
          self.spacing_density_panel(theme, tokens),
          self.component_matrix_panel(theme, tokens),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      self.customization_panel(theme),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
  surface(
    scroll_view(content, width=920.0, height=620.0),
    width=960.0,
    height=680.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn DesignSystemsModel::hero(
  self : DesignSystemsModel,
  theme : @core.Theme,
  report : @common.DesignSystemReport,
) -> @core.View[DesignSystemsMsg] {
  ignore(self)
  surface(
    row(
      [
        column(
          [
            text(
              "Design Systems",
              role=@views.TextRole::Title,
              theme~,
              width=360.0,
              height=36.0,
            ),
            text(
              "Source-mapped preview package for official token parity work.",
              role=@views.TextRole::Caption,
              theme~,
              width=520.0,
              height=26.0,
            ).foreground(theme.palette.muted),
            text(
              report.manifest.official_name,
              role=@views.TextRole::Body,
              theme~,
              width=520.0,
              height=28.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
        column(
          [
            status_badge(
              design_status_label(report.status),
              tone=design_status_tone(report.status),
              detail=report.note,
              theme~,
              width=138.0,
            ),
            status_badge(
              if report.has_official_completion_claim() {
                "official complete"
              } else {
                "preview"
              },
              tone=if report.has_official_completion_claim() {
                @views.BadgeTone::Success
              } else {
                @views.BadgeTone::Warning
              },
              theme~,
              width=138.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Center,
    ),
    width=920.0,
    height=132.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn DesignSystemsModel::switcher_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
) -> @core.View[DesignSystemsMsg] {
  design_panel(
    theme,
    "Preset, scheme, variant, density",
    [
      segmented_control(
        [
          choice_item("material", "Material"),
          choice_item("carbon", "Carbon"),
          choice_item("primer", "Primer"),
          choice_item("fluent", "Fluent"),
        ],
        selected=design_preset_id(self.preset),
        on_select=id => SelectPreset(id),
        theme~,
        width=620.0,
      ),
      row(
        [
          segmented_control(
            [choice_item("light", "Light"), choice_item("dark", "Dark")],
            selected=design_scheme_id(self.scheme),
            on_select=id => SelectScheme(id),
            theme~,
            width=210.0,
          ),
          segmented_control(
            [
              choice_item("light", "Light"),
              choice_item("dark", "Dark"),
              choice_item("high", "High"),
              choice_item("system", "System"),
            ],
            selected=design_variant_id(self.variant),
            on_select=id => SelectVariant(id),
            theme~,
            width=360.0,
          ),
          segmented_control(
            [
              choice_item("compact", "Compact"),
              choice_item("standard", "Standard"),
              choice_item("comfortable", "Comfortable"),
            ],
            selected=design_density_id(self.density),
            on_select=id => SelectDensity(id),
            theme~,
            width=300.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
    ],
    width=920.0,
    height=138.0,
  )
}

///|
fn DesignSystemsModel::palette_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
  tokens : @common.DesignSystemTokens,
  report : @common.DesignSystemReport,
) -> @core.View[DesignSystemsMsg] {
  ignore(self)
  design_panel(
    theme,
    "Semantic palette roles",
    [
      row(
        [
          design_swatch(theme, "foreground", tokens.palette.foreground),
          design_swatch(theme, "primary", tokens.palette.primary),
          design_swatch(theme, "success", tokens.palette.success),
          design_swatch(theme, "warning", tokens.palette.warning),
          design_swatch(theme, "danger", tokens.palette.danger),
          design_swatch(theme, "info", tokens.palette.info),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      design_metric_row(
        theme,
        "Role rows",
        report.semantic_palette_roles.length().to_string(),
      ),
      design_metric_row(
        theme,
        "Role gaps",
        report.semantic_palette_gap_count().to_string(),
      ),
      design_metric_row(
        theme,
        "Source imports",
        design_source_imported_token_count(self.preset).to_string(),
      ),
    ],
    width=448.0,
    height=210.0,
  )
}

///|
fn DesignSystemsModel::typography_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
  tokens : @common.DesignSystemTokens,
  report : @common.DesignSystemReport,
) -> @core.View[DesignSystemsMsg] {
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
        "Body role: source value is resolved through neutral FontSpec.",
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
        tokens.typography.body.size.to_string(),
      ),
      design_metric_row(
        theme,
        "Typography gaps",
        report.typography_gap_count().to_string(),
      ),
    ],
    width=448.0,
    height=210.0,
  )
}

///|
fn DesignSystemsModel::spacing_density_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
  tokens : @common.DesignSystemTokens,
) -> @core.View[DesignSystemsMsg] {
  ignore(self)
  design_panel(
    theme,
    "Spacing and density",
    [
      row(
        [
          spacing_tile(theme, "xs", tokens.spacing.xs),
          spacing_tile(theme, "sm", tokens.spacing.sm),
          spacing_tile(theme, "md", tokens.spacing.md),
          spacing_tile(theme, "lg", tokens.spacing.lg),
          spacing_tile(theme, "xl", tokens.spacing.xl),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      design_metric_row(theme, "Density", self.density.label()),
      design_metric_row(
        theme,
        "Multiplier",
        tokens.spacing.density_multiplier.to_string(),
      ),
      design_metric_row(
        theme,
        "Density gaps",
        design_density_resolver_gap_count(self.preset).to_string(),
      ),
    ],
    width=448.0,
    height=234.0,
  )
}

///|
fn DesignSystemsModel::component_matrix_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
  tokens : @common.DesignSystemTokens,
) -> @core.View[DesignSystemsMsg] {
  let styles = tokens.core_component_styles()
  let matrix = design_component_token_matrix(self.preset)
  let rows : Array[@core.View[DesignSystemsMsg]] = [
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
          theme~,
          style=styles.button.primary,
          width=112.0,
          height=38.0,
        ),
        text_field(
          self.draft,
          on_input=value => DraftChanged(value),
          placeholder="Custom override",
          theme~,
          style=styles.text_field.outline,
          width=220.0,
          height=38.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
  ]
  let mut shown = 0
  for item in matrix {
    if shown < 3 {
      rows.push(
        design_metric_row(
          theme,
          item.component,
          item.mapped_token_count.to_string() +
          "/" +
          item.required_token_count.to_string() +
          " mapped",
        ),
      )
      shown = shown + 1
    }
  }
  design_panel(theme, "Component token matrix", rows, width=448.0, height=234.0)
}

///|
fn DesignSystemsModel::customization_panel(
  self : DesignSystemsModel,
  theme : @core.Theme,
) -> @core.View[DesignSystemsMsg] {
  let custom_label = if self.custom_enabled {
    "Custom override on"
  } else {
    "Custom override off"
  }
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

///|
fn design_panel(
  theme : @core.Theme,
  title : String,
  children : Array[@core.View[DesignSystemsMsg]],
  width~ : Double,
  height~ : Double,
) -> @core.View[DesignSystemsMsg] {
  let rows : Array[@core.View[DesignSystemsMsg]] = [
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
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=@views.CrossAlign::Start),
    width~,
    height~,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn design_metric_row(
  theme : @core.Theme,
  label : String,
  value : String,
) -> @core.View[DesignSystemsMsg] {
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
  theme : @core.Theme,
  label : String,
  color : @core.Color,
) -> @core.View[DesignSystemsMsg] {
  surface(
    text(label, role=@views.TextRole::Caption, theme~, width=76.0, height=24.0).foreground(
      theme.palette.primary_foreground,
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
  theme : @core.Theme,
  label : String,
  value : Double,
) -> @core.View[DesignSystemsMsg] {
  surface(
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
fn design_status_label(status : @common.DesignTokenStatus) -> String {
  match status {
    @common.DesignTokenStatus::NotMapped => "not mapped"
    @common.DesignTokenStatus::SourceMapped => "source mapped"
    @common.DesignTokenStatus::PreviewMapped => "preview"
    @common.DesignTokenStatus::ThemeMapped => "theme mapped"
    @common.DesignTokenStatus::ComponentMapped => "component"
    @common.DesignTokenStatus::OfficialComplete => "official"
  }
}

///|
fn design_status_tone(status : @common.DesignTokenStatus) -> @views.BadgeTone {
  match status {
    @common.DesignTokenStatus::OfficialComplete => @views.BadgeTone::Success
    @common.DesignTokenStatus::ThemeMapped
    | @common.DesignTokenStatus::ComponentMapped => @views.BadgeTone::Accent
    @common.DesignTokenStatus::NotMapped => @views.BadgeTone::Danger
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
  }
}

///|
fn design_preset_from_id(id : String) -> DesignSystemChoice {
  match id {
    "carbon" => DesignSystemChoice::Carbon
    "primer" => DesignSystemChoice::Primer
    "fluent" => DesignSystemChoice::Fluent
    _ => DesignSystemChoice::Material
  }
}

///|
fn design_tokens_for(
  preset : DesignSystemChoice,
  variant~ : @common.DesignSchemeVariant,
  system_scheme~ : @core.ColorScheme,
  density~ : @common.DesignDensity,
) -> @common.DesignSystemTokens {
  match preset {
    Material => @material.tokens_for_variant(variant~, system_scheme~, density~)
    Carbon => @carbon.tokens_for_variant(variant~, system_scheme~, density~)
    Primer => @primer.tokens_for_variant(variant~, system_scheme~, density~)
    Fluent => @fluent.tokens_for_variant(variant~, system_scheme~, density~)
  }
}

///|
fn design_report_for(
  preset : DesignSystemChoice,
  scheme~ : @core.ColorScheme,
  system_scheme~ : @core.ColorScheme,
  density~ : @common.DesignDensity,
) -> @common.DesignSystemReport {
  match preset {
    Material => @material.report(scheme~, system_scheme~, density~)
    Carbon => @carbon.report(scheme~, system_scheme~, density~)
    Primer => @primer.report(scheme~, system_scheme~, density~)
    Fluent => @fluent.report(scheme~, system_scheme~, density~)
  }
}

///|
fn design_source_imported_token_count(preset : DesignSystemChoice) -> Int {
  match preset {
    Material => @material.preset().source_imported_token_count()
    Carbon => @carbon.preset().source_imported_token_count()
    Primer => @primer.preset().source_imported_token_count()
    Fluent => @fluent.preset().source_imported_token_count()
  }
}

///|
fn design_density_resolver_gap_count(preset : DesignSystemChoice) -> Int {
  match preset {
    Material => @material.preset().density_resolver_gap_count()
    Carbon => @carbon.preset().density_resolver_gap_count()
    Primer => @primer.preset().density_resolver_gap_count()
    Fluent => @fluent.preset().density_resolver_gap_count()
  }
}

///|
fn design_component_token_matrix(
  preset : DesignSystemChoice,
) -> Array[@common.DesignComponentTokenMatrixRecord] {
  match preset {
    Material => @material.component_token_matrix()
    Carbon => @carbon.component_token_matrix()
    Primer => @primer.component_token_matrix()
    Fluent => @fluent.component_token_matrix()
  }
}

///|
fn design_customization_report_count(preset : DesignSystemChoice) -> Int {
  match preset {
    Material => @material.preset().customization_report_count()
    Carbon => @carbon.preset().customization_report_count()
    Primer => @primer.preset().customization_report_count()
    Fluent => @fluent.preset().customization_report_count()
  }
}

///|
fn design_customization_capability_gap_count(
  preset : DesignSystemChoice,
) -> Int {
  match preset {
    Material => @material.preset().customization_capability_gap_count()
    Carbon => @carbon.preset().customization_capability_gap_count()
    Primer => @primer.preset().customization_capability_gap_count()
    Fluent => @fluent.preset().customization_capability_gap_count()
  }
}

///|
fn design_scheme_id(scheme : @core.ColorScheme) -> String {
  match scheme {
    @core.ColorScheme::Light => "light"
    @core.ColorScheme::Dark => "dark"
  }
}

///|
fn design_scheme_from_id(id : String) -> @core.ColorScheme {
  match id {
    "dark" => @core.ColorScheme::Dark
    _ => @core.ColorScheme::Light
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
pub fn DesignSystemsApp::runtime(
  self : DesignSystemsApp,
  width? : Double = 960.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  ignore(self)
  DesignSystemsModel::new().runtime(width~, height~)
}

///|
pub fn runtime(
  width? : Double = 960.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  DesignSystemsModel::new().runtime(width~, height~)
}

///|
pub fn DesignSystemsModel::runtime(
  self : DesignSystemsModel,
  width? : Double = 960.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple(init=self, update~, view~),
    size=@core.Size::new(width~, height~),
  )
}
