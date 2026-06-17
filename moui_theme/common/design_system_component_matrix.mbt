///|
pub(all) struct DesignComponentTokenMatrixRecord {
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
  moui_surface : String
  mapped_token_count : Int
  required_token_count : Int
  source_imported_token_count : Int
  runtime_aligned_token_count : Int
  pending_token_family : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::component_token_matrix(
  self : DesignPreset,
) -> Array[DesignComponentTokenMatrixRecord] {
  match self {
    Material => material_component_token_matrix()
    Carbon => carbon_component_token_matrix()
    Primer => primer_component_token_matrix()
    Fluent => fluent_component_token_matrix()
  }
}

///|
pub fn DesignPreset::component_token_matrix_for(
  self : DesignPreset,
  component : String,
) -> DesignComponentTokenMatrixRecord? {
  for item in self.component_token_matrix() {
    if item.component == component {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::component_token_matrix_count(self : DesignPreset) -> Int {
  self.component_token_matrix().length()
}

///|
pub fn DesignPreset::component_token_matrix_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    if item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped ||
      item.mapped_token_count < item.required_token_count {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::component_token_matrix_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::component_token_matrix_mapped_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    count = count + item.mapped_token_count
  }
  count
}

///|
pub fn DesignPreset::component_token_matrix_required_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    count = count + item.required_token_count
  }
  count
}

///|
pub fn DesignPreset::component_token_matrix_source_imported_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    count = count + item.source_imported_token_count
  }
  count
}

///|
pub fn DesignPreset::component_token_matrix_runtime_aligned_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.component_token_matrix() {
    count = count + item.runtime_aligned_token_count
  }
  count
}

///|
fn material_component_token_matrix() -> Array[DesignComponentTokenMatrixRecord] {
  let source = "https://material-web.dev/theming/material-theming/"
  [
    matrix_record(
      DesignPreset::Material,
      "Button",
      "md filled/elevated/outlined/text button tokens",
      source,
      "@views.ButtonStyle",
      3,
      8,
      "state layers, disabled tokens, shape, elevation, and per-variant text/elevated button tokens",
      DesignTokenStatus::PreviewMapped,
      "Filled button container, label, and pressed state-layer tokens are mapped.",
    ),
    matrix_record(
      DesignPreset::Material,
      "TextField",
      "md text-field tokens",
      source,
      "@views.TextFieldStyle",
      1,
      6,
      "container, input, outline, label, supporting-text, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Focused border flows through the neutral focus token; full text-field matrix is pending.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Surface",
      "md surface/container roles",
      source,
      "@views.SurfaceStyle",
      2,
      6,
      "surface-container-low/high/highest and inverse surface roles",
      DesignTokenStatus::PreviewMapped,
      "Neutral base/raised/overlay surfaces map a subset of Material surface roles.",
    ),
    matrix_record(
      DesignPreset::Material,
      "ChoiceControl",
      "md checkbox/radio/switch tokens",
      source,
      "@views.ChoiceControlStyle",
      1,
      6,
      "selected, unselected, disabled, icon, track, and handle tokens",
      DesignTokenStatus::PreviewMapped,
      "Shared selected and disabled colors exist; component-specific control matrices are pending.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Progress",
      "md linear progress tokens",
      source,
      "@views.ProgressStyle",
      1,
      4,
      "track, active-indicator, stop-indicator, and shape tokens",
      DesignTokenStatus::PreviewMapped,
      "Active indicator color maps to the neutral progress foreground.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Slider",
      "md slider tokens",
      source,
      "@views.SliderStyle",
      1,
      7,
      "active/inactive track, handle, label, tick, focus, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Neutral slider foreground/thumb tokens exist; Material slider token import is pending.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Picker",
      "md menu/select tokens",
      source,
      "@views.PickerStyle",
      1,
      5,
      "menu container, list item, selected, focus, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Menu container color maps to the neutral picker background.",
    ),
    matrix_record(
      DesignPreset::Material,
      "DatePicker",
      "md date-picker tokens",
      source,
      "@views.PickerStyle",
      0,
      6,
      "date-picker container, day, selected, today, range, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "DatePicker currently reuses neutral picker tokens.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Feedback",
      "Material status/error roles",
      source,
      "@views.FeedbackStyle",
      1,
      5,
      "success, warning, info, error container, and on-container roles",
      DesignTokenStatus::PreviewMapped,
      "Error role maps to danger feedback; other status tone source import is pending.",
    ),
    matrix_record(
      DesignPreset::Material,
      "Badge",
      "Material badge tokens",
      source,
      "@views.BadgeStyle",
      0,
      5,
      "badge color, label, size, shape, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Badge tone tokens are generated from MoUI semantic palette roles.",
    ),
    matrix_record(
      DesignPreset::Material,
      "FormValidation",
      "Material supporting/error text roles",
      source,
      "@views.FormValidationStyle",
      1,
      4,
      "error, on-error, supporting text, and outline error tokens",
      DesignTokenStatus::PreviewMapped,
      "Error role maps to neutral validation foreground/border.",
    ),
  ]
}

