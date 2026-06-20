///|
pub(all) enum DesignTypographyRole {
  TypographyBody
  TypographyTitle
  TypographyCaption
  TypographyControl
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignTypographyRoleRecord {
  preset : @common.DesignPreset
  role : DesignTypographyRole
  token_surface : String
  core_surface : String
  official_token : String
  official_token_count : Int
  source_imported_count : Int
  runtime_aligned_count : Int
  runtime_destination_gap_count : Int
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  source_value : String
  expected_runtime_value : String
  token_size : Double
  core_size : Double
  token_weight : Int
  core_weight : Int
  token_family : String
  core_family : String
  resolves_core_surface : Bool
  required : Bool
  status : DesignTokenStatus
  remaining_gap : String
  note : String
} derive(Eq, Debug, ToJson)

///|
priv struct TypographySourceEvidence {
  official_token : String
  official_token_count : Int
  source_imported_count : Int
  runtime_aligned_count : Int
  runtime_destination_gap_count : Int
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  source_value : String
  expected_runtime_value : String
}

///|
pub fn DesignTypographyRole::label(preset : DesignTypographyRole) -> String {
  match preset {
    TypographyBody => "body"
    TypographyTitle => "title"
    TypographyCaption => "caption"
    TypographyControl => "control"
  }
}

///|
pub fn typography_role_report(
  preset : @common.DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[DesignTypographyRoleRecord] {
  [
    typography_role_record(preset, DesignTypographyRole::TypographyBody, scheme),
    typography_role_record(
      preset,
      DesignTypographyRole::TypographyTitle,
      scheme,
    ),
    typography_role_record(
      preset,
      DesignTypographyRole::TypographyCaption,
      scheme,
    ),
    typography_role_record(
      preset,
      DesignTypographyRole::TypographyControl,
      scheme,
    ),
  ]
}

///|
pub fn typography_role_for(
  preset : @common.DesignPreset,
  role : DesignTypographyRole,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> DesignTypographyRoleRecord? {
  for item in typography_role_report(preset, scheme~) {
    if item.role == role {
      return Some(item)
    }
  }
  None
}

///|
pub fn typography_role_count(preset : @common.DesignPreset) -> Int {
  typography_role_report(preset).length()
}

///|
pub fn typography_role_mapped_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    if item.resolves_core_surface && item.official_token_count > 0 {
      count = count + 1
    }
  }
  count
}

///|
pub fn typography_role_aligned_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    if item.runtime_aligned_count > 0 {
      count = count + 1
    }
  }
  count
}

///|
pub fn typography_role_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    if item.required &&
      (
        !item.resolves_core_surface ||
        item.status == DesignTokenStatus::NotMapped ||
        item.official_token_count == 0 ||
        item.source_imported_count == 0 ||
        item.runtime_aligned_count == 0 ||
        item.runtime_destination_gap_count > 0
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn typography_role_source_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    if item.required &&
      (
        item.official_token_count == 0 ||
        item.source_imported_count == 0 ||
        !item.source_declared ||
        !item.source_locked
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn typography_role_official_parity_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    if item.required && item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
pub fn typography_role_destination_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in typography_role_report(preset) {
    count = count + item.runtime_destination_gap_count
  }
  count
}

///|
fn typography_role_record(
  preset : @common.DesignPreset,
  role : DesignTypographyRole,
  scheme : @core.ColorScheme,
) -> DesignTypographyRoleRecord {
  let token_surface = typography_role_token_surface(role)
  let evidence = typography_source_evidence(preset, role)
  let tokens = preset.tokens(scheme~)
  let theme = tokens.to_theme()
  let token_font = typography_role_token_font(tokens, role)
  let core_font = typography_role_core_font(theme, role)
  let resolves_core_surface = token_font == core_font
  let status = typography_role_status(evidence, resolves_core_surface)
  {
    preset,
    role,
    token_surface,
    core_surface: typography_role_core_surface(role),
    official_token: evidence.official_token,
    official_token_count: evidence.official_token_count,
    source_imported_count: evidence.source_imported_count,
    runtime_aligned_count: evidence.runtime_aligned_count,
    runtime_destination_gap_count: evidence.runtime_destination_gap_count,
    source_declared: evidence.source_declared,
    source_label: evidence.source_label,
    source_kind: evidence.source_kind,
    source_ref: evidence.source_ref,
    token_path: evidence.token_path,
    source_locked: evidence.source_locked,
    source_value: evidence.source_value,
    expected_runtime_value: evidence.expected_runtime_value,
    token_size: token_font.size,
    core_size: core_font.size,
    token_weight: token_font.weight,
    core_weight: core_font.weight,
    token_family: token_font.css_family(),
    core_family: core_font.css_family(),
    resolves_core_surface,
    required: true,
    status,
    remaining_gap: typography_role_remaining_gap(
      role, evidence, resolves_core_surface,
    ),
    note: "Typography role resolves through @common.DesignTypographyTokens into a neutral @core.TypographyScale slot.",
  }
}

///|
fn typography_source_evidence(
  preset : @common.DesignPreset,
  role : DesignTypographyRole,
) -> TypographySourceEvidence {
  let surfaces = typography_role_token_members(role)
  let mut official_token = ""
  let mut official_token_count = 0
  let mut source_imported_count = 0
  let mut runtime_aligned_count = 0
  let mut runtime_destination_gap_count = 0
  let mut source_declared = false
  let mut source_label = ""
  let mut source_kind = ""
  let mut source_ref = ""
  let mut token_path = ""
  let mut source_locked = false
  let mut source_value = ""
  let mut expected_runtime_value = ""
  let mut selected_source_imported = false
  let mut selected_runtime_aligned = false
  for item in runtime_token_alignment_report(preset) {
    if surfaces.any(surface => surface == item.moui_token) {
      official_token_count = official_token_count + 1
      if item.source_imported {
        source_imported_count = source_imported_count + 1
      }
      if item.runtime_aligned {
        runtime_aligned_count = runtime_aligned_count + 1
      }
      if item.source_imported && !item.runtime_value_available {
        runtime_destination_gap_count = runtime_destination_gap_count + 1
      }
      if official_token == "" ||
        (!selected_runtime_aligned && item.runtime_aligned) ||
        (!selected_source_imported && item.source_imported) {
        official_token = item.official_token
        source_value = item.source_value
        expected_runtime_value = item.expected_runtime_value
        selected_source_imported = item.source_imported
        selected_runtime_aligned = item.runtime_aligned
        match official_token_coverage_for(preset, item.official_token) {
          Some(coverage) => {
            source_declared = coverage.source_declared
            source_label = coverage.source_label
            source_kind = coverage.source_kind
            source_ref = coverage.source_ref
            token_path = coverage.token_path
            source_locked = coverage.source_locked
          }
          None => {
            source_declared = false
            source_label = ""
            source_kind = ""
            source_ref = ""
            token_path = ""
            source_locked = false
          }
        }
      }
    }
  }
  if official_token == "" {
    match
      token_group_resolver_for(preset, DesignSystemRequirement::Typography) {
      Some(group) => {
        source_declared = group.source_declared
        source_label = group.source_label
        source_kind = group.source_kind
        source_ref = group.source_ref
        token_path = group.token_path
        source_locked = group.source_locked
      }
      None => ()
    }
  }
  {
    official_token,
    official_token_count,
    source_imported_count,
    runtime_aligned_count,
    runtime_destination_gap_count,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    source_value,
    expected_runtime_value,
  }
}

///|
fn typography_role_status(
  evidence : TypographySourceEvidence,
  resolves_core_surface : Bool,
) -> DesignTokenStatus {
  if !resolves_core_surface {
    DesignTokenStatus::NotMapped
  } else if evidence.runtime_aligned_count > 0 &&
    evidence.runtime_destination_gap_count == 0 {
    DesignTokenStatus::ThemeMapped
  } else if evidence.official_token_count > 0 ||
    evidence.source_imported_count > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::PreviewMapped
  }
}

