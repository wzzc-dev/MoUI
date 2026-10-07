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
    ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  let second = @app.update_with_services(
    first,
    ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
    ProjectScanCompleted(Success(Err("/root:目录里没有 moon.mod"))),
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
    ProjectScanCompleted(
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
        Ok(_scanned) =>
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
      ProjectScanCompleted(Success(Ok(Single(source_a)))),
      services,
    ).0
  let with_b = @app.update_with_services(
      with_a,
      ProjectScanCompleted(Success(Ok(Single(source_b)))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(web_only_source)))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  let (running, _) = @app.update_with_services(
    imported,
    ProjectBuildRun(BkWebPreview),
    services,
  )
  assert_true(running.build_busy)
  // 事件驱动(M1):过门即发 EvBuildSubmit,派发给注入的 submit 由组合根
  // 监听器承担(回执仍是 ProjectBuildFinished)
  match running.outbox {
    // import 步已入队 EvProjectsDirty(真实程序每趟排空),这里只断言尾部事件
    [.., EvBuildSubmit(kind, root, entry_rel)] => {
      assert_eq(kind, BkWebPreview)
      assert_eq(root, "/root")
      assert_eq(entry_rel, "web_wasm")
    }
    _ => fail("应发出构建提交事件")
  }
}

///|
test "构建回执:报告落 last_build,busy 复位,诊断汇进 Problems" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
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

///|
/// G2 W3:工程记录存储编码往返(root/module_name 摘要 + active_root)。
test "工程记录存储编码往返" {
  let services = @services.AppServices::new()
  let (imported, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectScanCompleted(Success(Ok(Single(counter_source())))),
    services,
  )
  let (with_second, _) = @app.update_with_services(
    imported,
    ProjectScanCompleted(
      Success(Ok(Single({ ..counter_source(), root: "/root_b", }))),
    ),
    services,
  )
  let encoded = @app.encode_project_store(with_second)
  match @app.decode_project_store(encoded) {
    Ok((active_root, records)) => {
      assert_eq(active_root, "/root_b")
      assert_eq(records.length(), 2)
      // upsert 头插:后导入的在前
      assert_eq(records[0], ("/root_b", "examples/counter"))
    }
    Err(msg) => fail("编码产物应可解码:\{msg}")
  }
}

///|
test "工程记录存储拒绝坏 JSON 与未知版本" {
  match @app.decode_project_store("not json") {
    Ok(_) => fail("坏 JSON 应报错")
    Err(msg) => assert_true(msg.contains("JSON"), msg~)
  }
  match
    @app.decode_project_store(
      (
        #|{"format":"moui.studio.projects","version":99,"projects":[]}
      ),
    ) {
    Ok(_) => fail("未知版本应拒绝")
    Err(msg) => assert_true(msg.contains("未知版本"), msg~)
  }
}

///|
/// G2 W3:boot 恢复链——Loaded 起静默重扫,回执逐个静默合并(无通知),
/// pending 归零时按 active_root 落位选中。
test "boot 恢复:静默重扫合并并落位 active" {
  let services = @services.AppServices::new()
  let payload =
    #|{"format":"moui.studio.projects","version":1,"active_root":"/root_b",
    #|  "projects":[{"root":"/root_a","module_name":"a"},{"root":"/root_b","module_name":"b"}]}
  let (loaded, _) = @app.update_with_services(
    @app.initial_model(),
    ProjectsStoreLoaded(Success(payload)),
    services,
  )
  assert_eq(loaded.projects_restore_pending, 2)
  assert_eq(loaded.restore_active_root, "/root_b")
  let (restored_a, _) = @app.update_with_services(
    loaded,
    ProjectRestoreScanCompleted(
      Success(Ok(Single({ ..counter_source(), root: "/root_a", }))),
    ),
    services,
  )
  assert_eq(restored_a.projects_restore_pending, 1)
  assert_eq(restored_a.projects.length(), 1)
  // 恢复期间不弹通知(静默合并)
  assert_eq(restored_a.notice, "")
  let (restored_b, _) = @app.update_with_services(
    restored_a,
    ProjectRestoreScanCompleted(
      Success(Ok(Single({ ..counter_source(), root: "/root_b", }))),
    ),
    services,
  )
  assert_eq(restored_b.projects_restore_pending, 0)
  assert_eq(restored_b.projects.length(), 2)
  assert_eq(restored_b.restore_active_root, "")
  // active 落位在 /root_b 的记录上
  match @app.active_project_of(restored_b) {
    Some(project) => assert_eq(project.root, "/root_b")
    None => fail("恢复后应有选中工程")
  }
}

