// White-box tests for the dead-message gate: lexical stripping, enum body and
// variant extraction, construction-site detection, and catalog parsing.

///|
/// Renders a parse result as text so catalog diagnostics can be asserted
/// without requiring `Eq`/`Debug` on the internal `Catalog` struct.
fn catalog_text(result : Result[Catalog, String]) -> String {
  match result {
    Err(message) => message
    Ok(_) => "<ok>"
  }
}

///|
test "strip_comments_and_strings blanks payloads but keeps line structure" {
  let source = "enum Msg {\n  Home(String), // Home is constructed here\n}\n"
  let stripped = strip_comments_and_strings(source)
  assert_true(!stripped.contains("Home is constructed here"))
  assert_true(stripped.contains("enum Msg"))
  // String literals are masked as well; only code remains.
  let quoted = strip_comments_and_strings("show(\"Home\")\n")
  assert_true(!quoted.contains("Home"))
  assert_true(quoted.contains("show"))
  // Newlines survive masking, so reported line numbers stay aligned.
  assert_eq(stripped.split("\n").count(), source.split("\n").count())
}

///|
test "enum_body and enum_variants handle nested and multi-line payloads" {
  // MoonBit enums in this repo are newline-separated without trailing commas.
  let source = "pub(all) enum Msg {\n  Home\n  Settings(String)\n  Nested(Array[Int], Msg)\n  Dialog(\n    String,\n  )\n  // trailing note\n}\n"
  let body = match enum_body(source, "Msg") {
    Some(value) => value
    None => ""
  }
  assert_true(body != "")
  assert_eq(enum_variants(body), ["Home", "Settings", "Nested", "Dialog"])
  assert_true(enum_body(source, "Missing") is None)
}

///|
test "has_construction_site separates construction from pattern positions" {
  assert_true(has_construction_site("let msg = Home", "Home"))
  assert_true(has_construction_site("dispatch(Settings(\"x\"))", "Settings"))
  // Qualified references, match arms, `is` checks and `|` patterns are uses,
  // not constructions.
  assert_true(!has_construction_site("@pkg.Home", "Home"))
  assert_true(!has_construction_site("match msg { Home => 0; _ => 1 }", "Home"))
  assert_true(
    !has_construction_site("match msg { is Home => 0; _ => 1 }", "Home"),
  )
  assert_true(!has_construction_site("| Home", "Home"))
  // Identifier boundaries matter: `Homepage` does not construct `Home`.
  assert_true(!has_construction_site("Homepage", "Home"))
}

///|
test "parse_catalog reports precise diagnostics and accepts empty catalogs" {
  assert_eq(catalog_text(parse_catalog("{")), "catalog is not valid JSON")
  assert_eq(
    catalog_text(parse_catalog("{\"enums\":[{\"path\":\"a.mbt\"}]}")),
    "catalog entry missing \"name\"",
  )
  assert_eq(
    catalog_text(parse_catalog("{\"enums\":[{\"name\":\"Msg\"}]}")),
    "catalog entry \"Msg\" missing \"path\"",
  )
  assert_eq(
    catalog_text(
      parse_catalog("{\"enums\":[{\"name\":\"Msg\",\"path\":\"a.mbt\"}]}"),
    ),
    "catalog entry \"Msg\" has no scanRoots",
  )
  assert_eq(
    catalog_text(
      parse_catalog(
        "{\"enums\":[{\"name\":\"Msg\",\"path\":\"a.mbt\",\"scanRoots\":[\".\"],\"waivers\":[{\"variant\":\"Home\"}]}]}",
      ),
    ),
    "waiver \"Home\" in \"Msg\" must carry a reason",
  )
  let valid = "{\"enums\":[{\"name\":\"Msg\",\"path\":\"a.mbt\",\"scanRoots\":[\".\"]}]}"
  assert_eq(catalog_text(parse_catalog(valid)), "<ok>")
  // An empty catalog is valid: no example currently registers a dead-UI gate.
  assert_eq(catalog_text(parse_catalog("{\"enums\":[]}")), "<ok>")
}
