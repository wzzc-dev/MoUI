///|
/// A static translation entry in a catalog.
pub(all) struct Message {
  locale : String
  key : String
  value : String
}

///|
/// Constructs a static translation entry.
pub fn Message::new(
  locale~ : String,
  key~ : String,
  value~ : String,
) -> Message {
  { locale, key, value }
}

///|
/// An in-memory catalog indexed by canonical locale and message key.
pub struct Catalog {
  messages : Map[String, Map[String, String]]
}

///|
/// Builds a catalog from static message entries. Entries with invalid locale
/// identifiers are ignored. Later entries replace earlier entries with the
/// same locale and key.
pub fn Catalog::from_entries(entries : ArrayView[Message]) -> Catalog {
  let messages : Map[String, Map[String, String]] = Map([])
  for entry in entries {
    match Locale::parse(entry.locale) {
      Some(locale) => {
        let locale_key = locale.canonical()
        let localized = messages.get_or_init(locale_key, () => Map([]))
        localized[entry.key] = entry.value
      }
      None => ()
    }
  }
  { messages, }
}

///|
fn Catalog::lookup(self : Catalog, locale : String, key : String) -> String? {
  match self.messages.get(locale) {
    Some(messages) => messages.get(key)
    None => None
  }
}
