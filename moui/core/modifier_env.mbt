///|
/// Environment and focus modifiers: Theme, Environment, Disabled,
/// Focusable, FocusTrap.

///|
priv struct ThemeModifier {
  theme : Theme
}

///|
/// Memoized scope keys: apps hold a handful of distinct theme/environment
/// values, so the assoc-list scan (structural Eq over at most
/// `scope_key_cache_limit` entries) is cheaper than re-encoding on every view
/// build. The cache clears when it exceeds the bound; correctness never
/// depends on it (a miss just re-encodes).
let scope_key_cache : Array[(String, DeclarationKey)] = []

///|
let scope_key_cache_limit : Int32 = 32

///|
/// Canonical declaration key for a scoped value (theme or full environment).
fn scope_declaration_key(tag : String, value_json : String) -> DeclarationKey {
  let encoded = tag + ":" + value_json
  for entry in scope_key_cache {
    if entry.0 == encoded {
      return entry.1
    }
  }
  let key = DeclarationKey::string(encoded)
  scope_key_cache.push((encoded, key))
  if scope_key_cache.length() > scope_key_cache_limit {
    scope_key_cache.clear()
  }
  key
}

///|
/// Declaration for a scoped-environment modifier. The scoped environment
/// reaches children outside the declaration keys of the controls below, so a
/// changed scope value must invalidate the subtree through the modifier node
/// itself: the layout and paint channels are exact on the scoped value, while
/// semantics (content, not presentation) stays constant.
fn environment_scope_declaration(value_json : String) -> ViewDeclaration {
  let key = scope_declaration_key("env-scope", value_json)
  ViewDeclaration::channels(
    layout=Exact(key),
    paint=Exact(key),
    semantics=Constant,
    platform=Constant,
  )
}

///|
fn[Msg] ThemeModifier::to_any_modifier(
  self : ThemeModifier,
) -> AnyModifier[Msg] {
  let theme = self.theme
  {
    ..noop_modifier(),
    identity_kind: "Theme",
    declaration: environment_scope_declaration(theme.to_json().stringify()),
    // A theme changes colours, never sizes: the subtree keeps the incoming
    // constraints (including their minimums). Relaxing them here would
    // collapse every weighted layout under the theme — a column with
    // `expanded(child, weight=1.0)` measures its content height instead of
    // the space the parent offers, and the subtree collapses to zero height.
    child_constraints: fn(c) { c },
    child_environment: fn(e) { e.with_theme(theme) },
  }
}

///|
priv struct EnvironmentModifier {
  environment : Environment
}

///|
fn[Msg] EnvironmentModifier::to_any_modifier(
  self : EnvironmentModifier,
) -> AnyModifier[Msg] {
  let env = self.environment
  {
    ..noop_modifier(),
    identity_kind: "Environment",
    declaration: environment_scope_declaration(env.to_json().stringify()),
    // Same rule as the theme modifier: an environment swap is a context
    // change, not a resize.
    child_constraints: fn(c) { c },
    child_environment: fn(_e) { env },
  }
}

///|
priv struct DisabledModifier {
  disabled : Bool
}

///|
fn[Msg] DisabledModifier::to_any_modifier(
  self : DisabledModifier,
) -> AnyModifier[Msg] {
  let disabled = self.disabled
  {
    ..noop_modifier(),
    identity_kind: "Disabled",
    child_environment: fn(e) { e.with_enabled(!disabled) },
    semantics: ViewSemanticsInfo::new(disabled~),
    paint: if disabled {
      fn(_ctx) {
        {
          commands: [PushOpacity(0.42)],
          child_layers: [],
          post_commands: [PopOpacity],
          overlay_commands: [],
          repaint_boundary: false,
          animating: false,
        }
      }
    } else {
      fn(_ctx) { ViewPaintPlan::empty() }
    },
    event: if disabled {
      fn(_ctx) { ViewEventResult::ignored() }
    } else {
      fn(_ctx) { ViewEventResult::ignored() }
    },
  }
}

///|
priv struct FocusableModifier {
  focusable : Bool
}

///|
fn[Msg] FocusableModifier::to_any_modifier(
  self : FocusableModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "Focusable", focusable: self.focusable, }
}

///|
priv struct FocusTrapModifier {
  trap : Bool
}

///|
fn[Msg] FocusTrapModifier::to_any_modifier(
  self : FocusTrapModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "FocusTrap",
    focus_trap: self.trap,
    semantics: ViewSemanticsInfo::new(modal=self.trap),
  }
}
