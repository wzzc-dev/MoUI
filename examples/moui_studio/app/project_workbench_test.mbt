///|
/// 工程工作台(M0)测试:导入消息链 + 工程记录。
/// 服务流测试的驱动方式与 notice_entry_test 同款——手动派发「effect 完成
/// 时会来的那条消息」,不真正执行 ServiceTask(walk 任务的遍历逻辑已由
/// services/project 的 wbtest 用假 FileServices 全链覆盖)。

///|
/// counter 形工程的扫描输入(与 services/project wbtest 的 fixture 同构):
/// 根清单 + 三个包,app 包带 `pub fn program`。
fn counter_source() -> @project.ProjectSource {
  let mod_text =
    #|name = "examples/counter"
    #|
    #|version = "0.1.0"
    #|
    #|preferred_target = "native"
    #|
    #|import {
    #|  "wzzc-dev/moui@0.2.0",
    #|}
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
test "导入完成:工程入库、成为当前选中、toast 报名" {
  let services = @services.AppServices::new()
  let (next, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectWalkCompleted(Success(Ok(counter_source()))),
    services,
  )
  assert_eq(next.projects.length(), 1)
  assert_eq(next.active_project, 0)
  assert_eq(next.projects[0].root, "/root")
  assert_eq(next.projects[0].module_name, "examples/counter")
  // 入口判定随记录带入(预览三模式 M1-M3 直接吃)
  assert_eq(next.projects[0].scanned.web_entry, "web_wasm")
  assert_eq(next.projects[0].scanned.native_entry, "macos_skia")
  assert_eq(next.projects[0].scanned.program_packages, ["app"])
  assert_eq(next.toasts.length(), 1)
  assert_true(next.notice.contains("examples/counter"))
}

///|
test "重复导入同根工程:原位替换不新增" {
  let services = @services.AppServices::new()
  let first = @app.update_with_services(
      @app.initial_model(),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  let second = @app.update_with_services(
    first,
    ProjectWalkCompleted(Success(Ok(counter_source()))),
    services,
  )
  assert_eq(second.0.projects.length(), 1)
  assert_eq(second.0.active_project, 0)
}

///|
test "域级失败(目录不是 MoonBit 模块):toast 说明、不进列表" {
  let services = @services.AppServices::new()
  let (next, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectWalkCompleted(Success(Err("/root:目录里没有 moon.mod"))),
    services,
  )
  assert_eq(next.projects.length(), 0)
  assert_eq(next.active_project, -1)
  assert_eq(next.toasts.length(), 1)
  assert_true(next.notice.contains("moon.mod"))
}

///|
test "基础设施失败(扫描坏了):toast 报服务错误" {
  let services = @services.AppServices::new()
  let (next, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectWalkCompleted(
      Failure(@services.ServiceError::new(code="fs", message="磁盘不可读")),
    ),
    services,
  )
  assert_eq(next.projects.length(), 0)
  assert_eq(next.toasts.length(), 1)
  assert_true(next.notice.contains("磁盘不可读"))
}

///|
test "选目录取消:一切不变" {
  let services = @services.AppServices::new()
  let next = @app.update_with_services(
      @app.initial_model(),
      ProjectRootPicked(Cancelled),
      services,
    ).0
  assert_eq(next.projects.length(), 0)
  assert_eq(next.toasts.length(), 0)
}

///|
test "upsert_project:新工程插表头,同根原位替换" {
  let record_a = match @app.project_record_from_source(counter_source()) {
    Ok(record) => record
    Err(msg) => fail("fixture 应可解析:\{msg}")
  }
  let (one, index_one) = @app.upsert_project([], record_a)
  assert_eq(index_one, 0)
  assert_eq(one.length(), 1)
  let (two, index_two) = @app.upsert_project(one, record_a)
  assert_eq(index_two, 0)
  assert_eq(two.length(), 1)
}

///|
test "explorer 纯导航:选中工程/折叠包/选中文件(再点取消)" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  // 折叠/展开翻转
  let folded = @app.update_pure(imported, ToggleProjectPackage("app")).0
  assert_true(folded.project_tree_collapsed.contains("app"))
  let unfolded = @app.update_pure(folded, ToggleProjectPackage("app")).0
  assert_false(unfolded.project_tree_collapsed.contains("app"))
  // 文件选中 + 再点取消
  let picked = @app.update_pure(imported, SelectProjectFile("app/app.mbt")).0
  assert_eq(picked.selected_project_file, Some("app/app.mbt"))
  let unpicked = @app.update_pure(picked, SelectProjectFile("app/app.mbt")).0
  assert_eq(unpicked.selected_project_file, None)
  // 选中工程重置文件选中
  let switched = @app.update_pure(picked, SetActiveProject(0)).0
  assert_eq(switched.selected_project_file, None)
}

///|
test "explorer 移除工程:会话级,active 下标随位次修正" {
  let services = @services.AppServices::new()
  let source_a = counter_source()
  let source_b = match
    @project.parse_module_manifest("name = \"b/mod\"\nversion = \"0.1.0\"") {
    Ok(manifest) =>
      match @project.scan_module(manifest, []) {
        Ok(scanned) =>
          @project.ProjectSource::{
            root: "/b",
            module_manifest: "name = \"b/mod\"\nversion = \"0.1.0\"",
            package_sources: [],
          }
        Err(msg) => fail("scan 应成功:\{msg}")
      }
    Err(msg) => fail("manifest 应可解析:\{msg}")
  }
  let _ = source_a
  let with_a = @app.update_with_services(
      @app.initial_model(),
      ProjectWalkCompleted(Success(Ok(source_a))),
      services,
    ).0
  let with_b = @app.update_with_services(
      with_a,
      ProjectWalkCompleted(Success(Ok(source_b))),
      services,
    ).0
  // b 在表头且是当前选中(0);移除 0 → a 回到选中位 0
  assert_eq(with_b.projects[0].root, "/b")
  assert_eq(with_b.active_project, 0)
  let removed = @app.update_pure(with_b, RemoveProject(0)).0
  assert_eq(removed.projects.length(), 1)
  assert_eq(removed.projects[0].root, "/root")
  assert_eq(removed.active_project, 0)
  // 再移除唯一的工程 → 无选中
  let emptied = @app.update_pure(removed, RemoveProject(0)).0
  assert_eq(emptied.projects.length(), 0)
  assert_eq(emptied.active_project, -1)
}

///|
test "文件删除确认流:置卡→确认清卡→服务执行→回执通知" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  // 1) 请求确认:置确认卡
  let asked = @app.update_pure(
      imported,
      RequestConfirm(CkDeleteProjectFile("app/app.mbt")),
    ).0
  assert_true(asked.pending_confirm is Some(_))
  // 2) 确认:清卡 + 派发续行消息(effect)
  let (accepted, _) = @app.update_pure(asked, ConfirmAccepted)
  assert_true(accepted.pending_confirm is None)
  // 3) 服务层执行删除:模型不动,删除任务在 effect 里
  let (run, _) = @app.update_with_services(
    accepted,
    ProjectFileDeleteRun("app/app.mbt"),
    services,
  )
  assert_eq(run.projects.length(), 1)
  // 4) 回执成功:通知 + 重扫 effect(资源管理器文件树随之刷新)。
  // toast 是就地追加的共享数组,断言用**相对基线**(导入时已有一条)。
  let baseline = run.toasts.length()
  let (done, _) = @app.update_with_services(
    run,
    ProjectFileDeleted("app/app.mbt", Success(())),
    services,
  )
  assert_eq(done.toasts.length(), baseline + 1)
  assert_true(done.notice.contains("app/app.mbt"))
  // 5) 回执失败:警告 toast,工程原样
  let (failed, _) = @app.update_with_services(
    run,
    ProjectFileDeleted(
      "app/app.mbt",
      Failure(@services.ServiceError::new(code="fs", message="只读")),
    ),
    services,
  )
  assert_eq(failed.toasts.length(), baseline + 2)
  assert_eq(failed.projects.length(), 1)
}