///|
fn carbon_component_token_matrix() -> Array[DesignComponentTokenMatrixRecord] {
  let source = "https://carbondesignsystem.com/elements/color/tokens/"
  [
    matrix_record(
      DesignPreset::Carbon,
      "Button",
      "Carbon button tokens",
      source,
      "@views.ButtonStyle",
      1,
      7,
      "secondary, tertiary, danger, disabled, hover, active, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "$button-primary maps to the neutral primary button background.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "TextField",
      "Carbon field and border tokens",
      source,
      "@views.TextFieldStyle",
      2,
      7,
      "field background, text, placeholder, focus, disabled, invalid, and helper tokens",
      DesignTokenStatus::PreviewMapped,
      "$field and $border-interactive map to neutral field background/focus tokens.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Surface",
      "Carbon layer tokens",
      source,
      "@views.SurfaceStyle",
      1,
      5,
      "layer-01/02/03, layer-selected, and layer-hover tokens",
      DesignTokenStatus::PreviewMapped,
      "$layer-01 maps to the neutral surface role.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "ChoiceControl",
      "Carbon selection control tokens",
      source,
      "@views.ChoiceControlStyle",
      1,
      6,
      "icon, selected, unselected, disabled, focus, and hover tokens",
      DesignTokenStatus::PreviewMapped,
      "Interactive border/brand colors feed the shared choice-control selected color.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Progress",
      "Carbon progress indicator tokens",
      source,
      "@views.ProgressStyle",
      0,
      4,
      "active, track, indeterminate, and status tokens",
      DesignTokenStatus::PreviewMapped,
      "Progress currently derives from the Carbon primary semantic color.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Slider",
      "Carbon slider tokens",
      source,
      "@views.SliderStyle",
      1,
      6,
      "filled track, track, thumb, disabled, hover, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "$slider-filled-track maps to neutral slider foreground.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Picker",
      "Carbon field/menu tokens",
      source,
      "@views.PickerStyle",
      1,
      5,
      "field, menu background, option, selected, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "$field maps to the neutral picker background.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "DatePicker",
      "Carbon date picker tokens",
      source,
      "@views.PickerStyle",
      0,
      6,
      "calendar, day, selected, range, invalid, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "DatePicker currently reuses neutral picker tokens.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Feedback",
      "Carbon support/status tokens",
      source,
      "@views.FeedbackStyle",
      2,
      5,
      "success, warning, error, info, and inverse status tokens",
      DesignTokenStatus::PreviewMapped,
      "$support-success and $support-error map to neutral feedback tones.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "Badge",
      "Carbon tag/status tokens",
      source,
      "@views.BadgeStyle",
      0,
      5,
      "tag, label, status, disabled, and selected tokens",
      DesignTokenStatus::PreviewMapped,
      "Badge tone tokens are generated from MoUI semantic palette roles.",
    ),
    matrix_record(
      DesignPreset::Carbon,
      "FormValidation",
      "Carbon invalid field tokens",
      source,
      "@views.FormValidationStyle",
      1,
      4,
      "support-error, invalid border, helper text, and icon tokens",
      DesignTokenStatus::PreviewMapped,
      "$support-error maps to neutral validation foreground/border.",
    ),
  ]
}

