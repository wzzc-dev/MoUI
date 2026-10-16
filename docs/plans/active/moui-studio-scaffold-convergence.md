# Plan: MoUI Studio 新建项目脚手架收敛

- **Status**: active
- **ADR**: [0037](../../decisions/0037-studio-code-as-source-of-truth.md),
  [0038](../../decisions/0038-studio-plugin-kernel.md)
- **Goal**: 让「Studio 新建项目」与 `moui new` 共用同一个声明式文件计划生成器，
  新建即可在 Studio 之外编译运行；依赖版本一处事实；落盘事务化；
  磁盘真源与 ADR 0037 对齐；内核由 vendoring 转为发布依赖。
- **Non-goals**: Web 端新建/导出（无文件系统，保持显式降级）、
  完整磁盘→IR 反解析产品化、模板系统 DSL 化或模板分仓。

## 问题

`moui_studio/app/new_project.mbt` 是仓库里的**第二套项目脚手架**，且比已有的那套弱：

| 维度 | `moui_cli`（已有正确实现） | Studio 新建项目（旧状态） |
|---|---|---|
| 计划构造 | `generator.mbt` `build_project_file_plan()`：类型化入参 + 占位符模板 + 平台轴 | 手拼 23 个文件 |
| 落盘 | `project_validation.mbt`：stage 临时目录 → 真跑 `moon update/check/build` → 清产物 → commit，失败回滚 | 无校验、无回滚 |
| 可运行性 | 带平台入口包 | 无入口包，离开 Studio 跑不起来 |
| 工程身份 | `moui.project.json` | 靠嗅探 `runner.mbt` 判断 |
| 版本事实 | — | Studio `moon.mod` 0.2.3 / 生成工程 pin 0.2.0 / `moui_cli` 0.2.2，测试断言硬编码字面量 |
| 模块名 | `naming.mbt` 归一 | CJK 退化成 `"-"`，且被测试钉死 |
| 磁盘真源 | — | 不写 `form.mbt`（违 ADR 0037），恢复只靠 `.studio/program.json` |
| 内核 | — | 14 文件逐字节拷进用户工程（`kernel_*.mbt` 1 万余行常量 + `tools/sync_kernel` 漂移门 + 行数豁免） |

## 目标架构

1. **生成器 = 一处纯数据**。`moui_cli/scaffold_plan` 纯包
   （`supported_targets = "native+wasm-gc"`，零 fs/env/FFI）持有 `ProjectOptions`、
   `PlannedFile`、`build_project_file_plan()`、命名归一与全部模板。CLI 与 Studio
   都是它的薄适配器。
2. **产物形状由 capability 决定**，不由调用方决定：`profile: ide-skeleton |
   export-app` 共用同一 plan，入口包、`.gitignore`、`README.md`、`moon.work`、
   `moui.project.json` 都进骨架。
3. **工程身份可读**：`moui.project.json`（`schemaVersion/id/title/module/mouiVersion/platforms`）
   取代 `runner.mbt` 嗅探。
4. **落盘 = 事务**：stage(temp) → validate（native 真跑 `moon check`）→ commit + 回滚；
   Web 端保持 `export_available=false` 显式降级。

## Delivery sequence

| 阶段 | 内容 | 验证门 | 回滚 |
|---|---|---|---|
| P1 | 版本一处事实：`moon_mod()` / `deps_txt()` 从 Studio `moon.mod` 派生；`tools/sync_versions` 生成依赖表；断言改判派生值 | `moon test moui_studio/services/export --target native` + pr | 纯常量表，revert 即回 |
| P2 | 命名归一：CJK / 数字开头不再退化 | `moon test moui_studio/app --target native` + pr | revert |
| P3 | 骨架变可跑：补入口包 + 去下标耦合 | pr + platform + `scripts/studio-export-smoke.sh` | revert |
| P4 | 生成器收敛：`moui_cli/scaffold_plan` 纯包 + Studio 依赖它 + 事务化写盘 + `moui.project.json` | pr + `validate-api-surface.mjs` + `validate-release-module-closures.mjs` + daily | 包级搬迁，整阶段 revert |
| P5 | `form.mbt` 真源落地（骨架采用 form_designer 布局） | pr + theme | 前置阻塞：先补 `stage`/`place` helper 契约；失败退回「ADR 0037 显式记偏差」 |
| P6 | 内核发布化：`wzzc-dev/moui_studio_kernel`，删 `kernel_*.mbt` 与 `tools/sync_kernel` | daily + platform + release-closure | `kernel_sources()` 置空可逐字节回退；需新 ADR 取代 0038 |

## Acceptance

- [x] P1：导出 bundle 的 `moon.mod` / `deps.txt` 版本由 `moui_studio/moon.mod` 派生，
  漂移时 `moon run moui_studio/tools/sync_versions --target native -- --check` 报 DRIFT，
  且该检查已注册进 `checks/profiles.json` 的 pr profile。
- [x] P2：中文工程名生成合法模块名（不再出现 `"-"`），旧断言随之更新——
  纯非 ASCII 给 `moui-app` 兜底，数字开头加 `app-` 前缀。
