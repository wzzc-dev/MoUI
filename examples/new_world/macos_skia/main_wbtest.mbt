///|
/// The folder database is only as good as its file names: a world that is
/// written one character off is a world that disappears on the next launch,
/// with no error anywhere. These tests pin the path join and round-trip a
/// world through the real filesystem so that class of bug cannot return.

///|
test "world files are joined inside the world folder" {
  assert_eq(
    world_file_path("library", "雨夜酒馆", "world.md"),
    "library/雨夜酒馆/world.md",
  )
  assert_eq(
    world_file_path("library", "雨夜酒馆", "characters/林掌柜.md"),
    "library/雨夜酒馆/characters/林掌柜.md",
  )
  // The join adds no suffix of its own: a stray brace here is exactly what hid
  // every write from `list_worlds` (`<folder>/world.md`).
  assert_false(
    world_file_path("library", "雨夜酒馆", "world.md").has_suffix("}"),
  )
}

///|
fn file_content(
  entries : Array[(String, String)],
  name : String,
) -> String? {
  for pair in entries {
    if pair.0 == name {
      return Some(pair.1)
    }
  }
  None
}

///|
async test "a written world reads back unchanged" {
  let root = @fs.tmpdir(prefix="new-world-roundtrip-")
  let png : Bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR"
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("world_book.md", "# 世界书\n\n- 酒: 后堂老酒。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    ("characters/林掌柜.png", @app.base64_encode(png)),
  ]
  let ok = write_world_files_to(root, "雨夜酒馆", files)
  assert_true(ok)
  // The probe is the same one `list_worlds` uses; if it misses, the library
  // shows an empty shelf even though the player just played a whole evening.
  let probe = @fs.kind("\{root}/雨夜酒馆/world.md") catch {
    _ => @fs.FileKind::Unknown
  }
  assert_true(probe is @fs.FileKind::Regular)
  let readback = read_folder_files(root, "雨夜酒馆")
  assert_eq(file_content(readback, "world.md"), Some(files[0].1))
  assert_eq(file_content(readback, "world_book.md"), Some(files[1].1))
  assert_eq(
    file_content(readback, "characters/林掌柜.md"),
    Some(files[2].1),
  )
  // The picture goes to disk as bytes and comes back as the same base64.
  assert_eq(
    file_content(readback, "characters/林掌柜.png"),
    Some(files[3].1),
  )
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
}

///|
async test "rewriting a shorter picture truncates the old bytes" {
  let root = @fs.tmpdir(prefix="new-world-truncate-")
  let long : Bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07"
  let short : Bytes = b"\xff\xd8\xff"
  let original : Array[(String, String)] = [
    ("world.md", "# 后巷\n"),
    ("characters/江湖人.png", @app.base64_encode(long)),
  ]
  assert_true(write_world_files_to(root, "后巷", original))
  let shorter : Array[(String, String)] = [
    ("world.md", "# 后巷\n"),
    ("characters/江湖人.png", @app.base64_encode(short)),
  ]
  assert_true(write_world_files_to(root, "后巷", shorter))
  let readback = read_folder_files(root, "后巷")
  assert_eq(
    file_content(readback, "characters/江湖人.png"),
    Some(@app.base64_encode(short)),
  )
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
}
