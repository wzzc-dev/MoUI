///|
test "detects product logic patterns in entrypoints" {
  let entry : Entrypoint = {
    example: "demo",
    path: "examples/demo/macos_skia",
    mobile: false,
  }
  let files = ["examples/demo/macos_skia/main.mbt"]
  let texts : Map[String, String] = {
    "examples/demo/macos_skia/main.mbt": "pub fn update(model : Model, msg : Msg) -> Model { model }\n",
  }
  let findings = check_p1_entry_texts(entry, true, false, files, texts)
  debug_inspect(findings.any(item => !item.ok), content="true")
  debug_inspect(
    findings.any(item => item.hint.contains("fn update")),
    content="true",
  )
}

///|
test "accepts thin entrypoint with app package" {
  let entry : Entrypoint = {
    example: "demo",
    path: "examples/demo/web_wasm",
    mobile: false,
  }
  let files = ["examples/demo/web_wasm/main.mbt"]
  let texts : Map[String, String] = {
    "examples/demo/web_wasm/main.mbt": "fn main {\n  @app.run()\n}\n",
  }
  let findings = check_p1_entry_texts(entry, true, false, files, texts)
  debug_inspect(findings.length(), content="1")
  debug_inspect(findings[0].ok, content="true")
}

///|
test "P2 rejects core control constructors and public View enum" {
  let mbti =
    #|pub enum View {
    #|  Node
    #|}
    #|pub fn button() -> View
    #|
  let findings = check_p2_texts("moui/core/pkg.generated.mbti", Some(mbti), [])
  debug_inspect(
    findings.any(item => item.hint.contains("enum View")),
    content="true",
  )
  debug_inspect(
    findings.any(item => item.hint.contains("pub fn button")),
    content="true",
  )
}

///|
test "R3 requires env-driven renderer selection" {
  let bad = check_r3_provider_text("provider.mbt", Some("fn select() {}"))
  debug_inspect(bad.ok, content="false")
  let good = check_r3_provider_text(
    "provider.mbt",
    Some(
      "let mode = NativeRendererMode::parse(@env.get(\"MOUI_SKIA_RENDERER\"))",
    ),
  )
  debug_inspect(good.ok, content="true")
}

///|
test "R3 keeps mobile ABI ownership in the framework and root shims mechanical" {
  let missing_install = check_r3_mobile_main(
    "main.mbt",
    Some(
      "@host.shell_renderer_selection\npub fn moui_embedding_attach_surface() {}",
    ),
  )
  debug_inspect(missing_install.ok, content="false")
  let thin = check_r3_mobile_main(
    "main.mbt",
    Some(
      "@platform_host.install_embedding\n@host.shell_renderer_selection\n@host.shell_renderer_configure",
    ),
  )
  debug_inspect(thin.ok, content="true")
  let expected = ["moui_embedding_attach_surface"]
  let executable_pkg_text =
    #|import { "wzzc-dev/moui_shell/embedding" @shell_embedding }
    #|options(link: { "native": { "exports": [ "moui_embedding_attach_surface" ] } })
    #|
  let executable_pkg = check_r3_mobile_pkg(
    "moon.pkg",
    Some(executable_pkg_text),
    expected,
  )
  debug_inspect(executable_pkg.ok, content="true")
  let missing_root_exports = check_r3_mobile_pkg(
    "moon.pkg",
    Some("import { \"wzzc-dev/moui_shell/embedding\" @shell_embedding }"),
    expected,
  )
  debug_inspect(missing_root_exports.ok, content="false")
  let shim_text =
    #|///|
    #|pub fn moui_embedding_attach_surface() -> Bool {
    #|  @shell_embedding.moui_embedding_attach_surface()
    #|}
    #|
  let shim = check_r3_mobile_export_shim(
    "embedding_exports.mbt",
    Some(shim_text),
    expected,
  )
  debug_inspect(shim.ok, content="true")
  let shim_with_logic_text =
    #|pub fn moui_embedding_attach_surface() -> Bool {
    #|  if true { @shell_embedding.moui_embedding_attach_surface() } else { false }
    #|}
    #|
  let shim_with_logic = check_r3_mobile_export_shim(
    "embedding_exports.mbt",
    Some(shim_with_logic_text),
    expected,
  )
  debug_inspect(shim_with_logic.ok, content="false")
  let wrong_forward_text =
    #|pub fn moui_embedding_attach_surface() -> Bool {
    #|  @shell_embedding.moui_embedding_render_frame()
    #|}
    #|
  let wrong_forward = check_r3_mobile_export_shim(
    "embedding_exports.mbt",
    Some(wrong_forward_text),
    expected,
  )
  debug_inspect(wrong_forward.ok, content="false")
  let owner_pkg_text =
    #|options(link: { "native": { "exports": [ "moui_embedding_attach_surface" ] } })
    #|
  let owner_pkg = check_r3_shell_embedding_pkg(
    "moui_shell/embedding/moon.pkg",
    Some(owner_pkg_text),
    expected,
  )
  debug_inspect(owner_pkg.ok, content="true")
  let owner_impl_text =
    #|let installed_embedding_runtime = Ref(None)
    #|pub fn moui_embedding_attach_surface() -> Bool { false }
    #|
  let owner_impl = check_r3_shell_embedding_impl(
    "moui_shell/embedding/runtime_callbacks.mbt",
    Some(owner_impl_text),
    expected,
  )
  debug_inspect(owner_impl.ok, content="true")
  let owner_without_state = check_r3_shell_embedding_impl(
    "moui_shell/embedding/runtime_callbacks.mbt",
    Some("pub fn moui_embedding_attach_surface() -> Bool { false }"),
    expected,
  )
  debug_inspect(owner_without_state.ok, content="false")
}

///|
test "G1 rejects skill tables that re-list P-rows" {
  let text =
    #|| P1 | thin entry |
    #|| P2 | no controls in core |
    #|| P3 | something |
    #|
  match check_g1_skill_text("skills/x/SKILL.md", text) {
    Some(finding) => debug_inspect(finding.ok, content="false")
    None => fail("expected G1 finding")
  }
  debug_inspect(count_p_rows(text), content="3")
}

///|
test "P2 does not treat View* enums as View enum" {
  debug_inspect(
    is_view_enum_decl("pub(all) enum ViewDirtyHint {"),
    content="false",
  )
  debug_inspect(is_view_enum_decl("pub enum View {"), content="true")
  debug_inspect(is_view_enum_decl("enum View["), content="true")
}