///|
fn typography_role_remaining_gap(
  role : DesignTypographyRole,
  evidence : TypographySourceEvidence,
  resolves_core_surface : Bool,
) -> String {
  if !resolves_core_surface {
    "DesignTypographyTokens." +
    role.label() +
    " does not currently resolve to its neutral @core.TypographyScale slot."
  } else if evidence.official_token_count == 0 {
    "No role-level official typography token anchor maps directly to this typography role yet."
  } else if evidence.source_imported_count == 0 {
    "The role has official/golden typography anchors, but no pinned source-import record proves its values yet."
  } else if evidence.runtime_destination_gap_count > 0 {
    "Pinned typography source imports include properties such as line-height or alternate font families that MoUI does not expose as neutral typography destinations yet."
  } else if evidence.runtime_aligned_count == 0 {
    "The pinned typography source values are not aligned with the current default light typography role."
  } else {
    "none"
  }
}

///|
fn typography_role_token_surface(role : DesignTypographyRole) -> String {
  match role {
    TypographyBody => "DesignTypographyTokens.body"
    TypographyTitle => "DesignTypographyTokens.title"
    TypographyCaption => "DesignTypographyTokens.caption"
    TypographyControl => "DesignTypographyTokens.control"
  }
}

///|
fn typography_role_core_surface(role : DesignTypographyRole) -> String {
  match role {
    TypographyBody => "@core.TypographyScale.body"
    TypographyTitle => "@core.TypographyScale.title"
    TypographyCaption => "@core.TypographyScale.caption"
    TypographyControl => "@core.TypographyScale.control"
  }
}

///|
fn typography_role_token_members(role : DesignTypographyRole) -> Array[String] {
  let prefix = typography_role_token_surface(role)
  [
    prefix + ".size",
    prefix + ".weight",
    prefix + ".families",
    prefix + ".line_height",
  ]
}

///|
fn typography_role_token_font(
  tokens : @common.DesignSystemTokens,
  role : DesignTypographyRole,
) -> @core.FontSpec {
  match role {
    TypographyBody => tokens.typography.body
    TypographyTitle => tokens.typography.title
    TypographyCaption => tokens.typography.caption
    TypographyControl => tokens.typography.control
  }
}

///|
fn typography_role_core_font(
  theme : @core.Theme,
  role : DesignTypographyRole,
) -> @core.FontSpec {
  match role {
    TypographyBody => theme.typography.body
    TypographyTitle => theme.typography.title
    TypographyCaption => theme.typography.caption
    TypographyControl => theme.typography.control
  }
}