///|
test "文件删除:无选中工程时续行为无操作" {
  let services = @services.AppServices::new()
  let (next, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectFileDeleteRun("app/app.mbt"),
    services,
  )
  assert_eq(next.projects.length(), 0)
  assert_eq(next.toasts.length(), 0)
}

///|
test "构建门:web 不可用 / 无工程 / 缺入口各自显式说话" {
  let services = @services.AppServices::new()
  // web:编译轨不可用 → 同一口径显式声明
  let web = @app.update_with_services(
      @app.initial_model(),
      ProjectBuildRun(BkWebPreview),
      services,
    ).0
  assert_true(web.notice.contains("编译轨"), msg=web.notice)
  // native:无工程
  let no_project = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectBuildRun(BkWebPreview),
      services,
    ).0
  assert_true(no_project.notice.contains("导入"))
  // native:有工程但对应入口缺失(web-only 工程跑 native 构建)→ 缺入口提示
  let app_pkg =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
  let entry_pkg =
    #|import {
    #|  "wzzc-dev/moui",
    #|}
  let web_only_source = @project.ProjectSource::{
    root: "/webonly",
    module_manifest: counter_source().module_manifest,
    package_sources: [
      ("app", app_pkg, true, ["moon.pkg", "app.mbt"]),
      ("web_wasm", entry_pkg, false, ["moon.pkg", "main.mbt"]),
    ],
  }
  let with_project = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(web_only_source))),
      services,
    ).0
  assert_eq(with_project.projects[0].scanned.native_entry, "")
  let no_entry = @app.update_with_services(
      with_project,
      ProjectBuildRun(BkRunNative),
      services,
    ).0
  assert_true(no_entry.notice.contains("入口"), msg=no_entry.notice)
  assert_false(no_entry.build_busy)
}

