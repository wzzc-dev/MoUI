///|
/// Does the *export* half actually put portraits in the bundle?
///
/// `bundle_wbtest` proves the codec carries a portrait that is handed to it. The
/// remaining question is whether the files the app sends to the host contain the
/// portrait at all — a world can render faces on screen and still export without
/// them if the commit set omits the asset.

///|
test "the exported payload includes the portrait asset" {
  // Build a world the same way the app does, then ask for the exact file set the
  // export effect passes to the host (`commit_files(model, World)`).
  let png = base64_encode(b"\x89PNG\r\n\x1a\n")
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 立绘\n\n林掌柜.png\n",
    ),
    ("characters/林掌柜.png", png),
  ]
  let (model, _e) = update(
    WorldModel::new(),
    WorldFilesArrived("雨夜酒馆", true, files),
  )
  let payload = commit_files(model, World)
  let paths : Array[String] = []
  for pair in payload {
    paths.push(pair.0)
  }
  // The asset ships as its own file, under the characters/ prefix the loader
  // reads back.
  assert_true(paths.contains("characters/林掌柜.png"))
  // And it is byte-identical, still base64 — the host decodes it on the way out.
  let mut shipped = ""
  for pair in payload {
    if pair.0 == "characters/林掌柜.png" {
      shipped = pair.1
    }
  }
  assert_eq(shipped, png)
  // The world files ride along, so an imported bundle is playable immediately.
  assert_true(paths.contains("world.md"))
  assert_true(paths.contains("characters/林掌柜.md"))
  // Provider config must NOT be in the bundle: it belongs to the library.
  assert_false(paths.any(path => path.contains("config")))
}

///|
test "an exported bundle reproduces the world, portrait and all" {
  // The whole promise of the feature: send the file to a friend, they import it,
  // and the world — faces included — is there.
  let png = base64_encode(b"\x89PNG\r\n\x1a\n")
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 立绘\n\n林掌柜.png\n",
    ),
    ("characters/林掌柜.png", png),
  ]
  let (model, _e) = update(
    WorldModel::new(),
    WorldFilesArrived("雨夜酒馆", true, files),
  )
  let payload = commit_files(model, World)
  // Encode the manifest the way the host does, then decode it as an import.
  let manifest = bundle_encode("雨夜酒馆", payload)
  match bundle_decode(manifest) {
    Some(bundle) =>
      match parse_world_files(world_files_from_paths(bundle.files)) {
        Some(parsed) => {
          let card = parsed.scenario.character("林掌柜").unwrap()
          assert_eq(card.portrait(), "林掌柜.png")
          // The card resolves the asset to a renderable data URI.
          let assets : Array[(String, String)] = []
          for pair in bundle.files {
            if pair.0 == "characters/林掌柜.png" {
              assets.push(("林掌柜.png", pair.1))
            }
          }
          assert_true(
            portrait_uri(card, assets).has_prefix("data:image/png;base64,"),
          )
        }
        None => fail("the imported world must parse")
      }
    None => fail("the manifest must decode")
  }
}
