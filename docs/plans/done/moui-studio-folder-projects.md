# moui-studio-folder-projects：示例项目落盘本地文件夹 + 移除离线模型

状态：done（2026-10-11 归档） · 起止 2026-10-10 → 2026-10-11 · 来源会话：用户直接需求

## 目标

1. **新建示例项目 = 选本地文件夹落盘工程**：模板/新建入口从「只换内存 IR」升级为
   「选文件夹 → 写入工程骨架（moon.mod + 程序包代码真源 + IR 快照）→ 注册并激活工程」。
2. **AI 修改项目接通**：新建工程成为活动工程后，提案采纳沿既有
   `EvCodeProjectWrite` 通道把 form.mbt/handlers.mbt 写进所选文件夹，并同步 IR 快照。
   提案 schema（`controls.update` + `props.font_size` 等）不动。
3. **移除离线假模型**：删 `ProviderMode::Fake` 全链路（假补全/假流式/假讲解/关键词
   路由），AI 恒走真实 OpenAI 兼容 provider；无 key 时结构化引导到设置。
   Web 端显式降级（AI 入口提示需要 native 版），不出假按钮。

## 决策记录

| # | 决策 | 理由 |
|---|---|---|
| D1 | 新建工程落盘骨架 = moon.mod（name=文件夹名、pin 当前版本、preferred_target=native）+ `<pkg>/moon.pkg` + `<pkg>/skeleton.mbt`（Msg + stage/place + `pub fn program()`）+ `<pkg>/form.mbt/handlers.mbt`（`code_project_files` 派生）+ `<root>/.studio/program.json`（IR 快照） | direct_scan 验收只认 moon.mod + moon.pkg；program_packages 需 `pub fn program`；EvCodeProjectWrite 落点 = 首个 program 包；handlers.mbt 的 `@compiled_runtime` 依赖 `wzzc-dev/moui_studio/services/compiled_runtime` |
| D2 | IR 快照存 `<root>/.studio/program.json`（`.studio/` 被扫描跳过），激活工程时存在且解码成功即恢复 IR | 磁盘→IR 回读（M6）未建；快照让「关掉重开继续 AI 编辑」成立；`.studio/` 已是预览 harness 惯例目录 |
| D3 | Web 端 `ai_available=false`（program 新可选参数），UI 隐藏 composer + 引导文案 | 浏览器无现成 HTTP 通道；仓库纪律「显式降级，不出现假按钮」；vendored fetch FFI 受 CORS 限制不引入 |
| D4 | 模板（samples.mbt）保留，与假模型解耦 | 模板是教学内容（教案引用），非假模型专属；初始程序仍取 `sample_hello()` |
| D5 | `.studio.json` 单文件保存/打开入口保持不变 | 本期只改「新建项目」流；单文件草稿流另有价值 |
| D6 | 假模型决策反转落档：`docs/plans/active/moui-studio.md` 曾定「假模型为默认模式」，本期移除并在此记录 | 治理要求决策变更可追溯 |

## 非目标

- form.mbt/handlers.mbt 反解析回 IR（workbench 计划 M6 范围）。
- Web 端浏览器 fetch provider。
- 工程骨架的 web_wasm/macos_skia 入口包（预览走 `.studio/preview` harness；构建入口后续按需）。

## 里程碑（全部完成，2026-10-11 核对）

- [x] M1 domain 清理：删 `domain/proposals/fake_model.mbt`（`proposal_system_prompt` 迁至
  samples.mbt）；删 `plugins/ai::fake_stream_chunks`、`services/model_provider::deterministic_completion`；
  相关测试改造。`samples.mbt` 与 `all_samples()` 保留。
- [x] M2 ProviderMode 移除：app 全部 Fake 分支合并为真实路径（无 key →
  `app.ai.key_needed` 引导）；模型 chip 恒显 provider_model（无 key「未连接」）；
  设置面板去 Fake/Real 切换；i18n 增删 + 生成器重跑。
- [x] M3 新建项目流：`new_project_skeleton_files()` 纯函数生成器 + wbtest；
  `NewProjectRequested(template)` → pick_directory → 写骨架 → direct_scan 注册/激活
  → 模板 IR 进 model.program → EvCodeProjectWrite + 快照写入；空舞台按钮、
  `studio.template.*`、`studio.file.new` 全部走新流。
- [x] M4 IR 快照恢复：SetActiveProject 异步读 `<root>/.studio/program.json` →
  decode → 确认门（当前程序非空且不同）→ 载入；提案采纳同步快照。
- [x] M5 Web 降级：`ai_available` 注入 + UI 降级 + web_wasm 入口传 false。
- [x] M6 文档与验证：README（子仓库）、memories、决策反转记录；逐包 moon test
  （native+wasm-gc）、新建工程 `moon build` 冒烟、静态五件套、i18n `--check`、
  source-file-policy。

## 进度日志

- 2026-10-10：计划建立；探索结论——示例模板硬编码于 `domain/proposals/samples.mbt`，
  工程导入不回读 IR，`ProviderMode::Fake` 默认且 Web 入口 noop provider。
- 2026-10-11：归档核对——M1–M6 全部落地：`domain/proposals/fake_model.mbt` 已删除
  （`proposals/` 仅剩 samples/validation）；`fake_stream_chunks`/`deterministic_completion`
  全仓零残留；`app/new_project.mbt` 骨架生成器 + `NewProjectRequested` 落盘链 +
  `PROGRAM_SNAPSHOT_REL` 快照恢复（`emit_program_snapshot`、`SetActiveProject` 回读）在位；
  `web_wasm/main.mbt` 传 `ai_available=false`。本计划归档。