///|
test "构建运行:busy 置位 + 待执行请求按 kind 装配" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  let (running, _) = @app.update_with_services(
    imported,
    ProjectBuildRun(BkWebPreview),
    services,
  )
  assert_true(running.build_busy)
  let request = match running.pending_build {
    Some(request) => request
    None => fail("应有待执行构建请求")
  }
  assert_eq(request.kind, BkWebPreview)
  assert_eq(request.root, "/root")
  assert_eq(request.entry_rel, "web_wasm")
}

///|
test "构建回执:报告落 last_build,busy 复位,诊断汇进 Problems" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  // 基线在**任何后续变更之前**取死(共享数组的引用语义)
  let toast_baseline = imported.toasts.length()
  let running = @app.update_with_services(
      imported,
      ProjectBuildRun(BkWebPreview),
      services,
    ).0
  let report = @build.BuildReport::{
    kind: BkWebPreview,
    ok: false,
    exit_code: 1,
    output: "moon: error",
    diagnostics: [
      @export.CompileDiagnostic::{
        severity: "error",
        code: "4014",
        file: "/root/app/app.mbt",
        line: 5,
        column: 3,
        text: "类型不匹配",
      },
    ],
    web_root: "/root",
    web_index_rel: "web_wasm/index.html",
    artifact_path: "",
  }
  let finished = @app.update_with_services(
      running,
      ProjectBuildFinished(BkWebPreview, Ok(report)),
      services,
    ).0
  assert_false(finished.build_busy)
  assert_true(finished.last_build is Some(_))
  // toasts 是**共享可变数组**(结构体 spread 只拷引用):断言必须用
  // 变更前取死的 Int 基线,行内再取 length() 会读到累计后的值
  assert_eq(finished.toasts.length(), toast_baseline + 1)
  // 合流:构建诊断以问题行出现(file 定位 → 跳资源管理器)
  let rows = @app.problem_rows(finished, @app.translator(finished))
  let mut found = false
  for row in rows {
    if row.file == "/root/app/app.mbt" && row.line == 5 {
      found = true
    }
  }
  assert_true(found, msg="构建诊断应汇进问题表")
  // 点击跳转:切到工程页并选中文件
  let jumped = @app.update_pure(
      finished,
      GotoProblem("build:/root/app/app.mbt", 5),
    ).0
  assert_true(jumped.left_view is LeftProject)
  assert_eq(jumped.selected_project_file, Some("/root/app/app.mbt"))
}

///|
test "预览落盘:导入成功即建队列,回执推进,写完就绪" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  // 导入成功:落盘队列建立(moon.pkg + main.mbt 两个文件)
  let state = match imported.preview_write {
    Some(state) => state
    None => fail("导入成功应有预览落盘队列")
  }
  assert_eq(state.files.length(), 2)
  let (path0, content0) = state.files[0]
  assert_true(path0.contains(".studio/preview/moon.pkg"), msg=path0)
  assert_true(content0.contains("@user_app"), msg=content0)
  // 第一次回执:游标推进到 main.mbt
  let (after_first, _) = @app.update_with_services(
    imported,
    PreviewFileWritten(Success(())),
    services,
  )
  let advanced = match after_first.preview_write {
    Some(state) => state
    None => fail("还有一个文件未写")
  }
  assert_eq(advanced.done, 1)
  let (path1, content1) = advanced.files[1]
  assert_true(path1.contains(".studio/preview/main.mbt"), msg=path1)
  assert_true(content1.contains("draw_commands()"), msg=content1)
  // 第二次回执:写完 → 清队列 + 就绪通知(toast 基线取死为 Int)
  let baseline = after_first.toasts.length()
  let done = @app.update_with_services(
      after_first,
      PreviewFileWritten(Success(())),
      services,
    ).0
  assert_true(done.preview_write is None)
  assert_eq(done.toasts.length(), baseline + 1)
  assert_true(done.notice.contains("预览已就绪"), msg=done.notice)
}

