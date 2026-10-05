///|
/// 资源管理器(M0-6a)的渲染冒烟:导入工程后切到「工程」页,真实布局下
/// 模块名/包名/文件名必须可见——左栏装配(标题/搜索框条件/图标栏)任何
/// 一处接错,这里都会以「文本不见」暴露。

///|
/// 与 shell_layout_wbtest 同款:纯转移 + headless 出帧。
fn explorer_apply(model : Model, msg : Msg) -> Model {
  let (next, _) = update_pure(model, msg)
  next
}

///|
fn explorer_draw(
  model : Model,
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (model, @moui.Effect::none()),
    update=(current, msg) => update_pure(current, msg),
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  @runtime.new_program_with_dimensions(program~, width~, height~).draw_commands()
}

///|
/// counter 形工程扫描输入(黑盒测试文件里的同构 fixture 在白盒不可见,自留一份)。
fn explorer_source() -> @project.ProjectSource {
  let mod_text =
    #|name = "examples/counter"
    #|version = "0.1.0"
    #|preferred_target = "native"
  let app_pkg =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
  let entry_pkg =
    #|import {
    #|  "wzzc-dev/moui",
    #|}
  @project.ProjectSource::{
    root: "/root",
    module_manifest: mod_text,
    package_sources: [
      ("app", app_pkg, true, ["moon.pkg", "app.mbt"]),
      ("web_wasm", entry_pkg, false, ["moon.pkg", "main.mbt"]),
      ("macos_skia", entry_pkg, false, ["moon.pkg", "main.mbt"]),
    ],
  }
}

///|
test "explorer 渲染导入工程的模块名/包名/文件名" {
  let services = @services.AppServices::new()
  let imported = update_with_services(
      initial_model(),
      ProjectWalkCompleted(Success(Ok(explorer_source()))),
      services,
    ).0
  let opened = explorer_apply(imported, SetLeftView(LeftProject))
  let texts = shell_texts(explorer_draw(opened, 1280.0, 800.0))
  let mut seen_module = false
  let mut seen_app_pkg = false
  let mut seen_app_file = false
  for run in texts {
    if run.text.contains("examples/counter") {
      seen_module = true
    }
    if run.text == "app" {
      seen_app_pkg = true
    }
    if run.text == "app.mbt" {
      seen_app_file = true
    }
  }
  assert_true(seen_module, msg="模块名应可见")
  assert_true(seen_app_pkg, msg="包名应可见")
  assert_true(seen_app_file, msg="文件名应可见")
}

///|
test "explorer 空态给导入入口" {
  let opened = explorer_apply(initial_model(), SetLeftView(LeftProject))
  let texts = shell_texts(explorer_draw(opened, 1280.0, 800.0))
  let mut seen_import = false
  for run in texts {
    if run.text.contains("导入 MoonBit 工程") {
      seen_import = true
    }
  }
  assert_true(seen_import, msg="空态应有导入入口")
}

///|
/// M1-2 验收核心:重放画布把解析帧里的 DrawText 真画出来——
/// 「counter 导入 → 预览构建 → 画布出帧」的最后一环。
test "预览工作区重放帧:JSON 命令真画到画布上" {
  let services = @services.AppServices::new()
  let imported = update_with_services(
      initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(explorer_source()))),
      services,
    ).0
  let report = @build.BuildReport::{
    kind: BkFramePreview,
    ok: true,
    exit_code: 0,
    output: "__STUDIO_PREVIEW_V1__\n{\"version\":\"1\",\"width\":640.0,\"height\":480.0,\"commands\":[[\"FillRect\",{\"origin\":{\"x\":0,\"y\":0},\"size\":{\"width\":640,\"height\":480}},{\"r\":1,\"g\":1,\"b\":1,\"a\":1}],[\"DrawText\",{\"text\":\"MoUI Counter\",\"frame\":{\"origin\":{\"x\":44,\"y\":10},\"size\":{\"width\":200,\"height\":20}},\"font\":{\"families\":{\"families\":[\"SystemUi\"]},\"size\":13,\"weight\":400,\"style\":\"Normal\",\"variations\":[]},\"color\":{\"r\":0.1,\"g\":0.1,\"b\":0.1,\"a\":1},\"align\":\"TextStart\"}]],\"semantics\":[]}",
    diagnostics: [],
    web_root: "",
    web_index_rel: "",
    artifact_path: "",
  }
  let finished = update_with_services(
      imported,
      ProjectBuildFinished(BkFramePreview, Ok(report)),
      services,
    ).0
  assert_true(finished.preview_frame is Some(_))
  let opened = explorer_apply(finished, SetWorkSpace(WsPreview))
  let commands = explorer_draw(opened, 1280.0, 800.0)
  // 重放画布必须画出帧里的文本(而非 Studio 自己的 chrome 文案):
  // DrawText 的 text 与帧 JSON 逐字一致。
  let mut replayed = false
  for run in shell_texts(commands) {
    if run.text == "MoUI Counter" && run.frame.origin.x == 44.0 {
      replayed = true
    }
  }
  assert_true(replayed, msg="帧里的 DrawText 应被重放到画布(x=44)")
}

///|
/// M1-3:语义投影 + 命中测试(最深匹配)。
test "语义投影与命中:点标题选中,点空白取消" {
  let frame = match parse_preview_frame(preview_payload()) {
    Ok(frame) => frame
    Err(msg) => fail("载荷应可解析:\{msg}")
  }
  let nodes = semantic_hit_nodes(frame)
  // fixture 语义:标题节点(MoUI Studio)+ 无 label 的容器节点
  assert_true(nodes.length() >= 2)
  // 命中标题(x=100,y=15 在 frame {44,10,96,20} 内)
  let mut title_index = -1
  let mut i = 0
  for node in nodes {
    if node.label == "MoUI Studio" {
      title_index = i
    }
    i = i + 1
  }
  assert_true(title_index >= 0, msg="fixture 应含标题节点")
  assert_eq(semantic_hit_index(nodes, 100.0, 15.0), title_index)
  // 画布坐标系之外的点未命中(容器节点覆盖整个 640×480)
  assert_eq(semantic_hit_index(nodes, 700.0, 500.0), -1)
}
