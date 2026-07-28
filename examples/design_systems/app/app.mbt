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
  container,
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
  Sickle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemsModel {
  preset : DesignSystemChoice
  scheme : @state.ColorScheme
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
    scheme: @state.ColorScheme::Light,
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
pub fn view(model : DesignSystemsModel) -> @moui.View[DesignSystemsMsg] {
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
pub fn DesignSystemsModel::theme(self : DesignSystemsModel) -> @moui.Theme {
  let base = match self.preset {
    Sickle =>
      @sickle.theme(scheme=self.scheme, mode=@sickle.SickleStyleMode::Hybrid)
    _ => self.tokens().to_theme()
  }
  if self.custom_enabled {
    let palette = {
      ..base.palette,
      primary: @graphics.Color::rgba(r=0.82, g=0.18, b=0.42),
    }
    let spacing_scale = { ..base.spacing_scale, sm: 14.0 }
    let radius_scale = { ..base.radius_scale, md: 10.0 }
    @common.custom(base~, palette~, spacing_scale~, radius_scale~)
  } else {
    base
  }
}

///|
pub fn DesignSystemsModel::view(
  self : DesignSystemsModel,
) -> @moui.View[DesignSystemsMsg] {
  let theme = self.theme()
  let content = if self.preset == DesignSystemChoice::Sickle {
    column(
      [
        self.sickle_hero(theme),
        self.switcher_panel(theme),
        row(
          [
            self.sickle_palette_panel(theme),
            self.sickle_typography_panel(theme),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
        row(
          [
            self.sickle_spacing_panel(theme),
            self.sickle_component_matrix_panel(theme),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
        self.customization_panel(theme),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    let tokens = self.tokens()
    let report = design_report_for(
      self.preset,
      scheme=tokens.scheme,
      system_scheme=self.scheme,
      density=self.density,
    )
    column(
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
  }
  container(
    scroll_view(content, width=920.0, height=620.0),
    width=960.0,
    height=680.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn DesignSystemsModel::hero(
  self : DesignSystemsModel,
  theme : @moui.Theme,
  report : @audit.DesignSystemReport,
) -> @moui.View[DesignSystemsMsg] {
  ignore(self)
  container(
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
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn DesignSystemsModel::sickle_hero(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
  ignore(self)
  container(
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
              "First-party Smartisan-inspired theme addon preview.",
              role=@views.TextRole::Caption,
              theme~,
              width=520.0,
              height=26.0,
            ).foreground(theme.palette.muted),
            text(
              "Sickle",
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
              "theme addon",
              tone=@views.BadgeTone::Accent,
              detail="Hybrid mode blends tactile depth with flat semantic controls.",
              theme~,
              width=138.0,
            ),
            status_badge(
              "first-party",
              tone=@views.BadgeTone::Success,
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
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn DesignSystemsModel::switcher_panel(
  self : DesignSystemsModel,
  theme : @moui.Theme,
) -> @moui.View[DesignSystemsMsg] {
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
          choice_item("sickle", "Sickle"),
        ],
        selected=design_preset_id(self.preset),
        on_select=id => SelectPreset(id),
        theme~,
        width=760.0,
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
  theme : @moui.Theme,
  tokens : @common.DesignSystemTokens,
  report : @audit.DesignSystemReport,
) -> @moui.View[DesignSystemsMsg] {
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
  theme : @moui.Theme,
  tokens : @common.DesignSystemTokens,
  report : @audit.DesignSystemReport,
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
  theme : @moui.Theme,
  tokens : @common.DesignSystemTokens,
) -> @moui.View[DesignSystemsMsg] {
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
  theme : @moui.Theme,
  tokens : @common.DesignSystemTokens,
) -> @moui.View[DesignSystemsMsg] {
  let styles = tokens.core_component_styles()
  let matrix = design_component_token_matrix(self.preset)
  let rows : Array[@moui.View[DesignSystemsMsg]] = [
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
    // Primary + tonal + outline + ghost button variants. The button resolves
    // its style from the ambient `ControlThemeSet.button` via `variant=`, so
    // a branded design system that sets `ControlThemeSet` once drives every
    // variant without per-control `style=` arguments.
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
    // Fluent 2 subtle / subtle-brand variants + underline text field. These
    // only differ structurally from the neutral defaults when the preset
    // supplies them (Fluent); other presets alias them to ghost/tonal.
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
          placeholder="Underline field",
          theme~,
          style=styles.text_field.filled,
          width=200.0,
          height=36.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
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
  design_panel(theme, "Component token matrix", rows, width=620.0, height=296.0)
}

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