///|
test "预览落盘失败:显式声明并放弃" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  let (failed, _) = @app.update_with_services(
    imported,
    PreviewFileWritten(
      Failure(@services.ServiceError::new(code="fs", message="磁盘只读")),
    ),
    services,
  )
  assert_true(failed.preview_write is None)
  assert_true(failed.notice.contains("磁盘只读"), msg=failed.notice)
}

///|
test "FramePreview 入口 = 生成的 harness 包路径" {
  let record = match @app.project_record_from_source(counter_source()) {
    Ok(record) => record
    Err(msg) => fail("fixture 应可解析:\{msg}")
  }
  assert_eq(@app.build_entry_rel(BkFramePreview, record), ".studio/preview")
  assert_eq(@app.build_entry_rel(BkWebPreview, record), "web_wasm")
  assert_eq(@app.build_entry_rel(BkRunNative, record), "macos_skia")
}

///|
test "FramePreview 回执:解析哨兵协议 → 帧入库" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  let report = @build.BuildReport::{
    kind: BkFramePreview,
    ok: true,
    exit_code: 0,
    output: "__STUDIO_PREVIEW_V1__\n{\"version\":\"1\",\"width\":640.0,\"height\":480.0,\"commands\":[[\"FillRect\",{\"origin\":{\"x\":0,\"y\":0},\"size\":{\"width\":10,\"height\":10}}, {\"r\":1,\"g\":1,\"b\":1,\"a\":1}]],\"semantics\":[]}",
    diagnostics: [],
    web_root: "",
    web_index_rel: "",
    artifact_path: "",
  }
  let finished = @app.update_with_services(
      imported,
      ProjectBuildFinished(BkFramePreview, Ok(report)),
      services,
    ).0
  assert_false(finished.build_busy)
  match finished.preview_frame {
    Some(frame) => {
      assert_eq(frame.version, 1)
      assert_eq(frame.commands.length(), 1)
    }
    None => fail("FramePreview 回执应解析出帧")
  }
}

///|
test "FramePreview 回执:解析失败显式报错,不落帧" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectWalkCompleted(Success(Ok(counter_source()))),
      services,
    ).0
  let report = @build.BuildReport::{
    kind: BkFramePreview,
    ok: true,
    exit_code: 0,
    output: "no sentinel here",
    diagnostics: [],
    web_root: "",
    web_index_rel: "",
    artifact_path: "",
  }
  let finished = @app.update_with_services(
      imported,
      ProjectBuildFinished(BkFramePreview, Ok(report)),
      services,
    ).0
  assert_true(finished.preview_frame is None)
  assert_true(finished.notice.contains("哨兵"), msg=finished.notice)
}

///|
/// M1-3:字面量定位(引号感知 + 精确匹配)+ 补丁任务(fake FS 全链)。
test "字面量 span 定位与补丁任务" {
  let source = "fn view(_) { text(\"MoUI Counter\", x=1) }"
  assert_true(@app.find_literal_span(source, "MoUI Counter") is Some(_))
  assert_true(@app.find_literal_span(source, "Other") is None)
  // 假 FS:读源文件 → 定位 → 转义回写
  let texts : Map[String, String] = Map([])
  texts["/root/app/app.mbt"] = source
  let files = @services.FileServices::new(
    read_text=path => {
      match texts.get(path) {
        Some(text) =>
          @services.ServiceTask::succeed(key="fake:read", value=text)
        None =>
          @services.ServiceTask::fail(
            key="fake:read",
            error=@services.ServiceError::new(code="fake:no-file", message=path),
          )
      }
    },
    write_text=(path, text) => {
      texts[path] = text
      @services.ServiceTask::succeed(key="fake:write", value=())
    },
  )
  let request = @app.SemanticPatchRequest::{
    paths: ["/root/app/app.mbt"],
    label: "MoUI Counter",
    new_text: "我的计数器",
  }
  let outcome : Ref[@services.ServiceTaskResult[Result[String, String]]?] = Ref(
    None,
  )
  let _ = @app.semantic_label_patch_task(files, request).start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Ok(path))) => {
      assert_eq(path, "/root/app/app.mbt")
      match texts.get("/root/app/app.mbt") {
        Some(patched) => {
          assert_true(patched.contains("我的计数器"), msg=patched)
          assert_false(patched.contains("MoUI Counter"), msg=patched)
        }
        None => fail("文件应仍在假 FS 里")
      }
    }
    Some(Success(Err(msg))) => fail("补丁应成功:\{msg}")
    Some(Failure(error)) => fail("不应走基础设施失败:\{error.message}")
    Some(Cancelled) => fail("不应被取消")
    None => fail("任务未完成")
  }
}
