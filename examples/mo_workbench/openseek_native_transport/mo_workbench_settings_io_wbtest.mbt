///|
test "ensure settings creates default json when missing" {
  let path = ".mo_workbench/settings.json"
  let existed = @fs.path_exists(path)
  mo_workbench_ensure_settings_file()
  assert_true(@fs.path_exists(path))
  if !existed {
    let _ = @fs.remove_file(path) catch { _ => () }
  }
}

///|
test "settings json roundtrip through public decode" {
  let json_text =
    #|{"openai_api_key":"k","openai_base_url":"https://x/v1","deepseek_api_key":"","mo_workbench_workspace":".","mo_workbench_session_root":"./.openseek","approval_policy":"write","sandbox_mode":"workspace","font_size":14,"appearance":"system"}
  guard @app.mo_workbench_decode_settings_file(json_text) is Some(file) else {
    fail("decode failed")
  }
  inspect(file.openai_api_key, content="k")
}