///|
/// G2 W2:工作区导入——逐成员入库,失败成员汇总进通知,进度读数清空。
test "工作区导入:多成员入库 + 失败汇总" {
  let services = @services.AppServices::new()
  let good_a = { ..counter_source(), root: "/root_a", }
  let good_b = { ..counter_source(), root: "/root_b", }
  let scan : @project.WorkspaceScan = {
    root: "/workspace",
    loaded: [good_a, good_b],
    failed: [("/bad", "目录里没有 moon.mod")],
  }
  let (next, _) = @app.update_with_services(
    {
      ..@app.initial_model(),
      scan_progress: Some("已扫描 100 个目录 · x"),
    },
    ProjectScanCompleted(Success(Ok(Workspace(scan)))),
    services,
  )
  assert_eq(next.projects.length(), 2)
  assert_eq(next.scan_progress, None)
  // 汇总通知要提到 1 个跳过
  assert_true(next.notice.contains("1"), msg=next.notice)
}

///|
/// G4 多标签:两文件并行打开互不串台;脏 tab 关闭走确认流,确认后续行关闭。
test "多标签:并行打开 + 切换 + 脏关闭确认" {
  let services = @services.AppServices::new()
  let selected = @app.update_with_services(
      @app.initial_model(),
      SelectProjectFile("a.md"),
      services,
    ).0
  let loaded_a = @app.update_with_services(
      selected,
      ProjectFileLoaded("a.md", Success("# A")),
      services,
    ).0
  let selected_b = @app.update_with_services(
      loaded_a,
      SelectProjectFile("b.mbt"),
      services,
    ).0
  let loaded_b = @app.update_with_services(
      selected_b,
      ProjectFileLoaded("b.mbt", Success("fn main {}")),
      services,
    ).0
  assert_eq(loaded_b.open_project_files.length(), 2)
  assert_eq(loaded_b.open_file_index, 1)
  // 切回 a:active tab 正确,光标随 tab(初始 0)
  let switched = @app.update_with_services(loaded_b, SelectFileTab(0), services).0
  match @app.active_project_file(switched) {
    Some(open) => {
      assert_eq(open.rel, "a.md")
      assert_eq(open.caret, 0)
    }
    None => fail("切换后应有 active tab")
  }
  // 编辑 a → 脏;关闭命中确认流(tab 未关)
  let edited = @app.update_with_services(
      switched,
      EditProjectFile("# A2"),
      services,
    ).0
  let guarded = @app.update_with_services(edited, CloseFileTab(0), services).0
  assert_true(
    guarded.pending_confirm is Some(CkCloseFileTab(0)),
    msg="脏 tab 关闭应进确认",
  )
  assert_eq(guarded.open_project_files.length(), 2)
  // 确认 → 续行关闭
  let accepted = @app.update_with_services(guarded, ConfirmAccepted, services).0
  assert_eq(accepted.open_project_files.length(), 1)
  match @app.active_project_file(accepted) {
    Some(open) => assert_eq(open.rel, "b.mbt")
    None => fail("关闭后应停在剩余 tab")
  }
}

