///|
/// Environment and focus modifiers: Theme, Environment, Disabled,
/// Focusable, FocusTrap.

///|
pub(all) struct ThemeModifier {
  theme : Theme
}

///|
pub fn[Msg] ThemeModifier::to_any_modifier(
  self : ThemeModifier,
) -> AnyModifier[Msg] {
  let theme = self.theme
  {
    ..noop_modifier(),
    identity_kind: "Theme",
    child_environment: fn(e) { e.with_theme(theme) },
  }
}

///|
pub(all) struct EnvironmentModifier {
  environment : Environment
}

///|
pub fn[Msg] EnvironmentModifier::to_any_modifier(
  self : EnvironmentModifier,
) -> AnyModifier[Msg] {
  let env = self.environment
  {
    ..noop_modifier(),
    identity_kind: "Environment",
    child_environment: fn(_e) { env },
  }
}

///|
pub(all) struct DisabledModifier {
  disabled : Bool
}

///|
pub fn[Msg] DisabledModifier::to_any_modifier(
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
          commands: [DrawCommand::PushOpacity(0.42)],
          child_layers: [],
          post_commands: [DrawCommand::PopOpacity],
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
pub(all) struct FocusableModifier {
  focusable : Bool
}

///|
pub fn[Msg] FocusableModifier::to_any_modifier(
  self : FocusableModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "Focusable", focusable: self.focusable }
}

///|
pub(all) struct FocusTrapModifier {
  trap : Bool
}

///|
pub fn[Msg] FocusTrapModifier::to_any_modifier(
  self : FocusTrapModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "FocusTrap",
    focus_trap: self.trap,
    semantics: ViewSemanticsInfo::new(modal=self.trap),
  }
}
