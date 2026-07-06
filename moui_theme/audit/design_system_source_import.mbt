///|
pub(all) struct DesignSourceImportedToken {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  token_name : String
  source_url : String
  source_ref : String
  token_path : String
  package_path : String
  source_file : String
  source_sha : String
  source_value : String
  moui_token : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSourceImportCoverage {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  required : Bool
  golden_mapped : Bool
  source_imported : Bool
  source_token : String
  source_file : String
  source_sha : String
  source_value : String
  moui_token : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSourceImportIntegrityRecord {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  source_token : String
  source_url : String
  source_ref : String
  token_path : String
  source_file : String
  source_declared : Bool
  source_locked : Bool
  source_file_scoped : Bool
  anchor_declared : Bool
  category_compatible : Bool
  layer_compatible : Bool
  golden_mapped : Bool
  golden_moui_token : String
  moui_token : String
  moui_token_matches_golden : Bool
  integrity_ok : Bool
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn source_imported_tokens(
  preset : @common.DesignPreset,
) -> Array[DesignSourceImportedToken] {
  match preset {
    Material => material_source_imported_tokens()
    Carbon => carbon_source_imported_tokens()
    Primer => primer_source_imported_tokens()
    Fluent => fluent_source_imported_tokens()
  }
}

///|
pub fn source_imported_token_count(preset : @common.DesignPreset) -> Int {
  source_imported_tokens(preset).length()
}

///|
pub fn source_import_integrity_report(
  preset : @common.DesignPreset,
) -> Array[DesignSourceImportIntegrityRecord] {
  let rows : Array[DesignSourceImportIntegrityRecord] = []
  for item in source_imported_tokens(preset) {
    rows.push(source_import_integrity_record(preset, item))
  }
  rows
}

///|
pub fn source_import_integrity_for(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignSourceImportIntegrityRecord? {
  for item in source_import_integrity_report(preset) {
    if item.official_token == official_token {
      return Some(item)
    }
  }
  None
}

///|
pub fn source_import_integrity_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_import_integrity_report(preset) {
    if !item.integrity_ok {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_manifest_lock_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_import_integrity_report(preset) {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_scope_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_import_integrity_report(preset) {
    if !item.source_file_scoped {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_anchor_mismatch_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_import_integrity_report(preset) {
    if !item.anchor_declared ||
      !item.category_compatible ||
      !item.layer_compatible {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_golden_mismatch_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_import_integrity_report(preset) {
    if !item.moui_token_matches_golden {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_imported_token_mapped_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_imported_tokens(preset) {
    if item.status == DesignTokenStatus::ThemeMapped ||
      item.status == DesignTokenStatus::ComponentMapped ||
      item.status == DesignTokenStatus::OfficialComplete {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_imported_token_source_lock_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_imported_tokens(preset) {
    if item.source_ref == "" ||
      item.token_path == "" ||
      item.source_file == "" ||
      item.source_sha == "" {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_imported_token_for(
  preset : @common.DesignPreset,
  token_name : String,
) -> DesignSourceImportedToken? {
  for item in source_imported_tokens(preset) {
    if item.token_name == token_name {
      return Some(item)
    }
  }
  None
}

///|
pub fn source_import_coverage(
  preset : @common.DesignPreset,
) -> Array[DesignSourceImportCoverage] {
  let rows : Array[DesignSourceImportCoverage] = []
  for anchor in official_token_anchors(preset) {
    rows.push(build_source_import_coverage(preset, anchor))
  }
  rows
}

///|
pub fn source_import_coverage_count(preset : @common.DesignPreset) -> Int {
  source_import_coverage(preset).length()
}

///|
pub fn source_imported_official_token_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_import_coverage(preset) {
    if item.required && item.source_imported {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_coverage_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_import_coverage(preset) {
    if item.required && !item.source_imported {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_unanchored_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_imported_tokens(preset) {
    if !has_official_token_anchor(preset, item.official_token) {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_import_coverage_for(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignSourceImportCoverage? {
  for item in source_import_coverage(preset) {
    if item.official_token == official_token {
      return Some(item)
    }
  }
  None
}

///|
fn source_imported_token_count_for_package(
  preset : @common.DesignPreset,
  package_path : String,
) -> Int {
  let mut count = 0
  for item in source_imported_tokens(preset) {
    if item.package_path == package_path {
      count = count + 1
    }
  }
  count
}

///|
fn source_import_integrity_record(
  preset : @common.DesignPreset,
  imported : DesignSourceImportedToken,
) -> DesignSourceImportIntegrityRecord {
  let source_lock = source_lock_for_imported_token(preset, imported)
  let anchor = official_anchor_for_imported_token(
    preset,
    imported.official_token,
  )
  let golden = golden_mapping_for(preset, imported.official_token)
  let (source_declared, source_locked, source_file_scoped) = match source_lock {
    Some(source) =>
      (
        true,
        source.stable_lock &&
        source.source_ref == imported.source_ref &&
        source.token_path == imported.token_path,
        imported.source_file.contains(source.token_path),
      )
    None => (false, false, false)
  }
  let (anchor_declared, category_compatible, layer_compatible) = match anchor {
    Some(anchor) =>
      (
        true,
        source_import_category_compatible(imported.category, anchor.category),
        source_import_layer_compatible(imported.layer, anchor.layer),
      )
    None => (false, false, false)
  }
  let (golden_mapped, golden_moui_token, moui_token_matches_golden) = match
    golden {
    Some(mapping) =>
      (true, mapping.moui_token, mapping.moui_token == imported.moui_token)
    None => (false, "", true)
  }
  let integrity_ok = source_declared &&
    source_locked &&
    source_file_scoped &&
    anchor_declared &&
    category_compatible &&
    layer_compatible &&
    moui_token_matches_golden
  {
    preset,
    category: imported.category,
    layer: imported.layer,
    official_token: imported.official_token,
    source_token: imported.token_name,
    source_url: imported.source_url,
    source_ref: imported.source_ref,
    token_path: imported.token_path,
    source_file: imported.source_file,
    source_declared,
    source_locked,
    source_file_scoped,
    anchor_declared,
    category_compatible,
    layer_compatible,
    golden_mapped,
    golden_moui_token,
    moui_token: imported.moui_token,
    moui_token_matches_golden,
    integrity_ok,
    status: if integrity_ok {
      imported.status
    } else {
      DesignTokenStatus::NotMapped
    },
    note: if integrity_ok {
      "Source import is tied to a stable manifest source lock, a compatible official anchor, and its golden mapping when one exists."
    } else {
      "Source import has a manifest source-lock, official-anchor, source-file scope, or golden destination mismatch."
    },
  }
}

///|
fn build_source_import_coverage(
  preset : @common.DesignPreset,
  anchor : DesignOfficialTokenAnchor,
) -> DesignSourceImportCoverage {
  let imported = source_imported_token_for_official_token(
    preset,
    anchor.official_token,
  )
  let golden = golden_mapping_for(preset, anchor.official_token)
  let golden_mapped = match golden {
    Some(_) => true
    None => false
  }
  match imported {
    Some(source_import) =>
      {
        preset,
        category: anchor.category,
        layer: anchor.layer,
        official_token: anchor.official_token,
        required: anchor.required,
        golden_mapped,
        source_imported: source_imported_token_locked(source_import),
        source_token: source_import.token_name,
        source_file: source_import.source_file,
        source_sha: source_import.source_sha,
        source_value: source_import.source_value,
        moui_token: source_import.moui_token,
        status: source_import.status,
        note: source_import.note,
      }
    None =>
      {
        preset,
        category: anchor.category,
        layer: anchor.layer,
        official_token: anchor.official_token,
        required: anchor.required,
        golden_mapped,
        source_imported: false,
        source_token: "",
        source_file: "",
        source_sha: "",
        source_value: "",
        moui_token: match golden {
          Some(mapping) => mapping.moui_token
          None => ""
        },
        status: DesignTokenStatus::NotMapped,
        note: "No pinned source-import token record covers this official token anchor yet.",
      }
  }
}

///|
fn source_lock_for_imported_token(
  preset : @common.DesignPreset,
  imported : DesignSourceImportedToken,
) -> DesignSourceLockRecord? {
  for source in source_lock_report(preset) {
    if source.source_url == imported.source_url &&
      source.source_ref == imported.source_ref &&
      source.token_path == imported.token_path {
      return Some(source)
    }
  }
  None
}

///|
fn official_anchor_for_imported_token(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignOfficialTokenAnchor? {
  for anchor in official_token_anchors(preset) {
    if anchor.official_token == official_token {
      return Some(anchor)
    }
  }
  None
}

///|
fn source_import_category_compatible(
  source_category : DesignTokenCategory,
  anchor_category : DesignTokenCategory,
) -> Bool {
  source_category == anchor_category ||
  (
    source_category == DesignTokenCategory::Color &&
    (
      anchor_category == DesignTokenCategory::Surface ||
      anchor_category == DesignTokenCategory::StateLayer ||
      anchor_category == DesignTokenCategory::ComponentStyle
    )
  )
}

///|
fn source_import_layer_compatible(
  source_layer : DesignTokenLayer,
  anchor_layer : DesignTokenLayer,
) -> Bool {
  source_layer == anchor_layer ||
  (
    source_layer == DesignTokenLayer::ReferenceToken &&
    (
      anchor_layer == DesignTokenLayer::AliasToken ||
      anchor_layer == DesignTokenLayer::SystemToken ||
      anchor_layer == DesignTokenLayer::ComponentToken
    )
  ) ||
  (
    source_layer == DesignTokenLayer::AliasToken &&
    anchor_layer == DesignTokenLayer::ComponentToken
  )
}

///|
fn source_imported_token_for_official_token(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignSourceImportedToken? {
  for item in source_imported_tokens(preset) {
    if item.official_token == official_token {
      return Some(item)
    }
  }
  None
}

///|
fn source_imported_token_locked(item : DesignSourceImportedToken) -> Bool {
  item.source_ref != "" &&
  item.token_path != "" &&
  item.source_file != "" &&
  item.source_sha != "" &&
  item.source_value != ""
}

///|
fn imported_token(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
  layer : DesignTokenLayer,
  token_name : String,
  source_url : String,
  source_ref : String,
  token_path : String,
  package_path : String,
  source_file : String,
  source_sha : String,
  source_value : String,
  moui_token : String,
  status : DesignTokenStatus,
  note : String,
  official_token? : String = "",
) -> DesignSourceImportedToken {
  let official_token = if official_token == "" {
    token_name
  } else {
    official_token
  }
  {
    preset,
    category,
    layer,
    official_token,
    token_name,
    source_url,
    source_ref,
    token_path,
    package_path,
    source_file,
    source_sha,
    source_value,
    moui_token,
    status,
    note,
  }
}
