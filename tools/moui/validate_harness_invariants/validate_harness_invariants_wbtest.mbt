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
test "R3 requires window-hosted mobile mains" {
  let bad_main = check_r3_mobile_main(
    "main.mbt",
    Some("@platform_host.start()\n"),
  )
  debug_inspect(bad_main.ok, content="false")
  let good = check_r3_mobile_main(
    "main.mbt",
    Some(
      "let app = @android_host.AndroidWindowHostedApp::new(...)\nlet event_loop = @window_android.EventLoop::new()\nevent_loop.run_app(app)\n",
    ),
  )
  debug_inspect(good.ok, content="true")
  let good_pkg = check_r3_mobile_pkg(
    "moon.pkg",
    Some("import { \"wzzc-dev/window/android\" @window_android }"),
  )
  debug_inspect(good_pkg.ok, content="true")
  let bad_pkg = check_r3_mobile_pkg(
    "moon.pkg",
    Some("import { \"wzzc-dev/moui/backend/android\" @android_host }"),
  )
  debug_inspect(bad_pkg.ok, content="false")
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

///|
test "R3 mobile build pipeline accepts a split package implementation" {
  let finding = check_r3_mobile_build_pipeline(
    "moui_cli mobile build pipeline",
    [Some("parse --renderer with auto"), Some("select skia-gpu or skia-raster")],
  )
  assert_true(finding.ok)
}

///|
test "R3 mobile build pipeline rejects missing source or renderer modes" {
  let missing = check_r3_mobile_build_pipeline("pipeline", [
    Some("--renderer auto"),
    None,
  ])
  assert_false(missing.ok)
  let incomplete = check_r3_mobile_build_pipeline("pipeline", [
    Some("--renderer auto skia-raster"),
  ])
  assert_false(incomplete.ok)
}