- [x] P3：骨架补上 `native_app/` 与 `web_wasm/` 入口包，在 Studio 之外
  `moon update && moon check && moon build --target native`（以及 `--target wasm-gc`）
  通过；工程身份改为按**落盘路径**从文件计划合成（`services/project/plan_source.mbt`），
  不再按队列下标反推。真开窗口属手工验收。
- [x] P4a（CLI 侧，已落）：`moui new` 的生成面从根包抽出为纯包
  `moui_cli/scaffold_plan`——`project_id_from_path`/`product_name` 等命名口径、
  平台轴、`ProjectOptions`/`PlannedFile`/`ProjectManifest` 类型面、`moui.project.json`
  读写、全部 `*_text()` 模板与 `build_project_file_plan()` 都在包内；根包只留
  「计划 → stage → validate → commit/回滚」的事务与 fs。`scaffold_plan` 已在
  native 与 wasm-gc 双目标通过测试，证明零 fs/env/FFI。
- [x] P4b-1（Studio 侧，已落）：`moui_cli@0.2.4` 上注册表后，Studio 的
  `services/export` 依赖 `wzzc-dev/moui_cli/scaffold_plan`——web 入口包清单
  （`web_pkg`）与宿主 ABI 垫片（`abi_mbt`）改为调用同一份 `@plan` 生成器，
  两条生成链（`moui new` 骨架 / Studio 导出 bundle）只剩「组合根别名」这一处
  差别。新建工程写盘加**删除相**：中断（失败或取消）把队列截成已写前缀逐项
  `delete_file`，游标由 `NewProjectQueueResult` 统一推进，不再留「半套骨架」。
- [ ] P4b-2（未完成，需决策）：以 `moui.project.json` 作 Studio 工程身份、
  写盘走 stage/validate/commit。**两条阻塞都不是 IO**：
  ① `@plan.parse_project_manifest` 要求 `module` 为 `owner/name` 形，而 Studio
  骨架/导出的 `moon.mod` 用裸名（`name = "my-app"`），CLI 侧 `moui new` 默认
  `local/<id>`——要么两边统一成 `local/` 前缀（改 moon.mod 名与全部包导入路径），
  要么放宽读回校验；二者都需维护者定调，不在本次改动内。
  ② 清单里的 `platforms` 要诚实：CLI 的桌面入口目录是 `<platform>_skia/`，
  Studio 骨架写的是 `native_app/`，声明 `["web","macos"]` 会让 `moui run`
  找不到入口——先收敛入口目录约定，再写清单。
- [ ] P5：骨架写出 `form.mbt` 且满足 `parse ∘ render == id`。
- [ ] P6：生成工程不再内联内核源码；`checks/release-modules.json` 有 kernel 模块条目。

## 实现记录

- **P4-1 骨架生成面出壳**（已落）：新建 `moui_studio/services/scaffold`
  （`skeleton.mbt` 落盘计划 + `dirs.mbt` 目录守卫/mkdir + `templates.mbt` 模板下标），
  布局探测 `is_studio_app_bundle` 迁 `plugins/project/code_project.mbt`，
  壳侧 `app/new_project.mbt` 只留草稿状态机与逐文件写盘 Effect；
  生成面测试随代码迁 `services/scaffold/skeleton_wbtest.mbt`，并在 pr profile
  注册 `studio scaffold tests`。壳行数 27,000 → 26,819（棘轮同批收紧）。
- **P4-2 生成器出壳（CLI 侧）**（已落）：`generator.mbt`/`naming.mbt`/
  `mobile_entrypoint_generator.mbt` 迁入 `moui_cli/scaffold_plan/`
  （`plan.mbt`/`naming.mbt`/`entrypoints.mbt`），类型面与依赖版本常量落
  `model.mbt`，`moui.project.json` 读写落 `manifest.mbt`，纯路径文本助手落
  `paths.mbt`（根包 `path_fs.mbt` 的 `normalized_path`/`base_name` 改为委托，
  避免两份归一规则）。生成器不再自查版本：`build_project_file_plan(options, cli_version)`
  由调用方传入，`moui_cli/generate.mbt` 用 `cli_version()`。落盘事务留在根包
  （`generate.mbt` + `project_validation.mbt` + `path_fs.mbt`），fs 侧测试随
  `generate_wbtest.mbt` 回到根包，plan 侧 golden 留 `scaffold_plan/plan_wbtest.mbt`。
  包外只暴露消费方真正需要的面（`project_mutate.mbt` 逐平台补文件要的
  `web_*`/`desktop_*`/`mobile_*` 模板 + 身份清单读写）；`app_text`/`moon_mod_text`/
  `dev_runner_text`/`gitignore_text`/`manifest_json`/`valid_*` 等回落到包内私有。
