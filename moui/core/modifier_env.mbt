///|
/// Environment and focus modifiers: Theme, Environment, Disabled,
/// Focusable, FocusTrap.

///|
priv struct ThemeModifier {
  theme : Theme
}

///|
fn[Msg] ThemeModifier::to_any_modifier(
  self : ThemeModifier,
) -> AnyModifier[Msg] {
  let theme = self.theme
  {
    ..noop_modifier(),
    identity_kind: "Theme",
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