///|
fn primer_component_token_matrix() -> Array[DesignComponentTokenMatrixRecord] {
  let source = "https://primer.style/product/primitives/color/"
  [
    matrix_record(
      DesignPreset::Primer,
      "Button",
      "Primer button tokens",
      source,
      "@views.ButtonStyle",
      1,
      7,
      "primary, secondary, danger, disabled, hover, active, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "--button-primary-bgColor-rest maps to the neutral primary button background.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "TextField",
      "Primer control border/background tokens",
      source,
      "@views.TextFieldStyle",
      2,
      7,
      "control background, border, text, placeholder, focus, disabled, and danger tokens",
      DesignTokenStatus::PreviewMapped,
      "--control-bgColor-rest and --control-borderColor-emphasis cover part of the neutral input matrix.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Surface",
      "Primer canvas/overlay tokens",
      source,
      "@views.SurfaceStyle",
      1,
      5,
      "canvas default, inset, overlay, border, and shadow tokens",
      DesignTokenStatus::PreviewMapped,
      "--bgColor-default maps to the neutral background/surface baseline.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "ChoiceControl",
      "Primer control selection tokens",
      source,
      "@views.ChoiceControlStyle",
      1,
      6,
      "selected, unselected, disabled, hover, focus, and danger control tokens",
      DesignTokenStatus::PreviewMapped,
      "Accent foreground feeds the neutral selected control color.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Progress",
      "Primer progress tokens",
      source,
      "@views.ProgressStyle",
      1,
      4,
      "progress foreground, background, size, and status tokens",
      DesignTokenStatus::PreviewMapped,
      "--progressBar-fgColor-accent maps to neutral progress foreground.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Slider",
      "Primer range/control tokens",
      source,
      "@views.SliderStyle",
      0,
      6,
      "track, fill, thumb, hover, focus, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Slider currently derives from the Primer accent semantic color.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Picker",
      "Primer select/control tokens",
      source,
      "@views.PickerStyle",
      1,
      5,
      "control background, overlay, option, selected, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "--control-bgColor-rest maps to neutral picker background.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "DatePicker",
      "Primer date picker tokens",
      source,
      "@views.PickerStyle",
      0,
      6,
      "calendar, day, selected, today, range, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "DatePicker currently reuses neutral picker tokens.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Feedback",
      "Primer status roles",
      source,
      "@views.FeedbackStyle",
      2,
      5,
      "success, danger, attention, accent, and severe tokens",
      DesignTokenStatus::PreviewMapped,
      "--fgColor-success and --fgColor-danger map to neutral feedback tones.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "Badge",
      "Primer label/status tokens",
      source,
      "@views.BadgeStyle",
      0,
      5,
      "label foreground, background, border, status, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Badge tone tokens are generated from MoUI semantic palette roles.",
    ),
    matrix_record(
      DesignPreset::Primer,
      "FormValidation",
      "Primer danger validation tokens",
      source,
      "@views.FormValidationStyle",
      1,
      4,
      "danger foreground, border, background, and helper tokens",
      DesignTokenStatus::PreviewMapped,
      "--fgColor-danger maps to neutral validation foreground/border.",
    ),
  ]
}

///|
fn fluent_component_token_matrix() -> Array[DesignComponentTokenMatrixRecord] {
  let source = "https://fluent2.microsoft.design/design-tokens"
  [
    matrix_record(
      DesignPreset::Fluent,
      "Button",
      "Fluent compound/button tokens",
      source,
      "@views.ButtonStyle",
      1,
      7,
      "brand, subtle, outline, disabled, hover, pressed, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "colorCompoundBrandBackground maps to neutral primary action background.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "TextField",
      "Fluent input field tokens",
      source,
      "@views.TextFieldStyle",
      1,
      7,
      "field background, foreground, placeholder, stroke, focus, disabled, and invalid tokens",
      DesignTokenStatus::PreviewMapped,
      "Neutral field tokens derive from Fluent foreground/background aliases.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Surface",
      "Fluent neutral background tokens",
      source,
      "@views.SurfaceStyle",
      1,
      5,
      "background 1/2/3/4 and overlay tokens",
      DesignTokenStatus::PreviewMapped,
      "colorNeutralBackground1 maps to the neutral background/surface baseline.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "ChoiceControl",
      "Fluent checkbox/radio/switch tokens",
      source,
      "@views.ChoiceControlStyle",
      1,
      6,
      "selected, unselected, disabled, hover, pressed, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "Brand background feeds the neutral selected control color.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Progress",
      "Fluent progress tokens",
      source,
      "@views.ProgressStyle",
      1,
      4,
      "bar, track, indeterminate, and status tokens",
      DesignTokenStatus::PreviewMapped,
      "ProgressBar.indicator.backgroundColor maps to neutral progress foreground.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Slider",
      "Fluent slider tokens",
      source,
      "@views.SliderStyle",
      0,
      6,
      "active rail, inactive rail, thumb, disabled, hover, and focus tokens",
      DesignTokenStatus::PreviewMapped,
      "Slider currently derives from the Fluent brand semantic color.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Picker",
      "Fluent menu/dropdown tokens",
      source,
      "@views.PickerStyle",
      1,
      5,
      "menu background, item, selected, hover, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "colorNeutralBackground1 maps to neutral picker background.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "DatePicker",
      "Fluent date picker tokens",
      source,
      "@views.PickerStyle",
      0,
      6,
      "calendar, day, selected, range, today, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "DatePicker currently reuses neutral picker tokens.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Feedback",
      "Fluent status aliases",
      source,
      "@views.FeedbackStyle",
      1,
      5,
      "success, warning, danger, info, and neutral status tokens",
      DesignTokenStatus::PreviewMapped,
      "Status tones derive from Fluent-style semantic palette values.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "Badge",
      "Fluent badge/status tokens",
      source,
      "@views.BadgeStyle",
      0,
      5,
      "badge fill, foreground, border, status, and disabled tokens",
      DesignTokenStatus::PreviewMapped,
      "Badge tone tokens are generated from MoUI semantic palette roles.",
    ),
    matrix_record(
      DesignPreset::Fluent,
      "FormValidation",
      "Fluent validation/error tokens",
      source,
      "@views.FormValidationStyle",
      1,
      4,
      "error foreground, stroke, background, and helper tokens",
      DesignTokenStatus::PreviewMapped,
      "Danger semantic color maps to neutral validation foreground/border.",
    ),
  ]
}

