///|
/// 界面国际化：中英双语 catalog（zh-Hans 默认，en 回退）。
/// UI 文案全部过 moui_i18n；领域层（DSL/IR/提案）保持语言中立，
/// 其展示名（内建命令、积木标签、错误）也在此翻译。

///|
/// 界面语言：与 DSL 语言表同一组 tag（zh-Hans / en）。
pub(all) enum UiLanguage {
  ZhHans
  En
}

///|
pub fn UiLanguage::tag(self : UiLanguage) -> String {
  match self {
    ZhHans => "zh-Hans"
    En => "en"
  }
}

///|
pub fn ui_language_from_tag(tag : String) -> UiLanguage {
  match @studio_lang.parse_language(tag) {
    Some(language) =>
      match language {
        @studio_lang.ZhHans => ZhHans
        @studio_lang.En => En
      }
    None => ZhHans
  }
}

///|
/// DSL 语言（代码视图/关键字渲染用）。
pub fn UiLanguage::dsl_language(self : UiLanguage) -> @studio_lang.Language {
  match self {
    ZhHans => @studio_lang.ZhHans
    En => @studio_lang.En
  }
}

///|
/// 对方语言的显示名（切换按钮显示目标语言）。
pub fn UiLanguage::other_language_label(self : UiLanguage) -> String {
  match self {
    ZhHans => "English"
    En => "中文"
  }
}

///|
/// 数据源 app/i18n/{zh-Hans,en}.json 经 scripts/generate-i18n-catalogs.mjs
/// 生成为 i18n_catalog_generated.mbt（DO NOT EDIT；--check 在 pr profile）。
fn studio_messages() -> Array[@i18n.Message] {
  let messages : Array[@i18n.Message] = []
  for catalog in generated_i18n_catalogs {
    for pair in catalog.messages {
      let (key, message) = pair
      match message {
        Text(value) =>
          messages.push(@i18n.Message::new(locale=catalog.locale, key~, value~))
        Plural(one~, other~) => {
          messages.push(
            @i18n.Message::new(
              locale=catalog.locale,
              key=key + ".one",
              value=one,
            ),
          )
          messages.push(
            @i18n.Message::new(
              locale=catalog.locale,
              key=key + ".other",
              value=other,
            ),
          )
        }
      }
    }
  }
  messages
}

///|
/// 构造翻译器（default locale = zh-Hans）。
pub fn translator_for(language : UiLanguage) -> @i18n.Translator {
  let catalog = @i18n.Catalog::from_entries(studio_messages())
  let locale = match language {
    ZhHans => "zh-Hans"
    En => "en"
  }
  let locale = locale_of(locale).unwrap_or(locale_of("zh-Hans").unwrap())
  let default_locale = locale_of("zh-Hans").unwrap_or(locale_of("en").unwrap())
  @i18n.Translator::new(catalog~, locale~, default_locale~)
}

///|
/// 文本 → Locale?。
fn locale_of(text : String) -> @i18n.Locale? {
  @i18n.Locale::parse(text)
}

///|
/// 常用取词（视图层统一入口）。
pub fn text(t : @i18n.Translator, key : String) -> String {
  t.translate(key)
}

///|
/// 带参取词。
pub fn text_with(
  t : @i18n.Translator,
  key : String,
  values : Array[(String, String)],
) -> String {
  t.translate(key, values~)
}

///|
/// DSL 语言错误的本地化消息。
pub fn error_message(
  t : @i18n.Translator,
  error : @studio_lang.LangError,
) -> String {
  let kind = error.kind()
  let key = match kind {
    @studio_lang.UnterminatedString => "err.unterminated_string"
    @studio_lang.BadNumber => "err.bad_number"
    @studio_lang.ExpectKeyword => "err.expect_keyword"
    @studio_lang.UnexpectedToken => "err.unexpected_token"
    @studio_lang.ReservedWord => "err.reserved_word"
    @studio_lang.MissingEnd => "err.missing_end"
    @studio_lang.UnknownName => "err.unknown_name"
    @studio_lang.NotDeclared => "err.not_declared"
    @studio_lang.TypeMismatch => "err.type_mismatch"
    @studio_lang.ArityMismatch => "err.arity_mismatch"
    @studio_lang.StepBudget => "err.step_budget"
    @studio_lang.DivideByZero => "err.divide_by_zero"
    @studio_lang.BadLoopCount => "err.bad_loop_count"
    @studio_lang.UnknownBuiltin => "err.unknown_builtin"
    @studio_lang.BreakOutsideLoop => "err.break_outside_loop"
  }
  let line = if error.line() > 0 {
    text_with(t, "err.line", [("line", "\{error.line()}")])
  } else {
    ""
  }
  text_with(t, key, [("a", error.a()), ("b", error.b())]) + line
}

///|
/// 编译轨运行期错误的本地化消息（`compiled_runtime.ErrorKind` 与
/// 解释轨 `LangError` kind 是同一批语义，走同一组 err.* 键）。
pub fn compiled_error_message(
  t : @i18n.Translator,
  error : @compiled_runtime.ErrorDetails,
) -> String {
  let key = match error.kind {
    @compiled_runtime.TypeMismatch => "err.type_mismatch"
    @compiled_runtime.NotDeclared => "err.not_declared"
    @compiled_runtime.DivideByZero => "err.divide_by_zero"
    @compiled_runtime.BadLoopCount => "err.bad_loop_count"
    @compiled_runtime.UnknownBuiltin => "err.unknown_builtin"
    @compiled_runtime.StepBudget => "err.step_budget"
  }
  let line = if error.line > 0 {
    text_with(t, "err.line", [("line", "\{error.line}")])
  } else {
    ""
  }
  text_with(t, key, [("a", error.a), ("b", error.b)]) + line
}
