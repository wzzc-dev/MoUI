///|
pub(all) enum DesignSourceRefKind {
  WorkspaceRef
  LiveDocumentationRef
  MovingBranchRef
  StableSnapshotRef
  MissingRef
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSourceLockRecord {
  preset : DesignPreset
  source_label : String
  source_url : String
  source_kind : String
  source_ref : String
  token_path : String
  snapshot_url : String
  ref_kind : DesignSourceRefKind
  declared_lock : Bool
  stable_lock : Bool
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignSourceRefKind::label(self : DesignSourceRefKind) -> String {
  match self {
    WorkspaceRef => "workspace"
    LiveDocumentationRef => "live documentation"
    MovingBranchRef => "moving branch"
    StableSnapshotRef => "stable snapshot"
    MissingRef => "missing"
  }
}

///|
pub fn DesignPreset::source_lock_report(
  self : DesignPreset,
) -> Array[DesignSourceLockRecord] {
  let records : Array[DesignSourceLockRecord] = []
  for source in self.sources() {
    records.push(source_lock_record(self, source))
  }
  records
}

///|
pub fn DesignPreset::source_lock_quality_gap_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.source_lock_report() {
    if !item.stable_lock {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::stable_source_lock_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.source_lock_report() {
    if item.stable_lock {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::source_snapshot_url_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.source_lock_report() {
    if item.snapshot_url != "" {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::source_snapshot_url_gap_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.source_lock_report() {
    if item.source_kind == "official-source" &&
      item.stable_lock &&
      item.snapshot_url == "" {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::moving_source_ref_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.source_lock_report() {
    if item.ref_kind == DesignSourceRefKind::LiveDocumentationRef ||
      item.ref_kind == DesignSourceRefKind::MovingBranchRef {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::has_stable_source_locks(self : DesignPreset) -> Bool {
  self.source_lock_report().length() > 0 &&
  self.source_lock_quality_gap_count() == 0
}

///|
fn source_lock_record(
  preset : DesignPreset,
  source : DesignSystemSource,
) -> DesignSourceLockRecord {
  let ref_kind = source_ref_kind(source.source_ref)
  let declared_lock = source.source_ref != "" &&
    source.status != DesignTokenStatus::NotMapped &&
    (
      source.token_path != "" ||
      source.source_kind == "official-docs" ||
      source.source_kind == "internal-token-contract" ||
      source.source_kind == "internal-component-adapter"
    )
  let stable_lock = declared_lock &&
    (
      ref_kind == DesignSourceRefKind::WorkspaceRef ||
      ref_kind == DesignSourceRefKind::StableSnapshotRef
    )
  let snapshot_url = source_snapshot_url(source, ref_kind, stable_lock)
  let status = if stable_lock {
    source.status
  } else if declared_lock {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  {
    preset,
    source_label: source.label,
    source_url: source.url,
    source_kind: source.source_kind,
    source_ref: source.source_ref,
    token_path: source.token_path,
    snapshot_url,
    ref_kind,
    declared_lock,
    stable_lock,
    status,
    note: if stable_lock {
      "Source has a stable lock suitable for reproducible token import evidence."
    } else if declared_lock {
      "Source has a declared lock, but it points at a moving branch or live documentation."
    } else {
      "Source is missing source_ref or token_path evidence."
    },
  }
}

///|
fn source_ref_kind(source_ref : String) -> DesignSourceRefKind {
  match source_ref {
    "" => DesignSourceRefKind::MissingRef
    "workspace" => DesignSourceRefKind::WorkspaceRef
    "live" => DesignSourceRefKind::LiveDocumentationRef
    "main" => DesignSourceRefKind::MovingBranchRef
    "master" => DesignSourceRefKind::MovingBranchRef
    _ => DesignSourceRefKind::StableSnapshotRef
  }
}

///|
fn source_snapshot_url(
  source : DesignSystemSource,
  ref_kind : DesignSourceRefKind,
  stable_lock : Bool,
) -> String {
  if !stable_lock {
    ""
  } else if ref_kind == DesignSourceRefKind::WorkspaceRef {
    source.url
  } else if source.url ==
    "https://github.com/material-components/material-web/tree/main/tokens" {
    "https://github.com/material-components/material-web/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/themes" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/colors" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/styles" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/motion" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/layout" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/carbon-design-system/carbon/tree/main/packages/type" {
    "https://github.com/carbon-design-system/carbon/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url == "https://github.com/primer/primitives" {
    "https://github.com/primer/primitives/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/microsoft/fluentui/tree/master/packages/tokens" {
    "https://github.com/microsoft/fluentui/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else if source.url ==
    "https://github.com/microsoft/fluentui/tree/master/packages/web-components" {
    "https://github.com/microsoft/fluentui/tree/" +
    source.source_ref +
    "/" +
    source.token_path
  } else {
    ""
  }
}