///|
fn matrix_record(
  preset : DesignPreset,
  component : String,
  official_scope : String,
  official_source : String,
  moui_surface : String,
  mapped_token_count : Int,
  required_token_count : Int,
  pending_token_family : String,
  status : DesignTokenStatus,
  note : String,
) -> DesignComponentTokenMatrixRecord {
  let source = component_matrix_source_for_url(preset, official_source)
  let source_imported_token_count = component_matrix_source_imported_count_for(
    preset, component,
  )
  let runtime_aligned_token_count = component_matrix_runtime_aligned_count_for(
    preset, component,
  )
  let (
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
  ) = match source {
    Some(source) =>
      (
        true,
        source.label,
        source.source_kind,
        source.source_ref,
        source.token_path,
        component_matrix_source_locked(source),
      )
    None => (false, "", "", "", "", false)
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
    moui_surface,
    mapped_token_count,
    required_token_count,
    source_imported_token_count,
    runtime_aligned_token_count,
    pending_token_family,
    status,
    note,
  }
}

///|
fn component_matrix_source_for_url(
  preset : DesignPreset,
  url : String,
) -> DesignSystemSource? {
  for source in preset.sources() {
    if source.url == url {
      return Some(source)
    }
  }
  None
}

///|
fn component_matrix_source_imported_count_for(
  preset : DesignPreset,
  component : String,
) -> Int {
  match preset {
    Material =>
      match component {
        "Button" => 3
        "Surface" => 5
        "Progress" => 1
        "Picker" => 1
        "Feedback" => 2
        "FormValidation" => 2
        _ => 0
      }
    Carbon =>
      match component {
        "Button" => 1
        "TextField" => 2
        "Surface" => 8
        "Slider" => 1
        "Picker" => 1
        "Feedback" => 6
        "FormValidation" => 2
        _ => 0
      }
    Primer =>
      match component {
        "Button" => 1
        "TextField" => 3
        "Surface" => 4
        "Progress" => 1
        "Picker" => 3
        "Feedback" => 3
        "FormValidation" => 1
        _ => 0
      }
    Fluent =>
      match component {
        "Button" => 1
        "TextField" => 4
        "Surface" => 8
        "Progress" => 1
        "Picker" => 1
        _ => 0
      }
  }
}

///|
fn component_matrix_runtime_aligned_count_for(
  preset : DesignPreset,
  component : String,
) -> Int {
  match preset {
    Material =>
      match component {
        "Button" => 3
        "Surface" => 5
        "Progress" => 1
        "Picker" => 1
        "Feedback" => 1
        "FormValidation" => 1
        _ => 0
      }
    Carbon =>
      match component {
        "Button" => 1
        "TextField" => 2
        "Surface" => 5
        "Slider" => 1
        "Picker" => 1
        "Feedback" => 4
        "FormValidation" => 1
        _ => 0
      }
    Primer =>
      match component {
        "TextField" => 1
        "Surface" => 4
        "Progress" => 1
        "Picker" => 1
        "Feedback" => 3
        "FormValidation" => 1
        _ => 0
      }
    Fluent =>
      match component {
        "Button" => 1
        "TextField" => 2
        "Surface" => 7
        "Progress" => 1
        "Picker" => 1
        _ => 0
      }
  }
}

///|
fn component_matrix_source_locked(source : DesignSystemSource) -> Bool {
  if source.status == DesignTokenStatus::NotMapped || source.source_ref == "" {
    false
  } else if source.source_kind == "official-source" ||
    source.source_kind == "internal-token-contract" ||
    source.source_kind == "internal-component-adapter" {
    source.token_path != ""
  } else {
    true
  }
}
