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
  sem_decl(DeclarationKey::string((info.to_json() : Json).stringify()))
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
