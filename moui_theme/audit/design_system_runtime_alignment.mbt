///|
pub(all) struct DesignRuntimeTokenAlignmentRecord {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  required : Bool
  source_imported : Bool
  source_token : String
  source_value : String
  moui_token : String
  source_value_resolved : Bool
  expected_runtime_value : String
  runtime_value_available : Bool
  runtime_value : String
  runtime_aligned : Bool
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn runtime_token_alignment_report(
  preset : @common.DesignPreset,
) -> Array[DesignRuntimeTokenAlignmentRecord] {
  let rows : Array[DesignRuntimeTokenAlignmentRecord] = []
  let tokens = preset.tokens(scheme=@core.ColorScheme::Light)
  for item in source_import_coverage(preset) {
    rows.push(runtime_token_alignment_record(preset, item, tokens))
  }
  rows
}

///|
pub fn runtime_token_alignment_for(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignRuntimeTokenAlignmentRecord? {
  for item in runtime_token_alignment_report(preset) {
    if item.official_token == official_token {
      return Some(item)
    }
  }
  None
}

///|
pub fn runtime_token_alignment_count(preset : @common.DesignPreset) -> Int {
  runtime_token_alignment_report(preset).length()
}

///|
pub fn runtime_token_aligned_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in runtime_token_alignment_report(preset) {
    if item.runtime_aligned {
      count = count + 1
    }
  }
  count
}

///|
pub fn runtime_token_alignment_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in runtime_token_alignment_report(preset) {
    if item.required && !item.runtime_aligned {
      count = count + 1
    }
  }
  count
}

///|
pub fn runtime_token_source_value_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in runtime_token_alignment_report(preset) {
    if item.required && item.source_imported && !item.source_value_resolved {
      count = count + 1
    }
  }
  count
}

///|
pub fn runtime_token_destination_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in runtime_token_alignment_report(preset) {
    if item.required && item.source_imported && !item.runtime_value_available {
      count = count + 1
    }
  }
  count
}

///|
fn runtime_token_alignment_record(
  preset : @common.DesignPreset,
  coverage : DesignSourceImportCoverage,
  tokens : @common.DesignSystemTokens,
) -> DesignRuntimeTokenAlignmentRecord {
  let expected = expected_runtime_token_value(coverage)
  let actual = actual_runtime_token_value(coverage.moui_token, tokens)
  let runtime_aligned = coverage.source_imported &&
    expected.available &&
    actual.available &&
    expected.value == actual.value
  let status = if runtime_aligned {
    coverage.status
  } else if !coverage.source_imported {
    DesignTokenStatus::NotMapped
  } else if !expected.available {
    DesignTokenStatus::PreviewMapped
  } else if !actual.available {
    DesignTokenStatus::NotMapped
  } else {
    DesignTokenStatus::PreviewMapped
  }
  {
    preset,
    category: coverage.category,
    layer: coverage.layer,
    official_token: coverage.official_token,
    required: coverage.required,
    source_imported: coverage.source_imported,
    source_token: coverage.source_token,
    source_value: coverage.source_value,
    moui_token: coverage.moui_token,
    source_value_resolved: expected.available,
    expected_runtime_value: expected.value,
    runtime_value_available: actual.available,
    runtime_value: actual.value,
    runtime_aligned,
    status,
    note: runtime_alignment_note(coverage, expected, actual, runtime_aligned),
  }
}

///|
fn runtime_alignment_note(
  coverage : DesignSourceImportCoverage,
  expected : RuntimeTokenValue,
  actual : RuntimeTokenValue,
  runtime_aligned : Bool,
) -> String {
  if runtime_aligned {
    "Resolved official source value matches the default light @common.DesignSystemTokens runtime value."
  } else if !coverage.source_imported {
    "No pinned source-import record covers this required official token anchor yet."
  } else if !expected.available {
    "The pinned source import is symbolic or declarative; generated token import must resolve it before runtime alignment can be proven."
  } else if !actual.available {
    "The imported MoUI token destination is not exposed by the runtime alignment resolver yet."
  } else {
    "The resolved official source value differs from the current default light @common.DesignSystemTokens runtime value."
  }
}

///|
struct RuntimeTokenValue {
  available : Bool
  value : String
} derive(Eq, Debug, ToJson)

