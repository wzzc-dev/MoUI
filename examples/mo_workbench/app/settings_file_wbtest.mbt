///|
fn inspect_active_provider_id(
  actual : String?,
  expected : String,
) -> Unit raise {
  guard actual is Some(provider_id) else {
    fail("expected active provider id " + expected)
  }
  inspect(provider_id, content=expected)
}

///|
test "default settings file matches template defaults" {
  let file = mo_workbench_default_settings_file()
  inspect(file.providers.length(), content="2")
  inspect(file.providers[0].base_url, content="https://api.deepseek.com/v1")
  inspect(file.providers[0].models.length(), content="2")
  inspect(file.providers[1].id, content="openai")
  inspect(file.providers[1].base_url, content="https://api.openai.com/v1")
  inspect_active_provider_id(file.active_provider_id, "deepseek")
  inspect(file.font_size, content="14")
  inspect(file.appearance, content="system")
}

///|
test "decode modern multi-provider settings json" {
  let text =
    #|{
    #|  "providers": [
    #|    {
    #|      "id": "deepseek",
    #|      "name": "DeepSeek",
    #|      "base_url": "https://api.deepseek.com/v1",
    #|      "api_key": "sk-test",
    #|      "models": ["deepseek-v4-flash", "deepseek-v4-pro"]
    #|    }
    #|  ],
    #|  "active_provider_id": "deepseek",
    #|  "current_model": "deepseek-v4-flash",
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
  inspect(file.providers[0].api_key, content="sk-test")
  inspect(file.providers[0].base_url, content="https://api.deepseek.com/v1")
  inspect(file.appearance, content="dark")
  inspect(file.font_size, content="16")
}

///|
test "decode legacy single-provider settings json migrates" {
  let text =
    #|{
    #|  "openai_api_key": "sk-legacy",
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
  inspect(file.providers.length(), content="1")
  inspect(file.providers[0].id, content="deepseek")
  inspect(file.providers[0].api_key, content="sk-legacy")
  inspect(file.providers[0].base_url, content="https://token.sensenova.cn/v1")
  inspect_active_provider_id(file.active_provider_id, "deepseek")
}

///|
test "merge settings file into workspace" {
  let base = SettingsWorkspace::new()
  let file = {
    providers: [
      {
        id: "deepseek",
        name: "DeepSeek",
        base_url: "https://api.example.com/v1",
        api_key: "sk-abc",
        models: ["deepseek-v4-flash"],
      },
    ],
    active_provider_id: Some("deepseek"),
    current_model: "deepseek-v4-flash",
    mo_workbench_workspace: "/tmp/ws",
    mo_workbench_session_root: "/tmp/sessions",
    approval_policy: "never",
    sandbox_mode: "read-only",
    font_size: 12,
    appearance: "light",
  }
  let merged = SettingsWorkspace::merge_settings_file(base, file)
  inspect(merged.find_provider("deepseek").unwrap().api_key, content="sk-abc")
  inspect(
    merged.find_provider("deepseek").unwrap().base_url,
    content="https://api.example.com/v1",
  )
  inspect_active_provider_id(merged.active_provider_id, "deepseek")
  inspect(merged.working_dir, content="/tmp/ws")
  inspect(merged.session_root, content="/tmp/sessions")
  inspect(merged.font_size, content="12")
  inspect(merged.approval_policy == ApprovalPolicy::NeverAsk, content="true")
}
