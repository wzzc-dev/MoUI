///|
fn category(locale : String, count : Int32) -> String {
  @moui_i18n.Locale::parse(locale).unwrap().plural_category(count).key()
}

///|
test "other-only languages never select a dedicated category" {
  for locale in ["zh", "zh-Hans-CN", "ja", "ko", "th", "vi", "id"] {
    for count in [0, 1, 2, 100] {
      inspect(category(locale, count), content="other")
    }
  }
}

///|
test "one-only languages select one for exactly one" {
  for locale in ["en", "en-US", "de", "nl", "sv", "da", "fi", "tr", "el"] {
    inspect(category(locale, 0), content="other")
    inspect(category(locale, 1), content="one")
    inspect(category(locale, 2), content="other")
    inspect(category(locale, 1000000), content="other")
  }
  inspect(category("en", -1), content="one")
}

///|
test "French and Portuguese one covers zero and one, many covers millions" {
  for locale in ["fr", "fr-FR", "pt", "pt-BR", "pt-PT"] {
    inspect(category(locale, 0), content="one")
    inspect(category(locale, 1), content="one")
    inspect(category(locale, 2), content="other")
    inspect(category(locale, 999999), content="other")
    inspect(category(locale, 1000000), content="many")
    inspect(category(locale, 2000000), content="many")
    inspect(category(locale, 1000001), content="other")
  }
  inspect(category("fr", -1), content="one")
}

///|
test "Spanish and Italian one excludes zero, many covers millions" {
  for locale in ["es", "it"] {
    inspect(category(locale, 0), content="other")
    inspect(category(locale, 1), content="one")
    inspect(category(locale, 2), content="other")
    inspect(category(locale, 1000000), content="many")
    inspect(category(locale, 1000001), content="other")
  }
}

///|
test "Russian and Ukrainian mod-10 and mod-100 boundaries" {
  for locale in ["ru", "uk"] {
    inspect(category(locale, 0), content="many")
    inspect(category(locale, 1), content="one")
    inspect(category(locale, 2), content="few")
    inspect(category(locale, 4), content="few")
    inspect(category(locale, 5), content="many")
    inspect(category(locale, 9), content="many")
    inspect(category(locale, 11), content="many")
    inspect(category(locale, 12), content="many")
    inspect(category(locale, 14), content="many")
    inspect(category(locale, 15), content="many")
    inspect(category(locale, 21), content="one")
    inspect(category(locale, 22), content="few")
    inspect(category(locale, 25), content="many")
    inspect(category(locale, 100), content="many")
    inspect(category(locale, 101), content="one")
    inspect(category(locale, 102), content="few")
    inspect(category(locale, 111), content="many")
    inspect(category(locale, 112), content="many")
    inspect(category(locale, 121), content="one")
  }
  inspect(category("ru", -21), content="one")
}

///|
test "Polish many covers 101 and 201 unlike Russian" {
  inspect(category("pl", 0), content="many")
  inspect(category("pl", 1), content="one")
  inspect(category("pl", 2), content="few")
  inspect(category("pl", 4), content="few")
  inspect(category("pl", 5), content="many")
  inspect(category("pl", 12), content="many")
  inspect(category("pl", 14), content="many")
  inspect(category("pl", 21), content="many")
  inspect(category("pl", 22), content="few")
  inspect(category("pl", 100), content="many")
  inspect(category("pl", 101), content="many")
  inspect(category("pl", 102), content="few")
  inspect(category("pl", 112), content="many")
  inspect(category("pl", 121), content="many")
}

///|
test "Czech few covers two through four only" {
  inspect(category("cs", 0), content="other")
  inspect(category("cs", 1), content="one")
  inspect(category("cs", 2), content="few")
  inspect(category("cs", 4), content="few")
  inspect(category("cs", 5), content="other")
  inspect(category("cs", 22), content="other")
  inspect(category("cs", 100), content="other")
}

///|
test "Arabic selects all six categories at CLDR thresholds" {
  inspect(category("ar", 0), content="zero")
  inspect(category("ar", 1), content="one")
  inspect(category("ar", 2), content="two")
  inspect(category("ar", 3), content="few")
  inspect(category("ar", 10), content="few")
  inspect(category("ar", 11), content="many")
  inspect(category("ar", 26), content="many")
  inspect(category("ar", 99), content="many")
  inspect(category("ar", 100), content="other")
  inspect(category("ar", 101), content="other")
  inspect(category("ar", 102), content="other")
  inspect(category("ar", 103), content="few")
  inspect(category("ar", 110), content="few")
  inspect(category("ar", 111), content="many")
  inspect(category("ar", 200), content="other")
  inspect(category("ar", 1000000), content="other")
  inspect(category("ar", -2), content="two")
}

///|
test "Hindi one covers zero and one" {
  inspect(category("hi", 0), content="one")
  inspect(category("hi", 1), content="one")
  inspect(category("hi", 2), content="other")
}

///|
test "unlisted languages fall back to the root other category" {
  inspect(category("zz", 0), content="other")
  inspect(category("zz", 1), content="other")
}

///|
test "plural category keys map to catalog suffixes" {
  inspect(@moui_i18n.PluralCategory::Zero.key(), content="zero")
  inspect(@moui_i18n.PluralCategory::One.key(), content="one")
  inspect(@moui_i18n.PluralCategory::Two.key(), content="two")
  inspect(@moui_i18n.PluralCategory::Few.key(), content="few")
  inspect(@moui_i18n.PluralCategory::Many.key(), content="many")
  inspect(@moui_i18n.PluralCategory::Other.key(), content="other")
}
