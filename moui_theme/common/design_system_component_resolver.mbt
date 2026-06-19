///|
pub(all) struct DesignComponentStyleResolverRecord {
  preset : DesignPreset
  component : String
  official_scope : String
  official_source : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  token_surface : String
  core_style_surface : String
  tokens_api : String
  style_api : String
  scheme : @core.ColorScheme
  resolves_tokens : Bool
  resolves_core_style : Bool
  status : DesignTokenStatus
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::component_style_resolver_report(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[DesignComponentStyleResolverRecord] {
  [
    component_style_resolver_record(self, "Button", scheme),
    component_style_resolver_record(self, "TextField", scheme),
    component_style_resolver_record(self, "Surface", scheme),
    component_style_resolver_record(self, "ChoiceControl", scheme),
    component_style_resolver_record(self, "Progress", scheme),
    component_style_resolver_record(self, "Slider", scheme),
    component_style_resolver_record(self, "Picker", scheme),
    component_style_resolver_record(self, "DatePicker", scheme),
    component_style_resolver_record(self, "Feedback", scheme),
    component_style_resolver_record(self, "Badge", scheme),
    component_style_resolver_record(self, "FormValidation", scheme),
  ]
}

///|
pub fn DesignPreset::component_style_resolver_for(
  self : DesignPreset,
  component : String,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> DesignComponentStyleResolverRecord? {
  for item in self.component_style_resolver_report(scheme~) {
    if item.component == component {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::component_style_resolver_count(self : DesignPreset) -> Int {
  self.component_style_resolver_report().length()
}

///|
pub fn DesignPreset::component_style_resolver_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_style_resolver_report() {
    if !item.resolves_tokens ||
      !item.resolves_core_style ||
      item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::component_style_resolver_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_style_resolver_report() {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::component_style_resolver_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_style_resolver_report() {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn component_style_resolver_record(
  preset : DesignPreset,
  component : String,
  scheme : @core.ColorScheme,
) -> DesignComponentStyleResolverRecord {
  let matrix = preset.component_token_matrix_for(component)
  let (
    official_scope,
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    core_style_surface,
    remaining_gap,
  ) = match matrix {
    Some(item) =>
      (
        item.official_scope,
        item.official_source,
        item.source_declared,
        item.source_label,
        item.source_kind,
        item.source_ref,
        item.token_path,
        item.source_locked,
        item.moui_surface,
        if item.pending_token_family == "none" {
          "none"
        } else {
          item.pending_token_family
        },
      )
    None =>
      (
        "", "", false, "", "", "", "", false, "", "Missing component matrix row.",
      )
  }
  let tokens = preset.tokens(scheme~)
  let resolves_tokens = component_tokens_resolve(tokens, component)
  let resolves_core_style = component_core_style_resolves(tokens, component)
  let status = if !source_declared ||
    !source_locked ||
    !resolves_tokens ||
    !resolves_core_style {
    DesignTokenStatus::NotMapped
  } else {
    DesignTokenStatus::ComponentMapped
  }
  {
    preset,
    component,
    official_scope,
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    token_surface: component_token_surface(component),
    core_style_surface,
    tokens_api: "DesignPreset::tokens(...).components",
    style_api: component_style_api(component),
    scheme,
    resolves_tokens,
    resolves_core_style,
    status,
    remaining_gap,
  }
}

///|
fn component_tokens_resolve(
  tokens : DesignSystemTokens,
  component : String,
) -> Bool {
  match component {
    "Button" =>
      tokens.components.button.primary.background == tokens.palette.primary &&
      tokens.components.button.primary.radius == tokens.radius.md &&
      tokens.components.button.outline.border_width == 1.0
    "TextField" =>
      tokens.components.text_field.normal.background == tokens.palette.surface &&
      (
        // Neutral presets bind the focused border to `palette.focus`; Fluent 2
        // binds it to the separate `brand_stroke` token.
        tokens.components.text_field.focused.border == tokens.palette.focus ||
        tokens.components.text_field.focused.border == tokens.palette.brand_stroke
      ) &&
      tokens.components.text_field.cursor == tokens.palette.focus &&
      tokens.components.text_field.font == tokens.typography.body
    "Surface" =>
      tokens.components.surface.base_padding == tokens.spacing.md &&
      tokens.components.surface.raised_padding == tokens.spacing.lg &&
      tokens.components.surface.base_radius == tokens.radius.md
    "ChoiceControl" =>
      tokens.components.choice_control.selected_color == tokens.palette.primary
    "Progress" =>
      tokens.components.progress.foreground == tokens.palette.primary &&
      tokens.components.progress.radius == tokens.radius.pill
    "Slider" =>
      (
        tokens.components.slider.foreground == tokens.palette.primary ||
        (
          tokens.preset == DesignPreset::Carbon &&
          tokens.scheme == @core.ColorScheme::Light &&
          tokens.components.slider.foreground == tokens.palette.foreground
        )
      ) &&
      tokens.components.slider.thumb_color == tokens.palette.primary
    "Picker" =>
      tokens.components.picker.foreground == tokens.palette.foreground &&
      tokens.components.picker.radius == tokens.radius.md
    "DatePicker" =>
      tokens.components.date_picker.foreground == tokens.palette.foreground &&
      tokens.components.date_picker.radius == tokens.radius.md
    "Feedback" =>
      tokens.components.feedback.success.foreground == tokens.palette.success &&
      tokens.components.feedback.padding == tokens.spacing.sm
    "Badge" =>
      tokens.components.badge.danger.background == tokens.palette.danger &&
      tokens.components.badge.radius == tokens.radius.pill
    "FormValidation" =>
      tokens.components.form_validation.foreground == tokens.palette.danger &&
      tokens.components.form_validation.padding == tokens.spacing.md
    _ => false
  }
}

///|
fn component_core_style_resolves(
  tokens : DesignSystemTokens,
  component : String,
) -> Bool {
  let styles = tokens.core_component_styles()
  match component {
    "Button" =>
      styles.button.primary.normal.foreground ==
      tokens.components.button.primary.foreground &&
      styles.button.primary.normal.background ==
      @core.Brush::solid(tokens.components.button.primary.background) &&
      styles.button.primary.normal.radius ==
      tokens.components.button.primary.radius &&
      styles.button.primary.disabled.foreground ==
      tokens.components.button.primary.foreground.multiply_alpha(
        tokens.state_layer.disabled_alpha,
      ) &&
      styles.button.tonal.normal.background ==
      @core.Brush::solid(tokens.components.button.tonal.background) &&
      styles.button.ghost.hovered.background ==
      @core.Brush::solid(
        tokens.state_layer.color.with_alpha(tokens.state_layer.hover_alpha),
      )
    "TextField" =>
      styles.text_field.filled.normal.foreground ==
      tokens.components.text_field.normal.foreground &&
      styles.text_field.filled.normal.background ==
      @core.Brush::solid(tokens.components.text_field.normal.background) &&
      styles.text_field.filled.placeholder_color ==
      tokens.components.text_field.placeholder &&
      styles.text_field.filled.cursor_color ==
      tokens.components.text_field.cursor &&
      styles.text_field.filled.font == tokens.components.text_field.font &&
      styles.text_field.plain.normal.background ==
      @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)) &&
      styles.text_field.plain.normal.border is None
    "Surface" =>
      styles.surface.base.radius == tokens.components.surface.base_radius &&
      styles.surface.base.padding ==
      @core.Insets::all(tokens.components.surface.base_padding) &&
      styles.surface.raised.radius == tokens.components.surface.raised_radius &&
      styles.surface.raised.padding ==
      @core.Insets::all(tokens.components.surface.raised_padding) &&
      styles.surface.overlay.level == @core.SurfaceLevel::Overlay
    "ChoiceControl" =>
      styles.choice_control == tokens.components.choice_control.core_style()
    "Progress" => styles.progress == tokens.components.progress.core_style()
    "Slider" =>
      styles.slider.foreground == tokens.components.slider.foreground &&
      styles.slider.background == tokens.components.slider.background &&
      styles.slider.thumb_color == tokens.components.slider.thumb_color &&
      styles.slider.track_height == tokens.components.slider.track_height &&
      styles.slider.thumb_size == tokens.components.slider.thumb_size &&
      styles.slider.radius == tokens.components.slider.radius
    "Picker" =>
      styles.picker.font == tokens.components.picker.font &&
      styles.picker.foreground == tokens.components.picker.foreground &&
      styles.picker.background == tokens.components.picker.background &&
      styles.picker.radius == tokens.components.picker.radius &&
      styles.picker.popup_max_height ==
      tokens.components.picker.popup_max_height
    "DatePicker" =>
      styles.date_picker.font == tokens.components.date_picker.font &&
      styles.date_picker.foreground == tokens.components.date_picker.foreground &&
      styles.date_picker.background == tokens.components.date_picker.background &&
      styles.date_picker.radius == tokens.components.date_picker.radius &&
      styles.date_picker.popup_max_height ==
      tokens.components.date_picker.popup_max_height
    "Feedback" => styles.feedback == tokens.components.feedback.core_style()
    "Badge" => styles.badge == tokens.components.badge.core_style()
    "FormValidation" =>
      styles.form_validation == tokens.components.form_validation.core_style()
    _ => false
  }
}

///|
fn component_token_surface(component : String) -> String {
  match component {
    "Button" => "DesignComponentTokens.button"
    "TextField" => "DesignComponentTokens.text_field"
    "Surface" => "DesignComponentTokens.surface"
    "ChoiceControl" => "DesignComponentTokens.choice_control"
    "Progress" => "DesignComponentTokens.progress"
    "Slider" => "DesignComponentTokens.slider"
    "Picker" => "DesignComponentTokens.picker"
    "DatePicker" => "DesignComponentTokens.date_picker"
    "Feedback" => "DesignComponentTokens.feedback"
    "Badge" => "DesignComponentTokens.badge"
    "FormValidation" => "DesignComponentTokens.form_validation"
    _ => ""
  }
}

///|
fn component_style_api(component : String) -> String {
  match component {
    "Button" => "DesignSystemTokens::core_component_styles().button"
    "TextField" => "DesignSystemTokens::core_component_styles().text_field"
    "Surface" => "DesignSystemTokens::core_component_styles().surface"
    "ChoiceControl" => "DesignChoiceControlTokens::core_style"
    "Progress" => "DesignProgressTokens::core_style"
    "Slider" => "DesignSliderTokens::core_style"
    "Picker" => "DesignPickerTokens::core_style"
    "DatePicker" => "DesignPickerTokens::core_style"
    "Feedback" => "DesignFeedbackTokens::core_style"
    "Badge" => "DesignBadgeTokens::core_style"
    "FormValidation" => "DesignFormValidationTokens::core_style"
    _ => ""
  }
}
