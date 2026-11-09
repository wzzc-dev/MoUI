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

///|
test "Translator selects Slavic and Arabic plural variants" {
  let catalog = @moui_i18n.Catalog::from_entries([
    @moui_i18n.Message::new(
      locale="ru",
      key="files.one",
      value="{count} файл",
    ),
    @moui_i18n.Message::new(
      locale="ru",
      key="files.few",
      value="{count} файла",
    ),
    @moui_i18n.Message::new(
      locale="ru",
      key="files.many",
      value="{count} файлов",
    ),
    @moui_i18n.Message::new(
      locale="ru",
      key="files.other",
      value="{count} файла (прочее)",
    ),
    @moui_i18n.Message::new(
      locale="ar",
      key="files.zero",
      value="لا ملفات",
    ),
    @moui_i18n.Message::new(
      locale="ar",
      key="files.one",
      value="ملف واحد",
    ),
    @moui_i18n.Message::new(locale="ar", key="files.two", value="ملفان"),
    @moui_i18n.Message::new(
      locale="ar",
      key="files.few",
      value="{count} ملفات",
    ),
    @moui_i18n.Message::new(
      locale="ar",
      key="files.many",
      value="{count} ملفًا",
    ),
    @moui_i18n.Message::new(
      locale="ar",
      key="files.other",
      value="{count} ملف",
    ),
  ])
  let russian = @moui_i18n.Translator::new(
    catalog~,
    locale=@moui_i18n.Locale::parse("ru").unwrap(),
    default_locale=@moui_i18n.Locale::parse("ru").unwrap(),
  )
  inspect(russian.translate_count("files", 1), content="1 файл")
  inspect(russian.translate_count("files", 2), content="2 файла")
  inspect(russian.translate_count("files", 5), content="5 файлов")
  inspect(russian.translate_count("files", 21), content="21 файл")
  inspect(russian.translate_count("files", 112), content="112 файлов")
  let arabic = @moui_i18n.Translator::new(
    catalog~,
    locale=@moui_i18n.Locale::parse("ar").unwrap(),
    default_locale=@moui_i18n.Locale::parse("ar").unwrap(),
  )
  inspect(arabic.translate_count("files", 0), content="لا ملفات")
  inspect(arabic.translate_count("files", 1), content="ملف واحد")
  inspect(arabic.translate_count("files", 2), content="ملفان")
  inspect(arabic.translate_count("files", 3), content="3 ملفات")
  inspect(arabic.translate_count("files", 11), content="11 ملفًا")
  inspect(arabic.translate_count("files", 100), content="100 ملف")
}

///|
test "Translator falls back to the other variant for sparse plural catalogs" {
  let catalog = @moui_i18n.Catalog::from_entries([
    @moui_i18n.Message::new(
      locale="ru",
      key="files.one",
      value="{count} файл",
    ),
    @moui_i18n.Message::new(
      locale="ru",
      key="files.other",
      value="{count} файлов",
    ),
  ])
  let translator = @moui_i18n.Translator::new(
    catalog~,
    locale=@moui_i18n.Locale::parse("ru").unwrap(),
    default_locale=@moui_i18n.Locale::parse("ru").unwrap(),
  )
  inspect(translator.translate_count("files", 1), content="1 файл")
  inspect(translator.translate_count("files", 2), content="2 файлов")
  inspect(translator.translate_count("files", 5), content="5 файлов")
  inspect(translator.translate_count("absent", 5), content="[[absent]]")
}

///|
test "Translator selects French million variants" {
  let catalog = @moui_i18n.Catalog::from_entries([
    @moui_i18n.Message::new(locale="fr", key="views.one", value="{count} vue"),
    @moui_i18n.Message::new(
      locale="fr",
      key="views.many",
      value="{count} de vues",
    ),
    @moui_i18n.Message::new(
      locale="fr",
      key="views.other",
      value="{count} vues",
    ),
  ])
  let translator = @moui_i18n.Translator::new(
    catalog~,
    locale=@moui_i18n.Locale::parse("fr").unwrap(),
    default_locale=@moui_i18n.Locale::parse("fr").unwrap(),
  )
  inspect(translator.translate_count("views", 0), content="0 vue")
  inspect(translator.translate_count("views", 1), content="1 vue")
  inspect(translator.translate_count("views", 2), content="2 vues")
  inspect(
    translator.translate_count("views", 1000000),
    content="1000000 de vues",
  )
}
