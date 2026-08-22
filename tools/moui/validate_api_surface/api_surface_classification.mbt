///|
struct ApiSurfaceCategoryBudget {
  path : String
  category : String
  max_count : Int
}

///|
fn api_surface_semantic_categories() -> Array[String] {
  [
    "app_constructor", "app_state_helper", "app_style", "advanced_core_protocol",
    "runtime_diagnostic", "host_contract", "renderer_contract", "required_protocol",
    "test_exposure", "migration_debt",
  ]
}

///|
fn api_surface_classification_paths() -> Array[String] {
  [
    "moui/core/pkg.generated.mbti", "moui/views/pkg.generated.mbti", "moui/runtime/pkg.generated.mbti",
    "moui/backend/pkg.generated.mbti", "moui/render/pkg.generated.mbti",
  ]
}

///|
fn api_surface_classification_budgets() -> Array[ApiSurfaceCategoryBudget] {
  [
    {
      path: "moui/core/pkg.generated.mbti",
      category: "advanced_core_protocol",
      max_count: 643,
    },
    {
      path: "moui/core/pkg.generated.mbti",
      category: "required_protocol",
      // Neutral accessibility DTOs are required cross-runtime protocol
      // surface, including their public enum/record shapes.
      max_count: 187,
    },
    {
      path: "moui/core/pkg.generated.mbti",
      category: "test_exposure",
      max_count: 0,
    },
    {
      path: "moui/core/pkg.generated.mbti",
      category: "migration_debt",
      max_count: 0,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "app_constructor",
      // Variable list rendering and grid semantics add three view-returning
      // app entrypoints; the remaining data-grid API is state-helper surface.
      max_count: 137,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "app_state_helper",
      max_count: 300,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "app_style",
      max_count: 223,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "advanced_core_protocol",
      max_count: 40,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "migration_debt",
      max_count: 0,
    },
    {
      path: "moui/views/pkg.generated.mbti",
      category: "test_exposure",
      max_count: 0,
    },
    {
      path: "moui/runtime/pkg.generated.mbti",
      category: "runtime_diagnostic",
      max_count: 469,
    },
    {
      path: "moui/runtime/pkg.generated.mbti",
      category: "required_protocol",
      max_count: 35,
    },
    {
      path: "moui/runtime/pkg.generated.mbti",
      category: "test_exposure",
      max_count: 0,
    },
    {
      path: "moui/runtime/pkg.generated.mbti",
      category: "migration_debt",
      max_count: 0,
    },
    {
      path: "moui/backend/pkg.generated.mbti",
      category: "host_contract",
      max_count: 206,
    },
    {
      path: "moui/backend/pkg.generated.mbti",
      category: "required_protocol",
      max_count: 44,
    },
    {
      path: "moui/backend/pkg.generated.mbti",
      category: "test_exposure",
      max_count: 0,
    },
    {
      path: "moui/backend/pkg.generated.mbti",
      category: "migration_debt",
      max_count: 0,
    },
    {
      path: "moui/render/pkg.generated.mbti",
      category: "renderer_contract",
      max_count: 265,
    },
    {
      path: "moui/render/pkg.generated.mbti",
      category: "required_protocol",
      max_count: 39,
    },
    {
      path: "moui/render/pkg.generated.mbti",
      category: "test_exposure",
      max_count: 0,
    },
    {
      path: "moui/render/pkg.generated.mbti",
      category: "migration_debt",
      max_count: 0,
    },
  ]
}

///|
fn api_surface_public_line(line : String) -> Bool {
  line.has_prefix("pub ") ||
  line.has_prefix("pub(open)") ||
  line.has_prefix("pub(all)") ||
  line.has_prefix("pub type ") ||
  line.has_prefix("type ")
}

///|
fn line_has_any_token(line : String, tokens : Array[String]) -> Bool {
  for token in tokens {
    if line.contains(token) {
      return true
    }
  }
  false
}