///|
fn expected_runtime_token_value(
  coverage : DesignSourceImportCoverage,
) -> RuntimeTokenValue {
  let source_value = coverage.source_value
  if source_value.contains("#242424") {
    runtime_color_value(@common.color_byte(r=36, g=36, b=36))
  } else if source_value.contains("#ffffff") {
    runtime_color_value(@core.Color::white())
  } else if source_value.contains("#fff") {
    runtime_color_value(@core.Color::white())
  } else if source_value.contains("#000000") || source_value.contains("#000") {
    runtime_color_value(@core.Color::black())
  } else if source_value.contains("#fef7ff") {
    runtime_color_value(@common.color_byte(r=254, g=247, b=255))
  } else if source_value.contains("#1d1b20") {
    runtime_color_value(@common.color_byte(r=29, g=27, b=32))
  } else if source_value.contains("#e7e0ec") {
    runtime_color_value(@common.color_byte(r=231, g=224, b=236))
  } else if source_value.contains("#f3edf7") {
    runtime_color_value(@common.color_byte(r=243, g=237, b=247))
  } else if source_value.contains("#79747e") {
    runtime_color_value(@common.color_byte(r=121, g=116, b=126))
  } else if source_value.contains("#49454f") {
    runtime_color_value(@common.color_byte(r=73, g=69, b=79))
  } else if source_value.contains("#6750a4") {
    runtime_color_value(@common.color_byte(r=103, g=80, b=164))
  } else if source_value.contains("#b3261e") {
    runtime_color_value(@common.color_byte(r=179, g=38, b=30))
  } else if source_value.contains("#f4f4f4") {
    runtime_color_value(@common.color_byte(r=244, g=244, b=244))
  } else if source_value.contains("#e0e0e0") {
    runtime_color_value(@common.color_byte(r=224, g=224, b=224))
  } else if source_value.contains("#161616") {
    runtime_color_value(@common.color_byte(r=22, g=22, b=22))
  } else if source_value.contains("#8d8d8d") {
    runtime_color_value(@common.color_byte(r=141, g=141, b=141))
  } else if source_value.contains("#525252") {
    runtime_color_value(@common.color_byte(r=82, g=82, b=82))
  } else if source_value.contains("#0f62fe") {
    runtime_color_value(@common.color_byte(r=15, g=98, b=254))
  } else if source_value.contains("#da1e28") {
    runtime_color_value(@common.color_byte(r=218, g=30, b=40))
  } else if source_value.contains("#24a148") {
    runtime_color_value(@common.color_byte(r=36, g=161, b=72))
  } else if source_value.contains("#f1c21b") {
    runtime_color_value(@common.color_byte(r=241, g=194, b=27))
  } else if source_value.contains("#0043ce") {
    runtime_color_value(@common.color_byte(r=0, g=67, b=206))
  } else if source_value.contains("rgba(black, 0.6)") {
    runtime_color_value(@common.color(r=0.0, g=0.0, b=0.0, a=0.6))
  } else if source_value.contains("rgba(0,0,0,0.4)") ||
    source_value.contains("rgba(0, 0, 0, 0.4)") {
    runtime_color_value(@common.color(r=0.0, g=0.0, b=0.0, a=0.4))
  } else if source_value.contains("#107c10") {
    runtime_color_value(@common.color_byte(r=16, g=124, b=16))
  } else if source_value.contains("#13a10e") {
    runtime_color_value(@common.color_byte(r=19, g=161, b=14))
  } else if source_value.contains("#d13438") {
    runtime_color_value(@common.color_byte(r=209, g=52, b=56))
  } else if source_value.contains("#c50f1f") {
    runtime_color_value(@common.color_byte(r=197, g=15, b=31))
  } else if source_value.contains("#da3b01") {
    runtime_color_value(@common.color_byte(r=218, g=59, b=1))
  } else if source_value.contains("#f7630c") {
    runtime_color_value(@common.color_byte(r=247, g=99, b=12))
  } else if source_value.contains("#fde300") {
    runtime_color_value(@common.color_byte(r=253, g=227, b=0))
  } else if source_value.contains("#eaa300") {
    runtime_color_value(@common.color_byte(r=234, g=163, b=0))
  } else if source_value.contains("#0f6cbd") {
    runtime_color_value(@common.color_byte(r=15, g=108, b=189))
  } else if source_value.contains("#0078d4") {
    runtime_color_value(@common.color_byte(r=0, g=120, b=212))
  } else if coverage.official_token == "ProgressBar.indicator.backgroundColor" &&
    source_value.contains("colorCompoundBrandBackground") {
    runtime_color_value(@common.color_byte(r=15, g=108, b=189))
  } else if source_value.contains("#fafafa") {
    runtime_color_value(@common.color_byte(r=250, g=250, b=250))
  } else if source_value.contains("#f5f5f5") {
    runtime_color_value(@common.color_byte(r=245, g=245, b=245))
  } else if source_value.contains("#d1d1d1") {
    runtime_color_value(@common.color_byte(r=209, g=209, b=209))
  } else if source_value.contains("#616161") {
    runtime_color_value(@common.color_byte(r=97, g=97, b=97))
  } else if source_value.contains("#1f2328") {
    runtime_color_value(@common.color_byte(r=31, g=35, b=40))
  } else if source_value.contains("#F6F8FA") || source_value.contains("#f6f8fa") {
    runtime_color_value(@common.color_byte(r=246, g=248, b=250))
  } else if source_value.contains("#0969da") {
    runtime_color_value(@common.color_byte(r=9, g=105, b=218))
  } else if source_value.contains("#C8D1DA") || source_value.contains("#c8d1da") {
    if source_value.contains("alpha: 0.4") {
      runtime_color_value(@common.color_byte(r=200, g=209, b=218, a=0.4))
    } else {
      runtime_color_value(@common.color_byte(r=200, g=209, b=218))
    }
  } else if source_value.contains("#D1D9E0") || source_value.contains("#d1d9e0") {
    runtime_color_value(@common.color_byte(r=209, g=217, b=224))
  } else if source_value.contains("#818B98") || source_value.contains("#818b98") {
    runtime_color_value(@common.color_byte(r=129, g=139, b=152))
  } else if source_value.contains("#59636E") || source_value.contains("#59636e") {
    runtime_color_value(@common.color_byte(r=89, g=99, b=110))
  } else if source_value.contains("#1a7f37") {
    runtime_color_value(@common.color_byte(r=26, g=127, b=55))
  } else if source_value.contains("#9a6700") {
    runtime_color_value(@common.color_byte(r=154, g=103, b=0))
  } else if source_value.contains("#1f883d") {
    runtime_color_value(@common.color_byte(r=31, g=136, b=61))
  } else if source_value.contains("#d1242f") {
    runtime_color_value(@common.color_byte(r=209, g=36, b=47))
  } else if source_value.contains("#cf222e") {
    runtime_color_value(@common.color_byte(r=207, g=34, b=46))
  } else if coverage.official_token == "--control-transparent-bgColor-hover" &&
    source_value.contains("alpha: 0.1") {
    runtime_double_value(0.1)
  } else if coverage.official_token == "$background-hover" &&
    source_value.contains("0.12") {
    runtime_double_value(0.12)
  } else if coverage.official_token ==
    "--md-filled-button-pressed-state-layer-opacity" &&
    source_value.contains("0.12") {
    runtime_double_value(0.12)
  } else if coverage.official_token == "--md-sys-typescale-body-medium-size" &&
    source_value.contains("0.875rem") {
    runtime_double_value(14.0)
  } else if coverage.official_token == "--md-sys-typescale-headline-small-size" &&
    source_value.contains("1.5rem") {
    runtime_double_value(24.0)
  } else if coverage.official_token == "--md-sys-typescale-body-small-size" &&
    source_value.contains("0.75rem") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--md-sys-typescale-label-large-size" &&
    source_value.contains("0.875rem") {
    runtime_double_value(14.0)
  } else if coverage.official_token == "$body-02" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "$productive-heading-03" {
    runtime_double_value(20.0)
  } else if coverage.official_token == "$caption-01" {
    runtime_double_value(12.0)
  } else if coverage.official_token == "$label-02" {
    runtime_double_value(14.0)
  } else if coverage.official_token == "--md-sys-shape-corner-medium" &&
    source_value.contains("12px") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--md-sys-elevation-level1" &&
    source_value.contains("level1") &&
    source_value.contains("1") {
    runtime_double_value(1.0)
  } else if coverage.official_token == "--md-sys-elevation-level3" &&
    source_value.contains("level3") &&
    source_value.contains("6") {
    runtime_double_value(6.0)
  } else if coverage.official_token == "--md-sys-elevation-level5" &&
    source_value.contains("level5") &&
    source_value.contains("12") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--md-sys-motion-duration-short4" &&
    source_value.contains("duration-short4") &&
    source_value.contains("200ms") {
    runtime_double_value(200.0)
  } else if coverage.official_token == "--md-sys-motion-duration-medium2" &&
    source_value.contains("duration-medium2") &&
    source_value.contains("300ms") {
    runtime_double_value(300.0)
  } else if coverage.official_token == "--md-sys-motion-duration-medium4" &&
    source_value.contains("duration-medium4") &&
    source_value.contains("400ms") {
    runtime_double_value(400.0)
  } else if coverage.official_token == "--md-sys-motion-easing-standard" &&
    source_value.contains("easing-standard") &&
    source_value.contains("cubic-bezier(0.2, 0, 0, 1)") {
    runtime_value("cubic-bezier(0.2,0,0,1)")
  } else if coverage.official_token == "--md-sys-motion-*" &&
    source_value.contains("duration-medium2") &&
    source_value.contains("300ms") {
    runtime_double_value(300.0)
  } else if coverage.official_token == "fontSizeBase100" {
    runtime_double_value(10.0)
  } else if coverage.official_token == "fontSizeBase200" {
    runtime_double_value(12.0)
  } else if coverage.official_token == "fontSizeBase300" {
    runtime_double_value(14.0)
  } else if coverage.official_token == "fontSizeBase400" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "fontSizeBase500" {
    runtime_double_value(20.0)
  } else if coverage.official_token == "fontSizeBase600" {
    runtime_double_value(24.0)
  } else if coverage.official_token == "fontSizeHero700" {
    runtime_double_value(28.0)
  } else if coverage.official_token == "fontSizeHero800" {
    runtime_double_value(32.0)
  } else if coverage.official_token == "fontSizeHero900" {
    runtime_double_value(40.0)
  } else if coverage.official_token == "fontSizeHero1000" {
    runtime_double_value(68.0)
  } else if coverage.official_token == "lineHeightBase100" {
    runtime_double_value(14.0)
  } else if coverage.official_token == "lineHeightBase200" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "lineHeightBase300" {
    runtime_double_value(20.0)
  } else if coverage.official_token == "lineHeightBase400" {
    runtime_double_value(22.0)
  } else if coverage.official_token == "lineHeightBase500" {
    runtime_double_value(28.0)
  } else if coverage.official_token == "lineHeightBase600" {
    runtime_double_value(32.0)
  } else if coverage.official_token == "lineHeightHero700" {
    runtime_double_value(36.0)
  } else if coverage.official_token == "lineHeightHero800" {
    runtime_double_value(40.0)
  } else if coverage.official_token == "lineHeightHero900" {
    runtime_double_value(52.0)
  } else if coverage.official_token == "lineHeightHero1000" {
    runtime_double_value(92.0)
  } else if coverage.official_token == "fontWeightRegular" {
    runtime_int_value(400)
  } else if coverage.official_token == "fontWeightMedium" {
    runtime_int_value(500)
  } else if coverage.official_token == "fontWeightSemibold" {
    runtime_int_value(600)
  } else if coverage.official_token == "fontWeightBold" {
    runtime_int_value(700)
  } else if coverage.official_token == "fontFamilyBase" {
    runtime_value(
      "'Segoe UI', 'Segoe UI Web (West European)', -apple-system, BlinkMacSystemFont, Roboto, 'Helvetica Neue', sans-serif",
    )
  } else if coverage.official_token == "fontFamilyMonospace" {
    runtime_value("Consolas, 'Courier New', Courier, monospace")
  } else if coverage.official_token == "fontFamilyNumeric" {
    runtime_value(
      "Bahnschrift, 'Segoe UI', 'Segoe UI Web (West European)', -apple-system, BlinkMacSystemFont, Roboto, 'Helvetica Neue', sans-serif",
    )
  } else if coverage.official_token == "strokeWidthThin" {
    runtime_double_value(1.0)
  } else if coverage.official_token == "strokeWidthThick" {
    runtime_double_value(2.0)
  } else if coverage.official_token == "strokeWidthThicker" {
    runtime_double_value(3.0)
  } else if coverage.official_token == "strokeWidthThickest" {
    runtime_double_value(4.0)
  } else if coverage.official_token == "borderRadiusNone" {
    runtime_double_value(0.0)
  } else if coverage.official_token == "borderRadiusSmall" {
    runtime_double_value(2.0)
  } else if coverage.official_token == "borderRadiusMedium" {
    runtime_double_value(4.0)
  } else if coverage.official_token == "borderRadiusLarge" {
    runtime_double_value(6.0)
  } else if coverage.official_token == "borderRadiusXLarge" {
    runtime_double_value(8.0)
  } else if coverage.official_token == "borderRadius2XLarge" {
    runtime_double_value(12.0)
  } else if coverage.official_token == "borderRadius3XLarge" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "borderRadius4XLarge" {
    runtime_double_value(24.0)
  } else if coverage.official_token == "borderRadius5XLarge" {
    runtime_double_value(32.0)
  } else if coverage.official_token == "borderRadius6XLarge" {
    runtime_double_value(40.0)
  } else if coverage.official_token == "borderRadiusCircular" {
    runtime_double_value(10000.0)
  } else if coverage.official_token == "--borderRadius-small" &&
    source_value.contains("value: 3") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(3.0)
  } else if coverage.official_token == "--borderRadius-medium" &&
    source_value.contains("value: 6") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(6.0)
  } else if coverage.official_token == "--borderRadius-large" &&
    source_value.contains("value: 12") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--borderRadius-full" &&
    source_value.contains("value: 9999") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(9999.0)
  } else if coverage.official_token == "--borderRadius-default" &&
    source_value.contains("borderRadius.medium") {
    runtime_double_value(6.0)
  } else if coverage.official_token == "--shadow-resting-small" &&
    source_value.contains("offsetY: 1") {
    runtime_double_value(1.0)
  } else if coverage.official_token == "--shadow-resting-medium" &&
    source_value.contains("offsetY: 3") {
    runtime_double_value(3.0)
  } else if coverage.official_token == "--shadow-floating-large" &&
    source_value.contains("offsetY: 40") {
    runtime_double_value(40.0)
  } else if coverage.official_token == "shadow4" &&
    source_value.contains("y: 2") {
    runtime_double_value(2.0)
  } else if coverage.official_token == "shadow16" &&
    source_value.contains("y: 8") {
    runtime_double_value(8.0)
  } else if coverage.official_token == "shadow64" &&
    source_value.contains("y: 32") {
    runtime_double_value(32.0)
  } else if coverage.official_token == "--base-size-4" &&
    source_value.contains("value: 4") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(4.0)
  } else if coverage.official_token == "--base-size-8" &&
    source_value.contains("value: 8") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(8.0)
  } else if coverage.official_token == "--base-size-12" &&
    source_value.contains("value: 12") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--base-size-16" &&
    source_value.contains("value: 16") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(16.0)
  } else if coverage.official_token == "--base-size-24" &&
    source_value.contains("value: 24") &&
    source_value.contains("unit: 'px'") {
    runtime_double_value(24.0)
  } else if coverage.official_token == "--base-text-size-xs" &&
    source_value.contains("value: 0.75") &&
    source_value.contains("unit: 'rem'") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "--base-text-size-sm" &&
    source_value.contains("value: 0.875") &&
    source_value.contains("unit: 'rem'") {
    runtime_double_value(14.0)
  } else if coverage.official_token == "--base-text-size-lg" &&
    source_value.contains("value: 1.25") &&
    source_value.contains("unit: 'rem'") {
    runtime_double_value(20.0)
  } else if coverage.official_token == "--base-text-weight-normal" &&
    source_value.contains("400") {
    runtime_int_value(400)
  } else if coverage.official_token == "--base-text-weight-semibold" &&
    source_value.contains("600") {
    runtime_int_value(600)
  } else if coverage.official_token == "--base-duration-0" &&
    source_value.contains("value: 0") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(0.0)
  } else if coverage.official_token == "--base-duration-50" &&
    source_value.contains("value: 50") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(50.0)
  } else if coverage.official_token == "--base-duration-100" &&
    source_value.contains("value: 100") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(100.0)
  } else if coverage.official_token == "--base-duration-200" &&
    source_value.contains("value: 200") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(200.0)
  } else if coverage.official_token == "--base-duration-300" &&
    source_value.contains("value: 300") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(300.0)
  } else if coverage.official_token == "--base-duration-400" &&
    source_value.contains("value: 400") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(400.0)
  } else if coverage.official_token == "--base-duration-500" &&
    source_value.contains("value: 500") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(500.0)
  } else if coverage.official_token == "--base-duration-600" &&
    source_value.contains("value: 600") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(600.0)
  } else if coverage.official_token == "--base-duration-700" &&
    source_value.contains("value: 700") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(700.0)
  } else if coverage.official_token == "--base-duration-800" &&
    source_value.contains("value: 800") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(800.0)
  } else if coverage.official_token == "--base-duration-900" &&
    source_value.contains("value: 900") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(900.0)
  } else if coverage.official_token == "--base-duration-1000" &&
    source_value.contains("value: 1000") &&
    source_value.contains("unit: 'ms'") {
    runtime_double_value(1000.0)
  } else if coverage.official_token == "--base-easing-linear" &&
    source_value.contains("cubic-bezier(0,0,1,1)") {
    runtime_value("cubic-bezier(0,0,1,1)")
  } else if coverage.official_token == "--base-easing-ease" &&
    source_value.contains("cubic-bezier(0.25,0.1,0.25,1)") {
    runtime_value("cubic-bezier(0.25,0.1,0.25,1)")
  } else if coverage.official_token == "--base-easing-easeIn" &&
    source_value.contains("cubic-bezier(0.7,0.1,0.75,0.9)") {
    runtime_value("cubic-bezier(0.7,0.1,0.75,0.9)")
  } else if coverage.official_token == "--base-easing-easeOut" &&
    source_value.contains("cubic-bezier(0.3,0.8,0.6,1)") {
    runtime_value("cubic-bezier(0.3,0.8,0.6,1)")
  } else if coverage.official_token == "--base-easing-easeInOut" &&
    source_value.contains("cubic-bezier(0.6,0,0.2,1)") {
    runtime_value("cubic-bezier(0.6,0,0.2,1)")
  } else if coverage.official_token == "$spacing-01" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(0.25)") {
    runtime_double_value(2.0)
  } else if coverage.official_token == "$spacing-02" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(0.5)") {
    runtime_double_value(4.0)
  } else if coverage.official_token == "$spacing-03" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(1)") {
    runtime_double_value(8.0)
  } else if coverage.official_token == "$spacing-04" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(1.5)") {
    runtime_double_value(12.0)
  } else if coverage.official_token == "$spacing-05" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(2)") {
    runtime_double_value(16.0)
  } else if coverage.official_token == "$spacing-06" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(3)") {
    runtime_double_value(24.0)
  } else if coverage.official_token == "$spacing-07" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(4)") {
    runtime_double_value(32.0)
  } else if coverage.official_token == "$spacing-08" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(5)") {
    runtime_double_value(40.0)
  } else if coverage.official_token == "$spacing-09" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(6)") {
    runtime_double_value(48.0)
  } else if coverage.official_token == "$spacing-10" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(8)") {
    runtime_double_value(64.0)
  } else if coverage.official_token == "$spacing-11" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(10)") {
    runtime_double_value(80.0)
  } else if coverage.official_token == "$spacing-12" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(12)") {
    runtime_double_value(96.0)
  } else if coverage.official_token == "$spacing-13" &&
    source_value.contains("miniUnit = 8") &&
    source_value.contains("miniUnits(20)") {
    runtime_double_value(160.0)
  } else if coverage.official_token == "$duration-fast-01" &&
    source_value.contains("durationFast01") &&
    source_value.contains("70ms") {
    runtime_double_value(70.0)
  } else if coverage.official_token == "$duration-fast-02" &&
    source_value.contains("durationFast02") &&
    source_value.contains("110ms") {
    runtime_double_value(110.0)
  } else if coverage.official_token == "$duration-moderate-01" &&
    source_value.contains("durationModerate01") &&
    source_value.contains("150ms") {
    runtime_double_value(150.0)
  } else if coverage.official_token == "$duration-moderate-02" &&
    source_value.contains("durationModerate02") &&
    source_value.contains("240ms") {
    runtime_double_value(240.0)
  } else if coverage.official_token == "$duration-slow-01" &&
    source_value.contains("durationSlow01") &&
    source_value.contains("400ms") {
    runtime_double_value(400.0)
  } else if coverage.official_token == "$duration-slow-02" &&
    source_value.contains("durationSlow02") &&
    source_value.contains("700ms") {
    runtime_double_value(700.0)
  } else if coverage.official_token == "easings.standard.productive" &&
    source_value.contains("cubic-bezier(0.2, 0, 0.38, 0.9)") {
    runtime_value("cubic-bezier(0.2,0,0.38,0.9)")
  } else if coverage.official_token == "easings.standard.expressive" &&
    source_value.contains("cubic-bezier(0.4, 0.14, 0.3, 1)") {
    runtime_value("cubic-bezier(0.4,0.14,0.3,1)")
  } else if coverage.official_token == "easings.entrance.productive" &&
    source_value.contains("cubic-bezier(0, 0, 0.38, 0.9)") {
    runtime_value("cubic-bezier(0,0,0.38,0.9)")
  } else if coverage.official_token == "easings.entrance.expressive" &&
    source_value.contains("cubic-bezier(0, 0, 0.3, 1)") {
    runtime_value("cubic-bezier(0,0,0.3,1)")
  } else if coverage.official_token == "easings.exit.productive" &&
    source_value.contains("cubic-bezier(0.2, 0, 1, 0.9)") {
    runtime_value("cubic-bezier(0.2,0,1,0.9)")
  } else if coverage.official_token == "easings.exit.expressive" &&
    source_value.contains("cubic-bezier(0.4, 0.14, 1, 1)") {
    runtime_value("cubic-bezier(0.4,0.14,1,1)")
  } else if coverage.official_token == "spacingHorizontalNone" {
    runtime_double_value(0.0)
  } else if coverage.official_token == "spacingHorizontalXXS" {
    runtime_double_value(2.0)
  } else if coverage.official_token == "spacingHorizontalXS" {
    runtime_double_value(4.0)
  } else if coverage.official_token == "spacingHorizontalSNudge" {
    runtime_double_value(6.0)
  } else if coverage.official_token == "spacingHorizontalS" {
    runtime_double_value(8.0)
  } else if coverage.official_token == "spacingHorizontalMNudge" {
    runtime_double_value(10.0)
  } else if coverage.official_token == "spacingHorizontalM" {
    runtime_double_value(12.0)
  } else if coverage.official_token == "spacingHorizontalL" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "spacingHorizontalXL" {
    runtime_double_value(20.0)
  } else if coverage.official_token == "spacingHorizontalXXL" {
    runtime_double_value(24.0)
  } else if coverage.official_token == "spacingHorizontalXXXL" {
    runtime_double_value(32.0)
  } else if coverage.official_token == "spacingVerticalNone" {
    runtime_double_value(0.0)
  } else if coverage.official_token == "spacingVerticalXXS" {
    runtime_double_value(2.0)
  } else if coverage.official_token == "spacingVerticalXS" {
    runtime_double_value(4.0)
  } else if coverage.official_token == "spacingVerticalSNudge" {
    runtime_double_value(6.0)
  } else if coverage.official_token == "spacingVerticalS" {
    runtime_double_value(8.0)
  } else if coverage.official_token == "spacingVerticalMNudge" {
    runtime_double_value(10.0)
  } else if coverage.official_token == "spacingVerticalM" {
    runtime_double_value(12.0)
  } else if coverage.official_token == "spacingVerticalL" {
    runtime_double_value(16.0)
  } else if coverage.official_token == "spacingVerticalXL" {
    runtime_double_value(20.0)
  } else if coverage.official_token == "spacingVerticalXXL" {
    runtime_double_value(24.0)
  } else if coverage.official_token == "spacingVerticalXXXL" {
    runtime_double_value(32.0)
  } else if coverage.official_token == "durationUltraFast" {
    runtime_double_value(50.0)
  } else if coverage.official_token == "durationFaster" {
    runtime_double_value(100.0)
  } else if coverage.official_token == "durationFast" {
    runtime_double_value(150.0)
  } else if coverage.official_token == "durationNormal" {
    runtime_double_value(150.0)
  } else if coverage.official_token == "durationGentle" {
    runtime_double_value(200.0)
  } else if coverage.official_token == "durationSlow" {
    runtime_double_value(250.0)
  } else if coverage.official_token == "durationSlower" {
    runtime_double_value(400.0)
  } else if coverage.official_token == "durationUltraSlow" {
    runtime_double_value(500.0)
  } else if coverage.official_token == "curveAccelerateMax" {
    runtime_value("cubic-bezier(0.9,0.1,1,0.2)")
  } else if coverage.official_token == "curveAccelerateMid" {
    runtime_value("cubic-bezier(1,0,1,1)")
  } else if coverage.official_token == "curveAccelerateMin" {
    runtime_value("cubic-bezier(0.8,0,0.78,1)")
  } else if coverage.official_token == "curveDecelerateMax" {
    runtime_value("cubic-bezier(0.1,0.9,0.2,1)")
  } else if coverage.official_token == "curveDecelerateMid" {
    runtime_value("cubic-bezier(0,0,0,1)")
  } else if coverage.official_token == "curveDecelerateMin" {
    runtime_value("cubic-bezier(0.33,0,0.1,1)")
  } else if coverage.official_token == "curveEasyEaseMax" {
    runtime_value("cubic-bezier(0.8,0,0.2,1)")
  } else if coverage.official_token == "curveEasyEase" {
    runtime_value("cubic-bezier(0.33,0,0.67,1)")
  } else if coverage.official_token == "curveLinear" {
    runtime_value("cubic-bezier(0,0,1,1)")
  } else {
    runtime_unavailable()
  }
}

