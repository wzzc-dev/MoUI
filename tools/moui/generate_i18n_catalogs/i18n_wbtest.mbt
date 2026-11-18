// White-box tests for tools/moui/generate_i18n_catalogs decision logic.
// They pin locale/key validation, placeholder extraction, catalog parity
// rules, and the generated-source line layout.

///|
fn repeat_char(char : Char, count : Int32) -> String {
  let builder = StringBuilder()
  for _ in 0..<count {
    builder.write_char(char)
  }
  builder.to_string()
}

///|
fn test_catalog(
  path : String,
  locale : String,
  keys : Array[String],
) -> SourceCatalog {
  { locale, path, messages: keys.map(key => { key, one: None, other: None, }), }
}

///|
fn text_catalog(
  path : String,
  locale : String,
  key : String,
  text : String,
) -> SourceCatalog {
  { locale, path, messages: [{ key, one: Some(text), other: None, }], }
}

///|
test "valid_locale_tag accepts language-script-region forms" {
  assert_true(valid_locale_tag("en"))
  assert_true(valid_locale_tag("zh-Hans"))
  assert_true(valid_locale_tag("en-US"))
  assert_true(valid_locale_tag("es-419"))
}

///|
test "valid_locale_tag rejects malformed tags" {
  assert_false(valid_locale_tag(""))
  assert_false(valid_locale_tag("e"))
  assert_false(valid_locale_tag("english"))
  assert_false(valid_locale_tag("-en"))
  assert_false(valid_locale_tag("en-"))
  assert_false(valid_locale_tag("en-US-x"))
  assert_false(valid_locale_tag("en-1234"))
}

///|
test "valid_message_key enforces dotted identifier segments" {
  assert_true(valid_message_key("app.title"))
  assert_true(valid_message_key("a-b_c.1"))
  assert_false(valid_message_key(""))
  assert_false(valid_message_key(".app"))
  assert_false(valid_message_key("app."))
  assert_false(valid_message_key("app..title"))
  assert_false(valid_message_key("app title"))
}

///|
test "placeholders_in sorts and dedupes names" {
  match placeholders_in("Hi {name}, {count} and {name}", "messages.greeting") {
    Ok(names) => assert_eq(names, ["count", "name"])
    Err(message) => fail(message)
  }
}

///|
test "placeholders_in reports precise errors" {
  match placeholders_in("{a {b}}", "messages.x") {
    Ok(_) => fail("nested placeholder must be rejected")
    Err(message) =>
      assert_eq(message, "messages.x has a nested { in placeholder")
  }
  match placeholders_in("{a", "messages.x") {
    Ok(_) => fail("unclosed placeholder must be rejected")
    Err(message) => assert_eq(message, "messages.x has an unclosed placeholder")
  }
  match placeholders_in("{}", "messages.x") {
    Ok(_) => fail("empty placeholder must be rejected")
    Err(message) => assert_eq(message, "messages.x has an empty placeholder")
  }
  match placeholders_in("{a-b}", "messages.x") {
    Ok(_) => fail("invalid placeholder name must be rejected")
    Err(message) =>
      assert_eq(message, "messages.x has an invalid placeholder: {a-b}")
  }
  match placeholders_in("a } b", "messages.x") {
    Ok(_) => fail("unmatched closing brace must be rejected")
    Err(message) => assert_eq(message, "messages.x has an unmatched }")
  }
}

///|
test "source_locale derives the locale from the json basename" {
  assert_eq(source_locale("i18n/en.json"), Some("en"))
  assert_eq(source_locale("i18n\\zh-Hans.json"), Some("zh-Hans"))
  assert_eq(source_locale("i18n/.json"), None)
  assert_eq(source_locale("i18n/en.yaml"), None)
  assert_eq(source_basename("a/b/c.json"), "c.json")
  assert_eq(parent_dir("i18n/en.json"), "i18n")
}

///|
test "moon_string escapes quotes, slashes, and controls" {
  assert_eq(moon_string("a\"b\\c\nd\te"), "a\\\"b\\\\c\\nd\\te")
  assert_eq(moon_string("\u{01}"), "\\u{1}")
}

///|
test "generated_text_entry picks 1, 4, or 6 line layout by width" {
  let short = generated_text_entry("a", "b")
  assert_eq(short.length(), 1)
  assert_true(short[0].contains("(\"a\", GeneratedI18nMessage::Text(\"b\")),"))
  let medium = generated_text_entry("a", repeat_char('a', 44))
  assert_eq(medium.length(), 4)
  assert_eq(medium[1], "        \"a\",")
  let long = generated_text_entry("a", repeat_char('a', 47))
  assert_eq(long.length(), 6)
  assert_true(long[5].contains("),"))
}

///|
test "generated_plural_entry keeps short plurals inline and wraps long ones" {
  let short = generated_plural_entry("a", "one", "others")
  assert_eq(short.length(), 1)
  assert_true(short[0].contains("Plural(one=\"one\", other=\"others\")"))
  let long = generated_plural_entry("a", repeat_char('x', 60), "y")
  assert_eq(long.length(), 7)
}

///|
test "validate_catalogs enforces locale uniqueness and key parity" {
  match validate_catalogs([]) {
    Ok(_) => fail("empty catalog list must be rejected")
    Err(message) =>
      assert_eq(message, "manifest must list at least one catalog")
  }
  let reference = test_catalog("i18n/en.json", "en", ["app.title"])
  match
    validate_catalogs([
      reference,
      test_catalog("i18n/de.json", "de", ["app.title"]),
    ]) {
    Ok(_) => ()
    Err(message) => fail("distinct locales must pass: " + message)
  }
  match
    validate_catalogs([
      reference,
      test_catalog("i18n/en-dup.json", "en", ["app.title"]),
    ]) {
    Ok(_) => fail("duplicate locale must be rejected")
    Err(message) => assert_eq(message, "i18n/en-dup.json duplicates locale: en")
  }
  match validate_catalogs([reference, test_catalog("i18n/de.json", "de", [])]) {
    Ok(_) => fail("missing message key must be rejected")
    Err(message) =>
      assert_eq(message, "i18n/de.json is missing message key: app.title")
  }
  match
    validate_catalogs([
      reference,
      test_catalog("i18n/de.json", "de", ["app.extra", "app.title"]),
    ]) {
    Ok(_) => fail("unexpected message key must be rejected")
    Err(message) =>
      assert_eq(message, "i18n/de.json has unexpected message key: app.extra")
  }
}

///|
test "validate_catalogs compares placeholder sets across catalogs" {
  let reference = text_catalog("i18n/en.json", "en", "app.title", "Hi {name}")
  match
    validate_catalogs([
      reference,
      text_catalog("i18n/de.json", "de", "app.title", "Hallo {nombre}"),
    ]) {
    Ok(_) => fail("placeholder mismatch must be rejected")
    Err(message) =>
      assert_eq(
        message, "i18n/de.json.messages.app.title placeholder set differs from i18n/en.json",
      )
  }
  let plural : SourceCatalog = {
    locale: "en",
    path: "i18n/plural.json",
    messages: [
      { key: "items", one: Some("{count} item"), other: Some("items"), },
    ],
  }
  match validate_catalogs([plural]) {
    Ok(_) => fail("plural placeholder mismatch must be rejected")
    Err(message) =>
      assert_eq(
        message, "i18n/plural.json.messages.items plural one and other forms must use the same placeholders",
      )
  }
}