///|
fn line_has_any_prefix(line : String, prefixes : Array[String]) -> Bool {
  for prefix in prefixes {
    if line.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
fn core_api_surface_name_tokens() -> Array[String] {
  [
    "Accessibility", "ActionCommand", "Alignment", "Animation", "AppEvent", "Axis",
    "Controlled", "Badge", "Binding", "BlendMode", "Border", "Brush", "Button", "CachedLayer",
    "CheckMark", "ChoiceControl", "Color", "Command", "Component", "Composition",
    "Constraints", "ContentSize", "ControlState", "CrossAxis", "Custom", "Damage",
    "DateValue", "Declaration", "DerivedState", "Drag", "Draw", "Easing", "Effect",
    "Environment", "Feedback", "Filter", "Focus", "Font", "FormValidationTheme",
    "Frame", "Image", "Insets", "InteractionState", "Key", "Keyboard", "Layer", "Layout",
    "LinearGradient", "MainAxis", "Motion", "Navigation", "Path", "PickerTheme",
    "PlatformView", "Point", "Pointer", "Program", "Progress", "RadialGradient",
    "Radius", "Rect", "Redraw", "RoundedRect", "Saveable", "Scroll", "Semantic",
    "Shader", "Shadow", "Size", "SliderTheme", "Spacing", "State", "Subscription",
    "Surface", "Text", "Theme", "Thumb", "Tone", "Transform", "Transition", "Typography",
    "View", "VisualStyle",
  ]
}

///|
fn core_api_surface_function_prefixes() -> Array[String] {
  [
    "pub fn active_text_selection", "pub fn animated_", "pub fn cancel_component_effects",
    "pub fn clamp_int", "pub fn composition_", "pub fn default_text_commands", "pub fn delete_grapheme_range",
    "pub fn fallback_stabilize", "pub fn focus_scope_", "pub fn hit_test", "pub fn is_",
    "pub fn max_int", "pub fn min_int", "pub fn move_text", "pub fn normalize_",
    "pub fn optional_rect_union", "pub fn replace_text", "pub fn resolve_", "pub fn selected_text",
    "pub fn surrounding_", "pub fn text_",
  ]
}

///|
fn views_style_tokens() -> Array[String] {
  [
    "Style", "Theme", "theme", "Color", "Typography", "ButtonVariant", "ContainerVariant",
    "TextRole", "TextFieldVariant", "Tone", "Token", "BadgeTone", "FeedbackTone",
    "PresenceStatus", "IconName", "CrossAlign", "MainAlign", "PopoverPlacement",
    "SegmentedControlSize", "SheetPresentationMode", "ChipVariant", "DatePickerMode",
  ]
}

///|
fn views_advanced_prefixes() -> Array[String] {
  [
    "pub fn clear(", "pub fn draw_", "pub fn fill_", "pub fn stroke_", "pub fn push_",
    "pub fn pop_", "pub fn[Msg] canvas(", "pub fn[Msg] custom_layout(", "pub fn[Msg] custom_children_layout(",
    "pub fn[Msg] component(",
  ]
}

///|
fn classify_api_surface_line(path : String, line : String) -> String? {
  if !api_surface_public_line(line) {
    return None
  }
  if line.has_prefix("pub(all)") {
    if path == "moui/views/pkg.generated.mbti" {
      // pub(all) enum is the only way to expose enum variants for external
      // construction in MoonBit. Views also owns externally constructed
      // control-theme records, so classify those as styles rather than debt.
      if line.has_prefix("pub(all) enum") {
        // Fall through to semantic classification below
      } else if line_has_any_token(line, views_style_tokens()) {
        return Some("app_style")
      } else {
        return Some("migration_debt")
      }
    } else {
      return Some("required_protocol")
    }
  }
  if path == "moui/core/pkg.generated.mbti" {
    if line_has_any_token(line, core_api_surface_name_tokens()) ||
      line_has_any_prefix(line, core_api_surface_function_prefixes()) ||
      line.contains("to_any_modifier") ||
      line.contains("noop_modifier") {
      return Some("advanced_core_protocol")
    }
    return None
  }
  if path == "moui/views/pkg.generated.mbti" {
    if line.contains("PaintContext") ||
      line_has_any_prefix(line, views_advanced_prefixes()) {
      return Some("advanced_core_protocol")
    }
    if line.contains("-> @core.View[Msg]") {
      return Some("app_constructor")
    }
    if line_has_any_token(line, views_style_tokens()) {
      return Some("app_style")
    }
    return Some("app_state_helper")
  }
  if path == "moui/runtime/pkg.generated.mbti" {
    return Some("runtime_diagnostic")
  }
  if path == "moui/backend/pkg.generated.mbti" {
    return Some("host_contract")
  }
  if path == "moui/render/pkg.generated.mbti" {
    return Some("renderer_contract")
  }
  None
}

///|
fn api_surface_category_budget_exists(path : String, category : String) -> Bool {
  for budget in api_surface_classification_budgets() {
    if budget.path == path && budget.category == category {
      return true
    }
  }
  false
}

///|
fn api_surface_category_known(category : String) -> Bool {
  for known in api_surface_semantic_categories() {
    if known == category {
      return true
    }
  }
  false
}

///|
fn count_api_surface_category(
  path : String,
  text : String,
  category : String,
) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if api_surface_public_line(line) {
      match classify_api_surface_line(path, line) {
        Some(found) => if found == category { count += 1 }
        None => ()
      }
    }
  }
  count
}

///|
fn validate_api_surface_classification_text(
  path : String,
  text : String,
  failures : Array[String],
) -> Unit {
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if api_surface_public_line(line) {
      match classify_api_surface_line(path, line) {
        Some(category) =>
          if !api_surface_category_budget_exists(path, category) {
            failures.push(
              path +
              ": classification category '" +
              category +
              "' has no budget for public API line '" +
              line +
              "'",
            )
          }
        None =>
          failures.push(
            path +
            ": unclassified public API line '" +
            line +
            "'; add classification or move API to owning package",
          )
      }
    }
  }
}

///|
fn validate_api_surface_classification_budgets(
  path : String,
  text : String,
  failures : Array[String],
) -> Unit {
  for budget in api_surface_classification_budgets() {
    if budget.path == path {
      if !api_surface_category_known(budget.category) {
        failures.push(
          path +
          ": unknown API surface category budget '" +
          budget.category +
          "'",
        )
      }
      let count = count_api_surface_category(path, text, budget.category)
      println(
        "api surface classification: " +
        path +
        " " +
        budget.category +
        "=\{count}/\{budget.max_count}",
      )
      if count > budget.max_count {
        failures.push(
          path +
          ": " +
          budget.category +
          " public API count=\{count}, above classification budget \{budget.max_count}; add classification review or move API to owning package",
        )
      }
    }
  }
}

///|
fn validate_api_surface_classifications(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for path in api_surface_classification_paths() {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    validate_api_surface_classification_text(path, text, failures)
    validate_api_surface_classification_budgets(path, text, failures)
  }
}
