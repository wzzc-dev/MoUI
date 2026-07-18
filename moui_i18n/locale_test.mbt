///|
test "Locale parses and canonicalizes language script and region" {
  let locale = @moui_i18n.Locale::parse(" ZH_hANS_cn ")
  assert_true(locale is Some(_))
  let locale = locale.unwrap()
  inspect(locale.language(), content="zh")
  guard locale.script() is Some(script) else { fail("expected script") }
  inspect(script, content="Hans")
  guard locale.region() is Some(region) else { fail("expected region") }
  inspect(region, content="CN")
  inspect(locale.canonical(), content="zh-Hans-CN")
}

///|
test "Locale rejects malformed and duplicate subtags" {
  assert_true(@moui_i18n.Locale::parse("") is None)
  assert_true(@moui_i18n.Locale::parse("e") is None)
  assert_true(@moui_i18n.Locale::parse("en--US") is None)
  assert_true(@moui_i18n.Locale::parse("en-US-GB") is None)
  assert_true(@moui_i18n.Locale::parse("en-Latn-Cyrl") is None)
  assert_true(@moui_i18n.Locale::parse("en-419-US") is None)
}

///|
test "Locale fallback candidates are deterministic" {
  let zh = @moui_i18n.Locale::parse("zh-Hans-CN").unwrap()
  guard zh.fallback_candidates() is ["zh-Hans-CN", "zh-Hans", "zh"] else {
    fail("unexpected Chinese candidates")
  }
  let english = @moui_i18n.Locale::parse("en-US").unwrap()
  guard english.fallback_candidates() is ["en-US", "en"] else {
    fail("unexpected English candidates")
  }
}