- **P4b-1 生成器出壳（Studio 侧）**（已落）：`wzzc-dev/moui_cli@0.2.4` 发布
  带上 `scaffold_plan` 包后（`0.2.3` 曾从中间态树发布、缺 ABI 契约，
  2026-10-16 重发布修正），`moui_studio/moon.mod` pin 它、
  `services/export/moon.pkg` 引 `@plan`，`web_pkg(name)` 改为
  `@plan.web_pkg_text(name, app_alias="exported_app")`、`abi_mbt()` 改为
  `@plan.web_abi_shim_mbt()`——宿主入口名单与转发从此一份事实（`moui new` 的
  `web_wasm/main.mbt` 也插同一段，只差组合根别名）。`scripts/studio-export-smoke.sh`
  在 workspace 外真编 native + wasm-gc 双端通过，证明垫片字节没漂。
  新建工程写盘加**删除相**：`NewProjectDraft` 的队列在失败/取消时截成已写前缀、
  逐项 `delete_file`，游标推进由 `NewProjectFileWritten` 改名后的
  `NewProjectQueueResult` 统一承担；相位与收尾由
  `app/new_project_wbtest.mbt` 白盒钉住。壳行数 26,819 → 26,807
  （写盘事务 +30，同批清掉 5 个零调用者遗留包装 −42，`source-file-policy`
  的 `update_shell.mbt` 棘轮同批收紧）。
- **生成器补 CI 门（新发现缺口）**：`checks/profiles.json` 里 `moui_cli` 一条
  都没有——CLI 的测试此前只靠手动 `moon test moui_cli`。Studio 现在跨模块
  消费 `@plan`，生成器坏了没人拦。补两条 pr 门：`cli scaffold generator tests`
  (`moon test moui_cli --target native`，根包 `+native`) 与
  `cli scaffold generator purity`(`moon test moui_cli/scaffold_plan --target wasm-gc`，
  把「零 fs/env/FFI」的双目标边界钉成门禁而不只是注释)。
- **默认依赖版本跟进**（已落）：`scaffold_plan/model.mbt` 的
  `default_moui_dependency_version` 由 0.2.2 提到 0.2.3——mooncakes 索引里
  `wzzc-dev/moui` 最新即 0.2.3、22 个 examples 全部 pin 0.2.3，生成工程不该再
  默认落后一版。`moui_web_renderer`(0.2.2) 与 `moui_skia_renderer`(0.2.1) 就是
  各自索引里的最新版，不动。帮助文本与 `moui.project.json` golden 同批改。
- **附带修复**：`pub fn program` 程序包探测由子串匹配收紧为
  `pub fn program(`，否则内核快照里的 `program_signature` 之类名字会把非组合根
  包误判成程序包（`services/project/walk.mbt`、`app/direct_scan.mbt`、
  `services/project/plan_source.mbt` 三处同口径）。这条同时修掉了预览 harness
  绑错包与提案采纳后内嵌 IR 不刷新的隐患。

## Decision log

| Date | Decision |
|---|---|
| 2026-10-14 | 内核 vendoring → 发布独立 kernel 模块（P6，需新 ADR 取代 0038 的相关结论） |
| 2026-10-14 | 共享生成器落点 → `moui_cli` 内新建纯包 `scaffold_plan`（避开「新增顶层包 = RFC-always」；Studio→moui_cli 的依赖边按维护者决定**不另立 ADR**，改由发布顺序与 `mooncakes-release-playbook.md` 约束） |
| 2026-10-14 | 本轮范围 → 做到 P4；P1–P3 属「修正确性」，P4 为结构收敛 |
| 2026-10-14 | ADR 0037 的 `form.mbt` 缺口 → 现在就修，骨架采用 form_designer 布局（P5） |

## 迁移（已存在的 folder projects）

一次性非破坏迁移器，口径仿 `moui_studio/plugins/project/code_project.mbt`
`migrate_studio_source`：打开时若无 `moui.project.json` 则从 `moon.mod` + 扫描结果
合成并写入，补投入口包文件（逐路径冲突表，存在即跳过并通知），
`.studio/program.json` 降级为带签名校验的缓存。**不做**永久双写、**不加**兼容 shim。

## 风险

1. P1 把生成 pin 抬到 Studio 当前版本可能暴露 bundle 构建失败（历史病例：旧线
   `moui@0.1.12` 在新工具链下类型检查失败 → 整个 native GUI 编不出）。必须先跑
   platform profile + `scripts/studio-export-smoke.sh`。
2. P4 让 Studio 与 `moui_cli` 发布节奏耦合；用 `scripts/window-dev-mode.sh`
   式本地成员开关缓解。
3. P5 触及运行/预览/主题三条线，且 `on_click` 从函数名改 Msg 值会破
   `parse_form` 的规范子集与 span 回写。
4. P6 的包路径改动机械但巨大，需单独 PR。
5. `moui_cli/scaffold_plan/plan_wbtest.mbt` 是逐字节 golden（默认排序的 macOS
   文件清单 + `moui.project.json` 原文），任何 plan 变更必须同阶段更新。

## 验证

```sh
moon test moui_studio/app moui_studio/services/export moui_studio/services/project --target native
moon test moui_cli --target native
moon check moui_studio --target wasm-gc
sh scripts/check.sh --profile pr
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile daily
node scripts/validate-api-surface.mjs
node scripts/validate-release-module-closures.mjs
scripts/studio-export-smoke.sh
node scripts/validate-guidance-consistency.mjs
```
