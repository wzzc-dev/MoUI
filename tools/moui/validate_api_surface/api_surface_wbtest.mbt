// White-box tests for tools/moui/validate_api_surface decision logic.
// They pin public-line detection, category classification and budgets,
// unclassified-line failures, and the app constructor return rules.

///|
fn budget_max_count(path : String, category : String) -> Int32? {
  for budget in api_surface_classification_budgets() {
    if budget.path == path && budget.category == category {
      return Some(budget.max_count)
    }
  }
  None
}

///|
test "api_surface_public_line only accepts public declarations" {
  assert_true(api_surface_public_line("pub fn render() -> Unit"))
  assert_true(api_surface_public_line("pub(open) struct Thing {}"))
  assert_true(api_surface_public_line("pub(all) enum Kind {}"))
  assert_true(api_surface_public_line("pub type Alias = Int"))
  assert_true(api_surface_public_line("type Private = Int"))
  assert_false(api_surface_public_line("fn hidden() -> Unit"))
  assert_false(api_surface_public_line("  pub fn indented() -> Unit"))
  assert_false(api_surface_public_line(""))
}

///|
test "classify_api_surface_line routes views declarations" {
  let views = "moui/views/pkg.generated.mbti"
  assert_eq(
    classify_api_surface_line(views, "pub fn[Msg] button() -> @core.View[Msg]"),
    Some("app_constructor"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub(all) struct Placed { x : Int }"),
    Some("app_constructor"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub(all) struct Presentation { x : Int }"),
    Some("app_state_helper"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub(all) struct Theme { x : Int }"),
    Some("app_style"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub(all) struct Widget { x : Int }"),
    Some("migration_debt"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub fn paint(ctx : PaintContext) -> Unit"),
    Some("advanced_core_protocol"),
  )
  assert_eq(
    classify_api_surface_line(views, "pub fn helper(state : State) -> Unit"),
    Some("app_state_helper"),
  )
  assert_eq(classify_api_surface_line(views, "fn hidden() -> Unit"), None)
}

///|
test "classify_api_surface_line routes non-views packages" {
  assert_eq(
    classify_api_surface_line(
      "moui/core/pkg.generated.mbti", "pub fn to_any_modifier() -> Unit",
    ),
    Some("advanced_core_protocol"),
  )
  assert_eq(
    classify_api_surface_line(
      "moui/core/pkg.generated.mbti", "pub fn zebra() -> Unit",
    ),
    None,
  )
  assert_eq(
    classify_api_surface_line(
      "moui/core/pkg.generated.mbti", "pub(all) struct Extra {}",
    ),
    Some("required_protocol"),
  )
  assert_eq(
    classify_api_surface_line(
      "moui/runtime/pkg.generated.mbti", "pub fn step() -> Unit",
    ),
    Some("runtime_diagnostic"),
  )
  assert_eq(
    classify_api_surface_line(
      "moui/backend/pkg.generated.mbti", "pub fn start() -> Unit",
    ),
    Some("host_contract"),
  )
  assert_eq(
    classify_api_surface_line(
      "moui/render/pkg.generated.mbti", "pub fn draw() -> Unit",
    ),
    Some("renderer_contract"),
  )
  assert_eq(
    classify_api_surface_line(
      "unknown/pkg.generated.mbti", "pub fn draw() -> Unit",
    ),
    None,
  )
}

///|
test "count_api_surface_category counts only the requested category" {
  let text =
    #|pub fn[Msg] button() -> @core.View[Msg]
    #|pub(all) struct Placed { x : Int }
    #|pub fn helper(state : State) -> Unit
    #|fn private_helper() -> Unit
  let views = "moui/views/pkg.generated.mbti"
  assert_eq(count_api_surface_category(views, text, "app_constructor"), 2)
  assert_eq(count_api_surface_category(views, text, "app_state_helper"), 1)
  assert_eq(count_api_surface_category(views, text, "migration_debt"), 0)
  let core = "moui/core/pkg.generated.mbti"
  assert_eq(
    count_api_surface_category(
      core, "pub fn zebra() -> Unit", "required_protocol",
    ),
    0,
  )
}

///|
test "classification failures name unclassified core lines" {
  let failures : Array[String] = []
  validate_api_surface_classification_text(
    "moui/core/pkg.generated.mbti", "pub fn zebra() -> Unit\nfn hidden() -> Unit",
    failures,
  )
  assert_eq(failures.length(), 1)
  assert_eq(
    failures[0],
    "moui/core/pkg.generated.mbti: unclassified public API line 'pub fn zebra() -> Unit'; add classification or move API to owning package",
  )
  let views_failures : Array[String] = []
  validate_api_surface_classification_text(
    "moui/views/pkg.generated.mbti", "pub fn[Msg] button() -> @core.View[Msg]\npub fn helper(state : State) -> Unit",
    views_failures,
  )
  assert_eq(views_failures.length(), 0)
}

///|
test "classification budgets declare the expected ceilings" {
  assert_eq(
    budget_max_count("moui/core/pkg.generated.mbti", "advanced_core_protocol"),
    Some(1306),
  )
  assert_eq(
    budget_max_count("moui/core/pkg.generated.mbti", "required_protocol"),
    Some(190),
  )
  assert_eq(
    budget_max_count("moui/render/pkg.generated.mbti", "renderer_contract"),
    Some(287),
  )
  assert_eq(
    budget_max_count("moui/render/pkg.generated.mbti", "required_protocol"),
    Some(39),
  )
  assert_eq(
    budget_max_count("moui/render/pkg.generated.mbti", "host_contract"),
    None,
  )
  assert_true(
    api_surface_category_budget_exists(
      "moui/views/pkg.generated.mbti", "app_constructor",
    ),
  )
  assert_true(api_surface_category_known("migration_debt"))
  assert_false(api_surface_category_known("bogus"))
}

///|
test "view_return_rules cover every app constructor" {
  let rules = view_return_rules()
  assert_eq(rules.length(), 15)
  assert_true(rules.any(rule => rule.name == "button"))
  assert_true(rules.any(rule => rule.name == "custom_children_layout"))
  assert_true(rules.any(rule => rule.name == "datepicker"))
  for rule in rules {
    assert_true(rule.signature_prefix.has_prefix("pub fn[Msg] "))
    assert_eq(rule.return_token, "-> @core.View[Msg]")
  }
}