///|
/// G4 CRUD:新建文件链——commit 校验重名拒绝;成功回执开空 tab 并关输入态。
test "文件 CRUD:新建拒绝重名,成功开 tab" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  // 重名拒绝(树里已有 app/app.mbt)
  let dup = @app.update_with_services(
      { ..imported, file_create_open: true, file_name_draft: "app/app.mbt", },
      FileCreateCommit,
      services,
    ).0
  assert_true(dup.notice.contains("已存在"), msg=dup.notice)
  assert_eq(dup.open_project_files.length(), 0)
  // 合法新建:回执后开空 tab、输入态关闭
  let created = @app.update_with_services(
      { ..imported, file_create_open: true, file_name_draft: "app/notes.md", },
      ProjectFileCreated("app/notes.md", Success(())),
      services,
    ).0
  assert_eq(created.open_project_files.length(), 1)
  assert_eq(created.open_file_index, 0)
  assert_false(created.file_create_open)
  match @app.active_project_file(created) {
    Some(open) => {
      assert_eq(open.rel, "app/notes.md")
      assert_eq(open.draft, "")
    }
    None => fail("新建后应打开空 tab")
  }
}

///|
/// G4 CRUD:改名三步链——回执逐段驱动,tab 的 rel 同步替换、内容保留。
test "文件 CRUD:改名链走完 tab rel 替换" {
  let services = @services.AppServices::new()
  let open_tab = {
    ..@app.initial_model(),
    open_project_files: [
      OpenProjectFile::{
        rel: "app/old.md",
        saved_content: "# 旧",
        draft: "# 旧草稿",
        caret: 3,
        selection: None,
      },
    ],
    open_file_index: 0,
    file_rename_open: Some("app/old.md"),
    file_name_draft: "app/new.md",
  }
  // read 回执 → 写;写回执 → 删;删回执 → rel 替换 + 输入态关闭
  let read_ok = @app.update_with_services(
      open_tab,
      ProjectRenameRead("app/old.md", "app/new.md", Success("# 旧")),
      services,
    ).0
  let written = @app.update_with_services(
      read_ok,
      ProjectRenameWritten("app/old.md", "app/new.md", Success(())),
      services,
    ).0
  let deleted = @app.update_with_services(
      written,
      ProjectRenameDeleted("app/old.md", "app/new.md", Success(())),
      services,
    ).0
  assert_eq(deleted.open_project_files.length(), 1)
  match @app.active_project_file(deleted) {
    Some(open) => {
      assert_eq(open.rel, "app/new.md")
      // 草稿与光标原样保留
      assert_eq(open.draft, "# 旧草稿")
      assert_eq(open.caret, 3)
    }
    None => fail("改名后 tab 应保留")
  }
  assert_false(deleted.file_rename_open is Some(_))
}

///|
/// G4 F4:保存 .mbt 自动起 web 构建（诊断汇 Problems）;.md 保存不触发。
test "保存后自动构建:mbt 触发,md 不触发" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  let selected = @app.update_with_services(
      imported,
      SelectProjectFile("app/app.mbt"),
      services,
    ).0
  let loaded = @app.update_with_services(
      selected,
      ProjectFileLoaded("app/app.mbt", Success("pub fn program() -> Unit { }")),
      services,
    ).0
  let (saved, _) = @app.update_with_services(
    loaded,
    ProjectFileSaveFinished("app/app.mbt", Success(())),
    services,
  )
  // 事件驱动:过门即发构建事件 + busy 置位
  assert_true(
    saved.outbox is [.., EvBuildSubmit(BkWebPreview, "/root", "web_wasm")],
    msg="保存 .mbt 应发出构建事件",
  )
  assert_true(saved.build_busy)
  // .md 保存:不触发（独立导入基底——outbox 是共享数组,不能复用上面
  // 已被 .mbt 分支推入构建事件的模型）
  let md_base = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  let md_loaded = @app.update_with_services(
      {
        ..md_base,
        open_project_files: [
          OpenProjectFile::{
            rel: "README.md",
            saved_content: "x",
            draft: "x",
            caret: 0,
            selection: None,
          },
        ],
        open_file_index: 0,
      },
      ProjectFileSaveFinished("README.md", Success(())),
      services,
    ).0
  // import 步遗留的 EvProjectsDirty 在 outbox 里（真实程序每趟排空）,
  // 这里只断言没有构建事件
  let mut has_build = false
  for event in md_loaded.outbox {
    match event {
      EvBuildSubmit(_, _, _) => has_build = true
      _ => ()
    }
  }
  assert_false(has_build, msg="保存 .md 不应触发构建")
}

