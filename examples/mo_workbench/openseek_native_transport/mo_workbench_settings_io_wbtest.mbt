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
    #|{"providers":[{"id":"deepseek","name":"DeepSeek","base_url":"https://api.deepseek.com/v1","api_key":"k","models":["deepseek-v4-flash","deepseek-v4-pro"]}],"active_provider_id":"deepseek","current_model":"deepseek-v4-flash","mo_workbench_workspace":".","mo_workbench_session_root":"./.openseek","approval_policy":"write","sandbox_mode":"workspace","font_size":14,"appearance":"system"}
  guard @app.mo_workbench_decode_settings_file(json_text) is Some(file) else {
    fail("decode failed")
  }
  inspect(file.providers[0].api_key, content="k")
}
