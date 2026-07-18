///|
/// Adapts the checked-in generated catalog data to the pure `moui_i18n` addon.
/// The source data is `website/app/i18n/*.json`; refresh
/// `i18n_catalog_generated.mbt` with `scripts/generate-i18n-catalogs.mjs`.
fn website_i18n_messages() -> Array[@i18n.Message] {
  let messages : Array[@i18n.Message] = []
  for catalog in generated_i18n_catalogs {
    for pair in catalog.messages {
      let (key, message) = pair
      match message {
        GeneratedI18nMessage::Text(value) =>
          messages.push(@i18n.Message::new(locale=catalog.locale, key~, value~))
        GeneratedI18nMessage::Plural(one~, other~) => {
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
fn website_translator(locale : String) -> @i18n.Translator {
  let default_locale = @i18n.Locale::parse("en-US").unwrap()
  let requested = @i18n.Locale::parse(locale).unwrap_or(default_locale)
  @i18n.Translator::new(
    catalog=@i18n.Catalog::from_entries(website_i18n_messages()),
    locale=requested,
    default_locale~,
  )
}

///|
fn website_message(locale : String, key : String) -> String {
  website_translator(locale).translate(key)
}

///|
fn website_message_with(
  locale : String,
  key : String,
  values : Array[(String, String)],
) -> String {
  website_translator(locale).translate(key, values~)
}
