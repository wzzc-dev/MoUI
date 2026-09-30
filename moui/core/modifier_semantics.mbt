///|
/// Semantics modifiers with proper declaration keys for incremental caching.
fn sem_decl(key : DeclarationKey) -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Constant,
    paint=Constant,
    semantics=Exact(key),
    platform=Constant,
  )
}

///|
fn semantics_info_declaration(info : ViewSemanticsInfo) -> ViewDeclaration {
  sem_decl(DeclarationKey::string((ToJson::to_json(info) : Json).stringify()))
}

///|
pub(all) struct AccessibilityLabelModifier {
  label : String
}

///|
pub fn[Msg] AccessibilityLabelModifier::to_any_modifier(
  self : AccessibilityLabelModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(label=self.label)
  {
    ..noop_modifier(),
    identity_kind: "AccessibilityLabel",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticIdModifier {
  semantic_id : SemanticId
}

///|
pub fn[Msg] SemanticIdModifier::to_any_modifier(
  self : SemanticIdModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(semantic_id=self.semantic_id)
  {
    ..noop_modifier(),
    identity_kind: "SemanticId",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsCompositionModifier {
  composition : SemanticsComposition
}

///|
pub fn[Msg] SemanticsCompositionModifier::to_any_modifier(
  self : SemanticsCompositionModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(composition=self.composition)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsComposition",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsRoleModifier {
  role : SemanticsRole
}

///|
pub fn[Msg] SemanticsRoleModifier::to_any_modifier(
  self : SemanticsRoleModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(role=self.role)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsRole",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsLevelModifier {
  level : Int
}

///|
pub fn[Msg] SemanticsLevelModifier::to_any_modifier(
  self : SemanticsLevelModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(level=self.level)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsLevel",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsUrlModifier {
  url : String
}

///|
pub fn[Msg] SemanticsUrlModifier::to_any_modifier(
  self : SemanticsUrlModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(url=self.url)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsUrl",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsSelectedModifier {
  selected : Bool
}

///|
pub fn[Msg] SemanticsSelectedModifier::to_any_modifier(
  self : SemanticsSelectedModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(selected=self.selected)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsSelected",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsPressedModifier {
  pressed : Bool
}

///|
pub fn[Msg] SemanticsPressedModifier::to_any_modifier(
  self : SemanticsPressedModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(pressed=self.pressed)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsPressed",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsCheckedModifier {
  checked : SemanticsCheckedState
}

///|
pub fn[Msg] SemanticsCheckedModifier::to_any_modifier(
  self : SemanticsCheckedModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(checked=self.checked)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsChecked",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsExpandedModifier {
  expanded : Bool
}

///|
pub fn[Msg] SemanticsExpandedModifier::to_any_modifier(
  self : SemanticsExpandedModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(expanded=self.expanded)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsExpanded",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsInvalidModifier {
  invalid : Bool
}

///|
pub fn[Msg] SemanticsInvalidModifier::to_any_modifier(
  self : SemanticsInvalidModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(invalid=self.invalid)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsInvalid",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsRequiredModifier {
  required : Bool
}

///|
pub fn[Msg] SemanticsRequiredModifier::to_any_modifier(
  self : SemanticsRequiredModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(required=self.required)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsRequired",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
pub(all) struct SemanticsDescriptionModifier {
  description : String
}

///|
pub fn[Msg] SemanticsDescriptionModifier::to_any_modifier(
  self : SemanticsDescriptionModifier,
) -> AnyModifier[Msg] {
  let info = ViewSemanticsInfo::new(description=self.description)
  {
    ..noop_modifier(),
    identity_kind: "SemanticsDescription",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}

///|
/// Grouped advanced semantics metadata with an exact cache key.
pub(all) struct SemanticsMetadataModifier {
  info : ViewSemanticsInfo
}

///|
/// Merge this info (a modifier's contribution) over `base` (the wrapped
/// child's info). Fields set explicitly on `self` win; unset fields pass
/// through from `base`.
///
/// Two fields are deliberately not inherited from `base`:
/// - `composition` keeps `self.composition`: composition is structural
///   (how this node's subtree contributes), and inheriting a child's
///   Boundary/MergeDescendants would re-wrap the child's own grouping.
/// - `text` keeps `self.text`: it is element-instance-scoped state
///   (caret/selection are injected by the owning element at overlay time),
///   so re-inheriting it from a wrapper would clobber the text control's
///   live state.
pub fn ViewSemanticsInfo::overlaying(
  self : ViewSemanticsInfo,
  base : ViewSemanticsInfo,
) -> ViewSemanticsInfo {
  {
    composition: self.composition,
    semantic_id: match self.semantic_id {
      Some(id) => Some(id)
      None => base.semantic_id
    },
    role: match self.role {
      Some(role) => Some(role)
      None => base.role
    },
    level: match self.level {
      Some(level) => Some(level)
      None => base.level
    },
    url: match self.url {
      Some(url) => Some(url)
      None => base.url
    },
    label: match self.label {
      Some(label) => Some(label)
      None => base.label
    },
    value: match self.value {
      Some(value) => Some(value)
      None => base.value
    },
    description: match self.description {
      Some(description) => Some(description)
      None => base.description
    },
    disabled: match self.disabled {
      Some(disabled) => Some(disabled)
      None => base.disabled
    },
    selected: match self.selected {
      Some(selected) => Some(selected)
      None => base.selected
    },
    pressed: match self.pressed {
      Some(pressed) => Some(pressed)
      None => base.pressed
    },
    checked: match self.checked {
      Some(checked) => Some(checked)
      None => base.checked
    },
    expanded: match self.expanded {
      Some(expanded) => Some(expanded)
      None => base.expanded
    },
    invalid: match self.invalid {
      Some(invalid) => Some(invalid)
      None => base.invalid
    },
    required: match self.required {
      Some(required) => Some(required)
      None => base.required
    },
    read_only: match self.read_only {
      Some(read_only) => Some(read_only)
      None => base.read_only
    },
    busy: match self.busy {
      Some(busy) => Some(busy)
      None => base.busy
    },
    multiline: match self.multiline {
      Some(multiline) => Some(multiline)
      None => base.multiline
    },
    password: match self.password {
      Some(password) => Some(password)
      None => base.password
    },
    modal: match self.modal {
      Some(modal) => Some(modal)
      None => base.modal
    },
    numeric: match self.numeric {
      Some(numeric) => Some(numeric)
      None => base.numeric
    },
    text: self.text,
    collection: match self.collection {
      Some(collection) => Some(collection)
      None => base.collection
    },
    relations: match self.relations {
      Some(relations) => Some(relations)
      None => base.relations
    },
    live: match self.live {
      Some(live) => Some(live)
      None => base.live
    },
    live_atomic: match self.live_atomic {
      Some(live_atomic) => Some(live_atomic)
      None => base.live_atomic
    },
  }
}

///|
pub fn[Msg] SemanticsMetadataModifier::to_any_modifier(
  self : SemanticsMetadataModifier,
) -> AnyModifier[Msg] {
  let info = self.info
  {
    ..noop_modifier(),
    identity_kind: "SemanticsMetadata",
    declaration: semantics_info_declaration(info),
    semantics: info,
  }
}
