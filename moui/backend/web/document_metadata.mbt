///|
pub(all) struct WebDocumentMetadata {
  title : String
  description : String
  canonical : String
  image : String
  locale : String
  direction : String
} derive(Eq, Debug, ToJson)

///|
pub fn WebDocumentMetadata::new(
  title~ : String,
  description? : String = "",
  canonical? : String = "",
  image? : String = "",
  locale? : String = "",
  direction? : String = "",
) -> WebDocumentMetadata {
  { title, description, canonical, image, locale, direction }
}

///|
pub fn web_update_document_metadata(metadata : WebDocumentMetadata) -> Unit {
  let json = (ToJson::to_json(metadata) : Json).stringify()
  web_update_document_metadata_host(web_host_string(json))
}

///|
fn web_update_document_metadata_host(json : WebHostString) -> Unit = "window_web" "update_document_metadata"
