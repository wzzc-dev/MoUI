///|
fn translator_for(locale : String) -> @moui_i18n.Translator {
  let catalog = @moui_i18n.Catalog::from_entries([
    @moui_i18n.Message::new(locale="en", key="greeting", value="Hello, {name}!"),
    @moui_i18n.Message::new(
      locale="en-US",
      key="greeting",
      value="Howdy, {name}!",
    ),
    @moui_i18n.Message::new(
      locale="zh-Hans",
      key="greeting",
      value="你好，{name}！",
    ),
    @moui_i18n.Message::new(locale="en", key="items.one", value="{count} item"),
    @moui_i18n.Message::new(
      locale="en",
      key="items.other",
      value="{count} items",
    ),
    @moui_i18n.Message::new(
      locale="zh",
      key="items.other",
      value="{count} 个项目",
    ),
    @moui_i18n.Message::new(
      locale="en",
      key="braces",
      value="{{{name}}} / {missing}",
    ),
    @moui_i18n.Message::new(locale="invalid!!", key="ignored", value="ignored"),
  ])
  @moui_i18n.Translator::new(
    catalog~,
    locale=@moui_i18n.Locale::parse(locale).unwrap(),
    default_locale=@moui_i18n.Locale::parse("en").unwrap(),
  )
}

///|
test "Translator resolves requested locale language and default fallbacks" {
  inspect(
    translator_for("en-US").translate("greeting", values=[("name", "Ada")]),
    content="Howdy, Ada!",
  )
  inspect(
    translator_for("en-GB").translate("greeting", values=[("name", "Ada")]),
    content="Hello, Ada!",
  )
  inspect(
    translator_for("zh-Hans-CN").translate("greeting", values=[("name", "明")]),
    content="你好，明！",
  )
  inspect(
    translator_for("fr-CA").translate("greeting", values=[("name", "Ada")]),
    content="Hello, Ada!",
  )
}

///|
test "Translator marks missing messages and interpolates escaped braces" {
  let translator = translator_for("en")
  inspect(translator.translate("absent"), content="[[absent]]")
  inspect(
    translator.translate("braces", values=[("name", "Ada")]),
    content="{Ada} / {missing}",
  )
}

///|
test "Translator selects English and Chinese plural categories" {
  inspect(translator_for("en-US").translate_count("items", 1), content="1 item")
  inspect(
    translator_for("en-US").translate_count("items", 2),
    content="2 items",
  )
  inspect(
    translator_for("zh-CN").translate_count("items", 1),
    content="1 个项目",
  )
  inspect(
    translator_for("zh-CN").translate_count("items", 4),
    content="4 个项目",
  )
  inspect(translator_for("fr").translate_count("items", 2), content="2 items")
  inspect(
    translator_for("en").translate_count("missing", 1),
    content="[[missing]]",
  )
}