///|
/// G4 F3:全文搜索——服务回执落命中集;命中点击 = 切代码工作区 + 选中并读文件。
test "全文搜索:命中落集,点击跳转" {
  let services = @services.AppServices::new()
  let imported = @app.update_with_services(
      @app.initial_model(),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      services,
    ).0
  let queried = @app.update_with_services(
      { ..imported, bottom_tab: BtSearch, search_query: "program", },
      SearchRun,
      services,
    ).0
  assert_true(queried.search_busy)
  let hits : Array[SearchHit] = [
    SearchHit::{ rel: "app/app.mbt", line: 3, preview: "pub fn program() {", },
  ]
  let finished = @app.update_with_services(
      queried,
      SearchFinished(Success(hits)),
      services,
    ).0
  assert_false(finished.search_busy)
  assert_eq(finished.search_hits.length(), 1)
  // 点击命中:工作区切到代码 + 文件选中(读 effect 由服务层执行)
  let jumped = @app.update_with_services(
      finished,
      SearchHitClicked("app/app.mbt"),
      services,
    ).0
  assert_true(jumped.workspace is WsCode, msg="跳转应切到代码工作区")
  assert_true(jumped.selected_project_file == Some("app/app.mbt"))
}

///|
/// G7.1:启动事件——RunStart 装填后立即执行 OnStart 子程序（零控件
/// 纯逻辑程序）,声明的变量进活动状态。
test "启动事件:OnStart 装填即执行" {
  let services = @services.AppServices::new()
  let program = {
    ..@ir.empty_program(),
    window: { title: "纯逻辑", width: 640, height: 480, timer_interval: 0,
        back_color: "", },
    variables: [{ name: "开机计数", init: "0", }],
    handlers: [
      {
        control_name: "",
        event: @ir.OnStart,
        note_zh: "开机即累加",
        note_en: "increment on start",
        body: [
          @ir.Assign(
            "开机计数",
            @ir.Binary(@ir.Add, @ir.Var("开机计数"), @ir.IntLit(1)),
          ),
        ],
      },
    ],
  }
  let base = {
    ..@app.initial_model(),
    program,
    // 变量初值快照随程序一起替换（start_run 从这里装填活动状态）
    runtime_values: @studio_lang.initial_values(program),
    runtime_texts: @studio_lang.initial_texts(program),
    runtime_rows: @studio_lang.initial_rows(program),
  }
  let started = @app.update_with_services(base, RunStart, services).0
  match started.run {
    None => fail("RunStart 应进入运行态")
    Some(run) =>
      match run.state.vars.get("开机计数") {
        Some(@studio_lang.VInt(1)) => ()
        Some(other) => fail("开机计数应为 1,实得非预期值")
        None => fail("OnStart 应已执行:变量未出现")
      }
  }
}

///|
/// G7.3 插件管理:禁用终端 → 页签归一 + 持久化写入;重新启用恢复。
test "插件管理:禁用终端归一页签并持久化" {
  let services = @services.AppServices::new()
  let base = { ..@app.initial_model(), bottom_tab: BtTerminal, }
  let toggled = @app.update_with_services(
      base,
      TogglePlugin("terminal"),
      services,
    ).0
  // 页签归一:禁用时正停在终端页签 → 回审计页签
  assert_true(toggled.bottom_tab is BtAudit)
  assert_false(@app.plugin_active(toggled, "terminal"))
  // 写盘事件入 outbox（settings 写由组合根监听）
  let re_enabled = @app.update_with_services(
      toggled,
      TogglePlugin("terminal"),
      services,
    ).0
  assert_true(@app.plugin_active(re_enabled, "terminal"))
}
