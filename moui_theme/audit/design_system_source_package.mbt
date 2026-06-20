///|
pub(all) struct DesignSourcePackageRecord {
  preset : @common.DesignPreset
  package_name : String
  source_label : String
  source_url : String
  source_ref : String
  token_path : String
  snapshot_url : String
  package_path : String
  category : DesignTokenCategory
  layer : DesignTokenLayer
  tracked_path_count : Int
  mapped_token_count : Int
  imported_token_count : Int
  status : DesignTokenStatus
  pending_gap : String
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn source_package_inventory(
  preset : @common.DesignPreset,
) -> Array[DesignSourcePackageRecord] {
  match preset {
    Material => material_source_package_inventory()
    Carbon => carbon_source_package_inventory()
    Primer => primer_source_package_inventory()
    Fluent => fluent_source_package_inventory()
  }
}

///|
pub fn source_package_inventory_count(preset : @common.DesignPreset) -> Int {
  source_package_inventory(preset).length()
}

///|
pub fn source_package_snapshot_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_package_inventory(preset) {
    if item.snapshot_url != "" {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_package_snapshot_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_package_inventory(preset) {
    if item.snapshot_url == "" {
      count = count + 1
    }
  }
  count
}

///|
pub fn source_package_imported_token_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in source_package_inventory(preset) {
    count = count + item.imported_token_count
  }
  count
}

///|
pub fn source_package_mapped_token_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_package_inventory(preset) {
    count = count + item.mapped_token_count
  }
  count
}

