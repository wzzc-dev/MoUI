///|
fn test_release_coupling() -> ReleaseCoupling {
  {
    mode: "synchronized-line",
    line: "0.3.x",
    adr: "docs/decisions/0055-synchronized-release-line.md",
    base_only_patch: "not-offered",
    compatibility_matrix: "deferred",
    evidence: "release catalog",
  }
}

///|
fn test_portfolio_route(id : String, intent : String) -> PortfolioRoute {
  {
    id,
    owner: "platform/test",
    intent,
    review_date: "2026-11-05",
    review_trigger: "test trigger",
    graduation: "test graduation",
    retirement: "test retirement",
  }
}

///|
test "ISO dates reject malformed and impossible values" {
  assert_true(valid_iso_date("2026-11-05"))
  assert_true(valid_iso_date("2024-02-29"))
  assert_false(valid_iso_date("2026-02-29"))
  assert_false(valid_iso_date("2026-13-01"))
  assert_false(valid_iso_date("2026-1-01"))
  assert_false(valid_iso_date("not-a-date"))
}

///|
test "intent maps to product class and readiness" {
  match intent_expectation("product") {
    Some(("committed", true)) => ()
    _ => fail("product intent must require committed/ready")
  }
  match intent_expectation("lab") {
    Some(("experimental", false)) => ()
    _ => fail("lab intent must require experimental/not-ready")
  }
  match intent_expectation("diagnostic") {
    Some(("diagnostic", false)) => ()
    _ => fail("diagnostic intent must require diagnostic/not-ready")
  }
  assert_true(intent_expectation("unknown") is None)
}

///|
test "release line accepts only the synchronized major/minor" {
  assert_true(version_matches_release_line("0.3.0", "0.3.x"))
  assert_true(version_matches_release_line("0.3.1", "0.3.x"))
  assert_false(version_matches_release_line("0.4.0", "0.3.x"))
  assert_false(version_matches_release_line("0.30.0", "0.3.x"))
  assert_true(release_line_prefix("0.3.x") == Some("0.3."))
}

///|
test "generated block replacement is stable and rejects duplicates" {
  let source = "before\n<!-- BEGIN -->\nold\n<!-- END -->\nafter\n"
  match
    replace_generated_block(source, "<!-- BEGIN -->", "<!-- END -->", "new") {
    Ok(text) =>
      assert_eq(text, "before\n<!-- BEGIN -->\nnew\n<!-- END -->\nafter\n")
    Err(_) => fail("expected generated block replacement")
  }
  let duplicate = source + source
  match
    replace_generated_block(duplicate, "<!-- BEGIN -->", "<!-- END -->", "new") {
    Ok(_) => fail("duplicate markers must fail")
    Err(message) => assert_true(message.contains("exactly one"))
  }
}

///|
test "stale component APIs are rejected unless explicitly negated" {
  assert_eq(
    stale_component_api("Use @core.Component::new for this control"),
    Some("@core.component::new"),
  )
  assert_eq(stale_component_api("No `SaveableStateStore` is provided"), None)
  assert_eq(stale_component_api("不再提供 ComponentContext"), None)
  assert_eq(
    stale_component_api("component-scoped effects own cleanup"),
    Some("component-scoped effects"),
  )
  assert_eq(
    stale_component_api(
      "ComponentContext is required for this adapter，且不会暴露 runtime tree",
    ),
    Some("componentcontext"),
  )
}

///|
test "HarmonyOS experimental claims conflict with committed status" {
  assert_true(
    harmonyos_status_conflict(
      "HarmonyOS embedded-runtime route (`experimental`)",
    ),
  )
  assert_false(
    harmonyos_status_conflict(
      "HarmonyOS is committed; Android and iOS remain experimental.",
    ),
  )
  assert_false(harmonyos_status_conflict("Android remains experimental."))
}

///|
test "generated route table keeps catalog facts and governance separate" {
  let matrix : PlatformFacts = {
    routes: [
      {
        id: "harmonyos-skia",
        product_class: "committed",
        ready: true,
        evidence_file: "checks/platforms/harmonyos.json",
        architecture_variant: false,
      },
    ],
  }
  let portfolio : PortfolioCatalog = {
    reviewed_on: "2026-11-05",
    release_coupling: test_release_coupling(),
    routes: [test_portfolio_route("harmonyos-skia", "product")],
    modules: [],
  }
  let table = generated_route_table(matrix, portfolio)
  assert_true(
    table.contains(
      "| `harmonyos-skia` | product | `committed` | yes | `platform/test` | 2026-11-05 | `checks/platforms/harmonyos.json` |",
    ),
  )
  assert_true(table.contains("checks/portfolio-governance.json"))
}

///|
test "route coverage reports missing and stale governance entries" {
  let matrix : PlatformFacts = {
    routes: [
      {
        id: "route-a",
        product_class: "committed",
        ready: true,
        evidence_file: "a.json",
        architecture_variant: false,
      },
    ],
  }
  let portfolio : PortfolioCatalog = {
    reviewed_on: "2026-11-05",
    release_coupling: test_release_coupling(),
    routes: [test_portfolio_route("route-b", "lab")],
    modules: [],
  }
  let failures : Array[String] = []
  validate_route_coverage(matrix, portfolio, failures)
  assert_true(
    failures.any(message => message.contains("missing route: route-a")),
  )
  assert_true(failures.any(message => message.contains("stale route: route-b")))
}

///|
test "intent mismatch reports product class and readiness failures" {
  let fact : PlatformRouteFacts = {
    id: "route-a",
    product_class: "experimental",
    ready: false,
    evidence_file: "a.json",
    architecture_variant: false,
  }
  let failures : Array[String] = []
  validate_route_intent(
    fact,
    test_portfolio_route("route-a", "product"),
    failures,
  )
  assert_eq(failures.length(), 2)
  assert_true(failures[0].contains("requires productClass 'committed'"))
  assert_true(failures[1].contains("requires ready=true"))
}

///|
test "module coverage excludes internal release modules" {
  let release : ReleaseFacts = {
    release_stages: ["addons"],
    modules: [
      {
        name: "wzzc-dev/public",
        directory: "public",
        publication: "public",
        release_stage: "addons",
      },
      {
        name: "wzzc-dev/internal_tests",
        directory: "internal_tests",
        publication: "internal",
        release_stage: "",
      },
    ],
  }
  let portfolio : PortfolioCatalog = {
    reviewed_on: "2026-11-05",
    release_coupling: test_release_coupling(),
    routes: [],
    modules: [
      {
        name: "wzzc-dev/public",
        owner: "addons/public",
        intent: "product",
        review_date: "2026-11-05",
        review_trigger: "test",
        evidence: "test",
        graduation: "test",
        retirement: "test",
      },
    ],
  }
  let failures : Array[String] = []
  validate_module_coverage(release, portfolio, failures)
  assert_true(failures.is_empty())
}
