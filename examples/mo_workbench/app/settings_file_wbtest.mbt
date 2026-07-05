///|
test "default settings file matches template defaults" {
  let file = mo_workbench_default_settings_file()
  inspect(file.openai_base_url, content="https://api.deepseek.com/v1")
  inspect(file.font_size, content="14")
  inspect(file.appearance, content="system")
}

///|
test "decode settings json example shape" {
  let text =
    #|{
    #|  "openai_api_key": "sk-test",
    #|  "openai_base_url": "https://token.sensenova.cn/v1",
    #|  "deepseek_api_key": "",
    #|  "mo_workbench_workspace": ".",
    #|  "mo_workbench_session_root": "./.openseek",
    #|  "approval_policy": "write",
    #|  "sandbox_mode": "workspace",
    #|  "font_size": 16,
    #|  "appearance": "dark"
    #|}
  guard mo_workbench_decode_settings_file(text) is Some(file) else {
    fail("expected settings file")
  }
  inspect(file.openai_api_key, content="sk-test")
  inspect(file.openai_base_url, content="https://token.sensenova.cn/v1")
  inspect(file.font_size, content="16")
}

///|
test "merge settings file into workspace" {
  let base = SettingsWorkspace::new()
  let file = {
    openai_api_key: "sk-abc",
    openai_base_url: "https://api.example.com/v1",
    deepseek_api_key: "",
    mo_workbench_workspace: "/tmp/ws",
    mo_workbench_session_root: "/tmp/sessions",
    approval_policy: "never",
    sandbox_mode: "read-only",
    font_size: 12,
    appearance: "light",
  }
  let merged = SettingsWorkspace::merge_settings_file(base, file)
  inspect(merged.api_key, content="sk-abc")
  inspect(merged.base_url, content="https://api.example.com/v1")
  inspect(merged.working_dir, content="/tmp/ws")
  inspect(merged.session_root, content="/tmp/sessions")
  inspect(merged.font_size, content="12")
  inspect(merged.approval_policy == ApprovalPolicy::NeverAsk, content="true")
}