///|
fn actual_runtime_token_value(
  moui_token : String,
  tokens : @common.DesignSystemTokens,
) -> RuntimeTokenValue {
  match moui_token {
    "@common.DesignSemanticPalette.foreground" =>
      runtime_color_value(tokens.palette.foreground)
    "@common.DesignSemanticPalette.background" =>
      runtime_color_value(tokens.palette.background)
    "@common.DesignSemanticPalette.surface" =>
      runtime_color_value(tokens.palette.surface)
    "@common.DesignSemanticPalette.surface_variant" =>
      runtime_color_value(tokens.palette.surface_variant)
    "@common.DesignSemanticPalette.primary" =>
      runtime_color_value(tokens.palette.primary)
    "@common.DesignSemanticPalette.primary_foreground" =>
      runtime_color_value(tokens.palette.primary_foreground)
    "@common.DesignSemanticPalette.outline" =>
      runtime_color_value(tokens.palette.outline)
    "@common.DesignSemanticPalette.muted" =>
      runtime_color_value(tokens.palette.muted)
    "@common.DesignSemanticPalette.success" =>
      runtime_color_value(tokens.palette.success)
    "@common.DesignSemanticPalette.warning" =>
      runtime_color_value(tokens.palette.warning)
    "@common.DesignSemanticPalette.danger" =>
      runtime_color_value(tokens.palette.danger)
    "@common.DesignSemanticPalette.info" =>
      runtime_color_value(tokens.palette.info)
    "@common.DesignSemanticPalette.focus" =>
      runtime_color_value(tokens.palette.focus)
    "@common.DesignSemanticPalette.scrim" =>
      runtime_color_value(tokens.palette.scrim)
    "@common.DesignComponentTokens.button.primary.background" =>
      runtime_color_value(tokens.components.button.primary.background)
    "@common.DesignComponentTokens.button.primary.foreground" =>
      runtime_color_value(tokens.components.button.primary.foreground)
    "@common.DesignComponentTokens.feedback.success.foreground" =>
      runtime_color_value(tokens.components.feedback.success.foreground)
    "@common.DesignComponentTokens.form_validation.foreground" =>
      runtime_color_value(tokens.components.form_validation.foreground)
    "@common.DesignComponentTokens.progress.foreground" =>
      runtime_color_value(tokens.components.progress.foreground)
    "@common.DesignComponentTokens.slider.foreground" =>
      runtime_color_value(tokens.components.slider.foreground)
    "@common.DesignComponentTokens.text_field.normal.border_width" =>
      runtime_double_value(tokens.components.text_field.normal.border_width)
    "@common.DesignComponentTokens.text_field.focused.border_width" =>
      runtime_double_value(tokens.components.text_field.focused.border_width)
    "@common.DesignTextFieldTokens.focused.border" =>
      runtime_color_value(tokens.components.text_field.focused.border)
    "@common.DesignComponentTokens.picker.background" =>
      runtime_color_value(tokens.components.picker.background.fallback_color())
    "@common.DesignTypographyTokens.body.size" =>
      runtime_double_value(tokens.typography.body.size)
    "@common.DesignTypographyTokens.title.size" =>
      runtime_double_value(tokens.typography.title.size)
    "@common.DesignTypographyTokens.caption.size" =>
      runtime_double_value(tokens.typography.caption.size)
    "@common.DesignTypographyTokens.control.size" =>
      runtime_double_value(tokens.typography.control.size)
    "@common.DesignTypographyTokens.body.weight" =>
      runtime_int_value(tokens.typography.body.weight)
    "@common.DesignTypographyTokens.title.weight" =>
      runtime_int_value(tokens.typography.title.weight)
    "@common.DesignTypographyTokens.control.weight" =>
      runtime_int_value(tokens.typography.control.weight)
    "@common.DesignTypographyTokens.body.families" =>
      runtime_value(tokens.typography.body.css_family())
    "@common.DesignTypographyTokens.control.families" =>
      runtime_value(tokens.typography.control.css_family())
    "@common.DesignStateLayerTokens.hover_alpha" =>
      runtime_double_value(tokens.state_layer.hover_alpha)
    "@common.DesignStateLayerTokens.pressed_alpha" =>
      runtime_double_value(tokens.state_layer.pressed_alpha)
    "@common.DesignRadiusTokens.sm" => runtime_double_value(tokens.radius.sm)
    "@common.DesignRadiusTokens.md" => runtime_double_value(tokens.radius.md)
    "@common.DesignRadiusTokens.lg" => runtime_double_value(tokens.radius.lg)
    "@common.DesignRadiusTokens.pill" =>
      runtime_double_value(tokens.radius.pill)
    "@common.DesignElevationTokens.sm.offset.y" =>
      runtime_double_value(tokens.elevation.sm.offset.y)
    "@common.DesignElevationTokens.md.offset.y" =>
      runtime_double_value(tokens.elevation.md.offset.y)
    "@common.DesignElevationTokens.lg.offset.y" =>
      runtime_double_value(tokens.elevation.lg.offset.y)
    "@common.DesignElevationTokens.card" =>
      match tokens.elevation.card {
        Some(value) => runtime_double_value(value.offset.y)
        None => runtime_unavailable()
      }
    "@common.DesignElevationTokens.flyout" =>
      match tokens.elevation.flyout {
        Some(value) => runtime_double_value(value.offset.y)
        None => runtime_unavailable()
      }
    "@common.DesignElevationTokens.dialog" =>
      match tokens.elevation.dialog {
        Some(value) => runtime_double_value(value.offset.y)
        None => runtime_unavailable()
      }
    "@common.DesignSpacingTokens.xs" => runtime_double_value(tokens.spacing.xs)
    "@common.DesignSpacingTokens.sm" => runtime_double_value(tokens.spacing.sm)
    "@common.DesignSpacingTokens.md" => runtime_double_value(tokens.spacing.md)
    "@common.DesignSpacingTokens.lg" => runtime_double_value(tokens.spacing.lg)
    "@common.DesignSpacingTokens.xl" => runtime_double_value(tokens.spacing.xl)
    "@common.DesignMotionTokens.fast_ms" =>
      runtime_double_value(tokens.motion.fast_ms)
    "@common.DesignMotionTokens.normal_ms" =>
      runtime_double_value(tokens.motion.normal_ms)
    "@common.DesignMotionTokens.slow_ms" =>
      runtime_double_value(tokens.motion.slow_ms)
    "@common.DesignMotionTokens.easing" =>
      runtime_value(easing_runtime_value(tokens.motion.easing))
    _ => runtime_unavailable()
  }
}

///|
fn runtime_color_value(value : @core.Color) -> RuntimeTokenValue {
  runtime_value(
    "rgba(" +
    value.r.to_string() +
    "," +
    value.g.to_string() +
    "," +
    value.b.to_string() +
    "," +
    value.a.to_string() +
    ")",
  )
}

///|
fn runtime_double_value(value : Double) -> RuntimeTokenValue {
  runtime_value(value.to_string())
}

///|
fn runtime_int_value(value : Int) -> RuntimeTokenValue {
  runtime_value(value.to_string())
}

///|
fn easing_runtime_value(value : @core.Easing) -> String {
  match value {
    @core.Easing::Linear => "linear"
    @core.Easing::EaseIn => "ease-in"
    @core.Easing::EaseOut => "ease-out"
    @core.Easing::EaseInOut => "ease-in-out"
  }
}

///|
fn runtime_value(value : String) -> RuntimeTokenValue {
  { available: true, value }
}

///|
fn runtime_unavailable() -> RuntimeTokenValue {
  { available: false, value: "" }
}
