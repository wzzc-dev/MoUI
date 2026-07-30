///|
/// Semantics modifiers with proper declaration keys for incremental caching.

fn sem_decl(key : DeclarationKey) -> ViewDeclaration {
  ViewDeclaration::channels(layout=Constant, paint=Constant, semantics=Exact(key), platform=Constant)
}

pub(all) struct AccessibilityLabelModifier { label : String }
pub fn[Msg] AccessibilityLabelModifier::to_any_modifier(self : AccessibilityLabelModifier) -> AnyModifier[Msg] {
  let label = self.label
  { ..noop_modifier(), identity_kind: "AccessibilityLabel",
    declaration: sem_decl(DeclarationKey::string(label)),
    semantics: ViewSemanticsInfo::new(label~, value=label),
  }
}

pub(all) struct SemanticIdModifier { semantic_id : SemanticId }
pub fn[Msg] SemanticIdModifier::to_any_modifier(self : SemanticIdModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticId", semantics: ViewSemanticsInfo::new(semantic_id=self.semantic_id) }
}

pub(all) struct SemanticsCompositionModifier { composition : SemanticsComposition }
pub fn[Msg] SemanticsCompositionModifier::to_any_modifier(self : SemanticsCompositionModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsComposition", semantics: ViewSemanticsInfo::new(composition=self.composition) }
}

pub(all) struct SemanticsRoleModifier { role : SemanticsRole }
pub fn[Msg] SemanticsRoleModifier::to_any_modifier(self : SemanticsRoleModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsRole", semantics: ViewSemanticsInfo::new(role=self.role) }
}

pub(all) struct SemanticsLevelModifier { level : Int }
pub fn[Msg] SemanticsLevelModifier::to_any_modifier(self : SemanticsLevelModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsLevel", semantics: ViewSemanticsInfo::new(level=self.level) }
}

pub(all) struct SemanticsUrlModifier { url : String }
pub fn[Msg] SemanticsUrlModifier::to_any_modifier(self : SemanticsUrlModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsUrl", semantics: ViewSemanticsInfo::new(url=self.url) }
}

pub(all) struct SemanticsSelectedModifier { selected : Bool }
pub fn[Msg] SemanticsSelectedModifier::to_any_modifier(self : SemanticsSelectedModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsSelected", semantics: ViewSemanticsInfo::new(selected=self.selected) }
}

pub(all) struct SemanticsPressedModifier { pressed : Bool }
pub fn[Msg] SemanticsPressedModifier::to_any_modifier(self : SemanticsPressedModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsPressed", semantics: ViewSemanticsInfo::new(pressed=self.pressed) }
}

pub(all) struct SemanticsCheckedModifier { checked : Bool }
pub fn[Msg] SemanticsCheckedModifier::to_any_modifier(self : SemanticsCheckedModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsChecked", semantics: ViewSemanticsInfo::new(checked=self.checked) }
}

pub(all) struct SemanticsExpandedModifier { expanded : Bool }
pub fn[Msg] SemanticsExpandedModifier::to_any_modifier(self : SemanticsExpandedModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsExpanded", semantics: ViewSemanticsInfo::new(expanded=self.expanded) }
}

pub(all) struct SemanticsInvalidModifier { invalid : Bool }
pub fn[Msg] SemanticsInvalidModifier::to_any_modifier(self : SemanticsInvalidModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsInvalid", semantics: ViewSemanticsInfo::new(invalid=self.invalid) }
}

pub(all) struct SemanticsRequiredModifier { required : Bool }
pub fn[Msg] SemanticsRequiredModifier::to_any_modifier(self : SemanticsRequiredModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsRequired", semantics: ViewSemanticsInfo::new(required=self.required) }
}

pub(all) struct SemanticsDescriptionModifier { description : String }
pub fn[Msg] SemanticsDescriptionModifier::to_any_modifier(self : SemanticsDescriptionModifier) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "SemanticsDescription", semantics: ViewSemanticsInfo::new(description=self.description) }
}
