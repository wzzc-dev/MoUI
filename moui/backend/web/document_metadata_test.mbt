///|
test "web document metadata retains existing constructor calls" {
  let metadata = WebDocumentMetadata::new(
    title="MoUI Docs",
    description="MoonBit GUI documentation",
    canonical="https://example.test/docs",
    image="https://example.test/og.webp",
  )
  inspect(metadata.locale, content="")
  inspect(metadata.direction, content="")
}

///|
test "web document metadata serializes locale and direction" {
  let metadata = WebDocumentMetadata::new(
    title="MoUI 文档",
    locale="zh-Hans",
    direction="ltr",
  )
  let json = (metadata.to_json() : Json).stringify()
  assert_true(json.contains("\"locale\":\"zh-Hans\""))
  assert_true(json.contains("\"direction\":\"ltr\""))
}
