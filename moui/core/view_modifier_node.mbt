///|
/// A view node that wraps a child View with a modifier.
/// The modifier is stored as an `AnyModifier[Msg]` vtable, eliminating the
/// 50-variant `ViewModifier[Msg]` enum. Each concrete modifier type
/// constructs its own `AnyModifier` via `to_any_modifier()`.

///|
fn[Msg] modifier_view(
  child : View[Msg],
  modifier : AnyModifier[Msg],
) -> View[Msg] {
  let node = ModifierViewNode::{ child, modifier }
  View::from_node(
    node,
    children=node => [node.child],
    event=(node, context) => (node.modifier.event)(context),
    text_command=(node, context, intent, paste_text) => {
      node.child.text_command_result(context, intent, paste_text~)
    },
    semantics_actions=node => node.modifier.semantics_actions.copy(),
  )
}

///|
priv struct ModifierViewNode[Msg] {
  child : View[Msg]
  modifier : AnyModifier[Msg]
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn identity(self) {
  let child_id = self.child.identity()
  let kind = self.modifier.identity_kind
  if kind == "Key" {
    match self.modifier.identity_key {
      Some(key) => { kind: child_id.kind, key: Some(key) }
      None => { kind: child_id.kind, key: child_id.key }
    }
  } else if kind == "" {
    child_id
  } else {
    { kind: "Modified<\{kind}>/\{child_id.kind}", key: child_id.key }
  }
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn declaration(self) {
  self.modifier.declaration
}

///|

///|
/// A modifier node carrying a keyboard-shortcut modifier is a shortcut
/// scope; all other modifiers pass keyboard policy through.
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn keyboard_policy(self) {
  if self.modifier.identity_kind == "KeyboardShortcut" {
    KeyboardPolicy::ShortcutScope
  } else {
    KeyboardPolicy::Passthrough
  }
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_constraints(self, c) {
  (self.modifier.child_constraints)(c)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_environment(self, e) {
  (self.modifier.child_environment)(e)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_style(self, s) {
  (self.modifier.child_style)(s)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn layout(self, ctx) {
  (self.modifier.layout)(ctx)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn paint(self, ctx) {
  (self.modifier.paint)(ctx)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn text_input_state(self, ctx) {
  self.child.text_input_state(ctx)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn semantics(self) {
  self.modifier.semantics
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn focusable(self) {
  self.modifier.focusable
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn focus_trap(self) {
  self.modifier.focus_trap
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn flex_weight(self) {
  self.modifier.flex_weight
}
