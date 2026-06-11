///|
pub(all) enum DesignSemanticPaletteRole {
  PaletteForeground
  PaletteBackground
  PaletteSurface
  PaletteSurfaceVariant
  PalettePrimary
  PalettePrimaryForeground
  PaletteOutline
  PaletteMuted
  PaletteSuccess
  PaletteWarning
  PaletteDanger
  PaletteInfo
  PaletteFocus
  PaletteScrim
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSemanticPaletteRoleRecord {
  preset : DesignPreset
  role : DesignSemanticPaletteRole
  token_surface : String
  core_surface : String
  official_token : String
  official_token_count : Int
  source_imported_count : Int
  runtime_aligned_count : Int
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  source_value : String
  expected_runtime_value : String
  token_value : String
  core_value : String
  resolves_core_surface : Bool
  required : Bool
  status : DesignTokenStatus
  remaining_gap : String
  note : String
} derive(Eq, Debug, ToJson)

///|
priv struct SemanticPaletteSourceEvidence {
  official_token : String
  official_token_count : Int
  source_imported_count : Int
  runtime_aligned_count : Int
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
pub fn DesignSemanticPaletteRole::label(
  self : DesignSemanticPaletteRole,
) -> String {
  match self {
    PaletteForeground => "foreground"
    PaletteBackground => "background"
    PaletteSurface => "surface"
    PaletteSurfaceVariant => "surface variant"
    PalettePrimary => "primary"
    PalettePrimaryForeground => "primary foreground"
    PaletteOutline => "outline"
    PaletteMuted => "muted"
    PaletteSuccess => "success"
    PaletteWarning => "warning"
    PaletteDanger => "danger"
    PaletteInfo => "info"
    PaletteFocus => "focus"
    PaletteScrim => "scrim"
  }
}

///|
pub fn DesignPreset::semantic_palette_role_report(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[DesignSemanticPaletteRoleRecord] {
  [
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteForeground,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteBackground,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteSurface,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteSurfaceVariant,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PalettePrimary,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PalettePrimaryForeground,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteOutline,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteMuted,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteSuccess,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteWarning,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteDanger,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteInfo,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteFocus,
      scheme,
    ),
    semantic_palette_role_record(
      self,
      DesignSemanticPaletteRole::PaletteScrim,
      scheme,
    ),
  ]
}

///|
pub fn DesignPreset::semantic_palette_role_for(
  self : DesignPreset,
  role : DesignSemanticPaletteRole,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> DesignSemanticPaletteRoleRecord? {
  for item in self.semantic_palette_role_report(scheme~) {
    if item.role == role {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::semantic_palette_role_count(self : DesignPreset) -> Int {
  self.semantic_palette_role_report().length()
}

///|
pub fn DesignPreset::semantic_palette_role_mapped_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_role_report() {
    if item.resolves_core_surface && item.official_token_count > 0 {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::semantic_palette_role_aligned_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_role_report() {
    if item.runtime_aligned_count > 0 {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::semantic_palette_role_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_role_report() {
    if item.required &&
      (
        !item.resolves_core_surface ||
        item.status == DesignTokenStatus::NotMapped ||
        item.official_token_count == 0 ||
        item.source_imported_count == 0 ||
        item.runtime_aligned_count == 0
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::semantic_palette_role_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_role_report() {
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
pub fn DesignPreset::semantic_palette_role_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_role_report() {
    if item.required && item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn semantic_palette_role_record(
  preset : DesignPreset,
  role : DesignSemanticPaletteRole,
  scheme : @core.ColorScheme,
) -> DesignSemanticPaletteRoleRecord {
  let token_surface = semantic_palette_role_token_surface(role)
  let evidence = semantic_palette_source_evidence(preset, token_surface)
  let tokens = preset.tokens(scheme~)
  let theme = tokens.to_theme()
  let token_value = semantic_palette_role_token_value(tokens, role)
  let core_value = semantic_palette_role_core_value(theme, role)
  let resolves_core_surface = token_value == core_value
  let status = semantic_palette_role_status(evidence, resolves_core_surface)
  {
    preset,
    role,
    token_surface,
    core_surface: semantic_palette_role_core_surface(role),
    official_token: evidence.official_token,
    official_token_count: evidence.official_token_count,
    source_imported_count: evidence.source_imported_count,
    runtime_aligned_count: evidence.runtime_aligned_count,
    source_declared: evidence.source_declared,
    source_label: evidence.source_label,
    source_kind: evidence.source_kind,
    source_ref: evidence.source_ref,
    token_path: evidence.token_path,
    source_locked: evidence.source_locked,
    source_value: evidence.source_value,
    expected_runtime_value: evidence.expected_runtime_value,
    token_value,
    core_value,
    resolves_core_surface,
    required: true,
    status,
    remaining_gap: semantic_palette_role_remaining_gap(
      role, evidence, resolves_core_surface,
    ),
    note: "Semantic palette role resolves through DesignSemanticPalette into a neutral @core theme surface.",
  }
}

///|
fn semantic_palette_source_evidence(
  preset : DesignPreset,
  token_surface : String,
) -> SemanticPaletteSourceEvidence {
  let mut official_token = ""
  let mut official_token_count = 0
  let mut source_imported_count = 0
  let mut runtime_aligned_count = 0
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
  for item in preset.runtime_token_alignment_report() {
    if item.moui_token == token_surface {
      official_token_count = official_token_count + 1
      if item.source_imported {
        source_imported_count = source_imported_count + 1
      }
      if item.runtime_aligned {
        runtime_aligned_count = runtime_aligned_count + 1
      }
      if official_token == "" ||
        (!selected_runtime_aligned && item.runtime_aligned) ||
        (!selected_source_imported && item.source_imported) {
        official_token = item.official_token
        source_value = item.source_value
        expected_runtime_value = item.expected_runtime_value
        selected_source_imported = item.source_imported
        selected_runtime_aligned = item.runtime_aligned
        match preset.official_token_coverage_for(item.official_token) {
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
      preset.token_group_resolver_for(DesignSystemRequirement::SemanticPalette) {
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
fn semantic_palette_role_status(
  evidence : SemanticPaletteSourceEvidence,
  resolves_core_surface : Bool,
) -> DesignTokenStatus {
  if !resolves_core_surface {
    DesignTokenStatus::NotMapped
  } else if evidence.runtime_aligned_count > 0 {
    DesignTokenStatus::ThemeMapped
  } else if evidence.official_token_count > 0 ||
    evidence.source_imported_count > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::PreviewMapped
  }
}

///|
fn semantic_palette_role_remaining_gap(
  role : DesignSemanticPaletteRole,
  evidence : SemanticPaletteSourceEvidence,
  resolves_core_surface : Bool,
) -> String {
  if !resolves_core_surface {
    "DesignSemanticPalette." +
    role.label() +
    " does not currently resolve to its neutral @core theme surface."
  } else if evidence.official_token_count == 0 {
    "No role-level official token anchor maps directly to this semantic palette role yet."
  } else if evidence.source_imported_count == 0 {
    "The role has an official/golden anchor, but no pinned source-import record proves its value yet."
  } else if evidence.runtime_aligned_count == 0 {
    "The pinned source value is not aligned with the current default light semantic palette role."
  } else {
    "none"
  }
}

///|
fn semantic_palette_role_token_surface(
  role : DesignSemanticPaletteRole,
) -> String {
  match role {
    PaletteForeground => "DesignSemanticPalette.foreground"
    PaletteBackground => "DesignSemanticPalette.background"
    PaletteSurface => "DesignSemanticPalette.surface"
    PaletteSurfaceVariant => "DesignSemanticPalette.surface_variant"
    PalettePrimary => "DesignSemanticPalette.primary"
    PalettePrimaryForeground => "DesignSemanticPalette.primary_foreground"
    PaletteOutline => "DesignSemanticPalette.outline"
    PaletteMuted => "DesignSemanticPalette.muted"
    PaletteSuccess => "DesignSemanticPalette.success"
    PaletteWarning => "DesignSemanticPalette.warning"
    PaletteDanger => "DesignSemanticPalette.danger"
    PaletteInfo => "DesignSemanticPalette.info"
    PaletteFocus => "DesignSemanticPalette.focus"
    PaletteScrim => "DesignSemanticPalette.scrim"
  }
}

///|
fn semantic_palette_role_core_surface(
  role : DesignSemanticPaletteRole,
) -> String {
  match role {
    PaletteForeground => "@core.ColorPalette.foreground"
    PaletteBackground => "@core.ColorPalette.background"
    PaletteSurface => "@core.ColorPalette.surface"
    PaletteSurfaceVariant => "@core.ColorPalette.surface_variant"
    PalettePrimary => "@core.ColorPalette.primary"
    PalettePrimaryForeground => "@core.ColorPalette.primary_foreground"
    PaletteOutline => "@core.ColorPalette.outline"
    PaletteMuted => "@core.ColorPalette.muted"
    PaletteSuccess => "@core.SemanticColorScale.success"
    PaletteWarning => "@core.SemanticColorScale.warning"
    PaletteDanger => "@core.SemanticColorScale.danger"
    PaletteInfo => "@core.SemanticColorScale.info"
    PaletteFocus => "@core.SemanticColorScale.focus"
    PaletteScrim => "@core.SemanticColorScale.scrim"
  }
}

///|
fn semantic_palette_role_token_value(
  tokens : DesignSystemTokens,
  role : DesignSemanticPaletteRole,
) -> String {
  runtime_color_value(
    match role {
      PaletteForeground => tokens.palette.foreground
      PaletteBackground => tokens.palette.background
      PaletteSurface => tokens.palette.surface
      PaletteSurfaceVariant => tokens.palette.surface_variant
      PalettePrimary => tokens.palette.primary
      PalettePrimaryForeground => tokens.palette.primary_foreground
      PaletteOutline => tokens.palette.outline
      PaletteMuted => tokens.palette.muted
      PaletteSuccess => tokens.palette.success
      PaletteWarning => tokens.palette.warning
      PaletteDanger => tokens.palette.danger
      PaletteInfo => tokens.palette.info
      PaletteFocus => tokens.palette.focus
      PaletteScrim => tokens.palette.scrim
    },
  ).value
}

///|
fn semantic_palette_role_core_value(
  theme : @core.Theme,
  role : DesignSemanticPaletteRole,
) -> String {
  runtime_color_value(
    match role {
      PaletteForeground => theme.palette.foreground
      PaletteBackground => theme.palette.background
      PaletteSurface => theme.palette.surface
      PaletteSurfaceVariant => theme.palette.surface_variant
      PalettePrimary => theme.palette.primary
      PalettePrimaryForeground => theme.palette.primary_foreground
      PaletteOutline => theme.palette.outline
      PaletteMuted => theme.palette.muted
      PaletteSuccess => theme.semantic_colors.success
      PaletteWarning => theme.semantic_colors.warning
      PaletteDanger => theme.semantic_colors.danger
      PaletteInfo => theme.semantic_colors.info
      PaletteFocus => theme.semantic_colors.focus
      PaletteScrim => theme.semantic_colors.scrim
    },
  ).value
}