///|
pub fn source_package_import_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in source_package_inventory(preset) {
    if item.imported_token_count == 0 ||
      item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
fn material_source_package_inventory() -> Array[DesignSourcePackageRecord] {
  [
    source_package(
      @common.DesignPreset::Material,
      "Material system token SCSS",
      "tokens/_md-sys-*.scss",
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      tracked_path_count=6,
      mapped_token_count=13,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Material,
        "tokens/_md-sys-*.scss",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full md.sys color, typescale, shape, elevation matrix, motion, and state token import.",
      note="Pinned package contains _md-sys-color, _md-sys-typescale, _md-sys-shape, _md-sys-elevation, _md-sys-motion, and _md-sys-state files.",
    ),
    source_package(
      @common.DesignPreset::Material,
      "Material reference palette SCSS",
      "tokens/versions/v0_192/_md-ref-palette.scss",
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      tracked_path_count=1,
      mapped_token_count=9,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Material,
        "tokens/versions/v0_192/_md-ref-palette.scss",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate the full md.ref palette import instead of the current semantic subset.",
      note="Pinned reference palette resolves Material light semantic color values used by the system color adapter.",
    ),
    source_package(
      @common.DesignPreset::Material,
      "Material component token SCSS",
      "tokens/_md-comp-*.scss",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=35,
      mapped_token_count=5,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Material,
        "tokens/_md-comp-*.scss",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full md.comp component token matrix from pinned SCSS sources.",
      note="Pinned package includes filled button, text field, linear progress, slider, menu, badge, and other component token files.",
    ),
  ]
}

///|
fn carbon_source_package_inventory() -> Array[DesignSourcePackageRecord] {
  [
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon theme sets",
      "packages/themes/src/{white,g10,g90,g100}.ts",
      DesignTokenCategory::SchemeVariant,
      DesignTokenLayer::AliasToken,
      tracked_path_count=4,
      mapped_token_count=12,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/themes/src/{white,g10,g90,g100}.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Carbon white/g10/g90/g100 theme token import.",
      note="Pinned package exposes Carbon theme set files for the shipped light and dark theme families.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon token source modules",
      "packages/themes/src/tokens/*.ts",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=10,
      mapped_token_count=8,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/themes/src/tokens/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Carbon token and component-token matrix from src/tokens.",
      note="Pinned package contains TokenSet, TokenGroup, layout, type, components, and v11 token source modules.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon motion source",
      "packages/motion/src/index.ts",
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      tracked_path_count=1,
      mapped_token_count=13,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/motion/src/index.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Close MoUI motion adaptation differences or add a richer neutral motion curve model.",
      note="Pinned motion source exposes the full Carbon duration token set and productive/expressive easing curves.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon layout token source",
      "packages/layout/src/*.ts",
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      tracked_path_count=2,
      mapped_token_count=25,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/layout/src/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate Carbon size and fluid spacing imports beyond the spacing/layout/container token families currently collapsed into MoUI spacing slots.",
      note="Pinned layout source contains Carbon spacing01..spacing13, layout01..layout07, and container01..container05 numeric scales; values outside MoUI's xs/sm/md/lg/xl slots remain preview-collapsed.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon type token source",
      "packages/type/src/styles.ts",
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      tracked_path_count=2,
      mapped_token_count=4,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/type/src/styles.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Carbon type style import, including line-height, letter spacing, font family, and responsive/fluid heading variants.",
      note="Pinned type source maps selected Carbon body, heading, caption, and label font-size styles into neutral typography slots.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon component token modules",
      "packages/themes/src/component-tokens/**/*.ts",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=5,
      mapped_token_count=1,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/themes/src/component-tokens/**/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Carbon component-token imports from component-tokens sources.",
      note="Pinned package contains button, content-switcher, notification, status, and tag component-token source modules.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon SCSS token output",
      "packages/themes/scss/*.scss",
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      tracked_path_count=6,
      mapped_token_count=8,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/themes/scss/*.scss",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Compare generated MoonBit tokens against Carbon SCSS output snapshots.",
      note="Pinned package contains SCSS output files such as _tokens, _themes, _theme, and _component-tokens.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon styles slider SCSS",
      "packages/styles/scss/components/slider/*.scss",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=2,
      mapped_token_count=1,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/styles/scss/components/slider/*.scss",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Carbon slider component token imports from styles SCSS sources.",
      note="Pinned styles package contains the slider filled-track rule consumed by the neutral slider foreground token.",
    ),
    source_package(
      @common.DesignPreset::Carbon,
      "Carbon color primitives",
      "packages/colors/src/colors.ts",
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      tracked_path_count=1,
      mapped_token_count=6,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Carbon,
        "packages/colors/src/colors.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate the full Carbon color primitive import instead of the current semantic subset.",
      note="Pinned colors source resolves white, gray10, gray100, blue60, red60, and green50 primitives used by the Carbon white theme adapter.",
    ),
  ]
}

///|
fn primer_source_package_inventory() -> Array[DesignSourcePackageRecord] {
  [
    source_package(
      @common.DesignPreset::Primer,
      "Primer base color mode primitives",
      "src/tokens/base/color/**/*.json5",
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      tracked_path_count=7,
      mapped_token_count=9,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/base/color/**/*.json5",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate direct Primer base color primitive imports for every light, dark, high-contrast, dimmed, and display mode source.",
      note="Pinned package contains the base light values resolved by functional color tokens, but the current records import the functional token layer directly.",
    ),
    source_package(
      @common.DesignPreset::Primer,
      "Primer functional color tokens",
      "src/tokens/functional/color/*.json5",
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      tracked_path_count=7,
      mapped_token_count=13,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/functional/color/*.json5",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Primer functional color import across fgColor, bgColor, borderColor, control, selection, syntax, and data-vis files.",
      note="Pinned package maps default foreground, muted foreground, accent/info, emphasized accent primary/focus, success, danger, background, muted/inset surfaces, and default border tokens.",
    ),
    source_package(
      @common.DesignPreset::Primer,
      "Primer base primitives",
      "src/tokens/base/{motion,size,typography}",
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      tracked_path_count=6,
      mapped_token_count=28,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/base/{motion,size,typography}",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate remaining Primer size, z-index, line-height, typography size/weight, and font-family primitive imports beyond the imported neutral representatives.",
      note="Pinned package contains imported base motion timing/easing primitives, neutral size representatives, and neutral typography size/weight representatives.",
    ),
    source_package(
      @common.DesignPreset::Primer,
      "Primer functional size tokens",
      "src/tokens/functional/size/*.json5",
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      tracked_path_count=8,
      mapped_token_count=5,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/functional/size/*.json5",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Primer functional size import across border, breakpoints, radius, size, viewport, and z-index files.",
      note="Pinned package imports the borderRadius small/medium/large/full/default radius tokens used by neutral radius slots.",
    ),
    source_package(
      @common.DesignPreset::Primer,
      "Primer functional shadow tokens",
      "src/tokens/functional/shadow/*.json5",
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      tracked_path_count=1,
      mapped_token_count=3,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/functional/shadow/*.json5",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Primer functional shadow import across inset, resting, floating, mode override, and high-contrast shadow records.",
      note="Pinned package imports representative resting small, resting medium, and floating large shadow tokens for neutral elevation slots.",
    ),
    source_package(
      @common.DesignPreset::Primer,
      "Primer component primitives",
      "src/tokens/component/*.json5",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=20,
      mapped_token_count=6,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Primer,
        "src/tokens/component/*.json5",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate full Primer component token matrix from component JSON5 files.",
      note="Pinned package contains button, menu, overlay, progressBar, label, focus, and other component token sources.",
    ),
  ]
}

///|
fn fluent_source_package_inventory() -> Array[DesignSourcePackageRecord] {
  [
    source_package(
      @common.DesignPreset::Fluent,
      "Fluent global tokens",
      "packages/tokens/src/global/*.ts",
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      tracked_path_count=11,
      mapped_token_count=90,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Fluent,
        "packages/tokens/src/global/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate remaining Fluent global color palette imports, add neutral line-height/font-family/stroke-width scale parity, and close spacing/radius/motion/color adaptation differences.",
      note="Pinned package imports full global font, stroke-width, horizontal and vertical spacing, radius, duration, curve, and expanded status reference color tokens used by neutral or preview slots.",
    ),
    source_package(
      @common.DesignPreset::Fluent,
      "Fluent alias tokens",
      "packages/tokens/src/alias/*.ts",
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      tracked_path_count=8,
      mapped_token_count=12,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Fluent,
        "packages/tokens/src/alias/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate Fluent light, dark, high-contrast, and brand alias token imports.",
      note="Pinned package contains light, dark, high-contrast, Teams color, focus stroke, overlay, and font-family alias sources.",
    ),
    source_package(
      @common.DesignPreset::Fluent,
      "Fluent theme token sets",
      "packages/tokens/src/themes/**",
      DesignTokenCategory::SchemeVariant,
      DesignTokenLayer::SystemToken,
      tracked_path_count=3,
      mapped_token_count=1,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Fluent,
        "packages/tokens/src/themes/**",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate exact Fluent web and Teams theme token set imports.",
      note="Pinned package exposes theme token sets under web and Teams theme directories.",
    ),
    source_package(
      @common.DesignPreset::Fluent,
      "Fluent web component progress styles",
      "packages/web-components/src/progress-bar/*.ts",
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      tracked_path_count=11,
      mapped_token_count=1,
      imported_token_count=source_imported_token_count_for_package(
        @common.DesignPreset::Fluent,
        "packages/web-components/src/progress-bar/*.ts",
      ),
      status=DesignTokenStatus::PreviewMapped,
      pending_gap="Generate Fluent web component style imports across component packages.",
      note="Pinned package contains the progress-bar indicator background rule used by the neutral progress foreground token.",
    ),
  ]
}

///|
fn source_package(
  preset : @common.DesignPreset,
  package_name : String,
  package_path : String,
  category : DesignTokenCategory,
  layer : DesignTokenLayer,
  tracked_path_count~ : Int,
  mapped_token_count~ : Int,
  imported_token_count~ : Int,
  status~ : DesignTokenStatus,
  pending_gap~ : String,
  note~ : String,
) -> DesignSourcePackageRecord {
  let source = source_package_lock_for(preset, package_path)
  {
    preset,
    package_name,
    source_label: source.source_label,
    source_url: source.source_url,
    source_ref: source.source_ref,
    token_path: source.token_path,
    snapshot_url: source.snapshot_url,
    package_path,
    category,
    layer,
    tracked_path_count,
    mapped_token_count,
    imported_token_count,
    status,
    pending_gap,
    note,
  }
}

///|
fn source_package_lock_for(
  preset : @common.DesignPreset,
  package_path : String,
) -> DesignSourceLockRecord {
  for item in source_lock_report(preset) {
    if item.token_path != "" && package_path.contains(item.token_path) {
      return item
    }
  }
  for item in source_lock_report(preset) {
    if item.source_kind == "official-source" {
      return item
    }
  }
  {
    preset,
    source_label: "",
    source_url: "",
    source_kind: "",
    source_ref: "",
    token_path: "",
    snapshot_url: "",
    ref_kind: DesignSourceRefKind::MissingRef,
    declared_lock: false,
    stable_lock: false,
    status: DesignTokenStatus::NotMapped,
    note: "No package source lock is available.",
  }
}
