# Plan: MoUI Studio 工程工作台——moon.work 工作区导入 + 规模治理 + 工程记录持久化

- **Status**: active（W1–W3 已落地；studio 全套 4836/4836 绿；真机导入走查待人工复核）
- **Goal**: 让 Studio 能把 `moon.work` 多模块工作区（如本仓库根，54 成员）整体导入；
  单模块导入在仓库级规模下不再失控；导入的工程记录跨重启保留。
- **Non-goals**: 多根工作区的「运行时添加/移除成员」UI（RemoveProject 已可会话内移除）；
  `.code-workspace` 式布局文件；工程内文件级 CRUD（独立计划：工作区手感）；
  workspace 成员的预览 harness 自动生成（成员按单模块重新导入即得）。

## 已核实事实（2026-10-07 探索，实施直接采信）

| 事实 | 锚点 |
|---|---|
| 导入要求根目录有 `moon.mod`，否则「不是 MoonBit 模块工程?」 | `services/project/walk.mbt:160` |
| 目录上限 `WALK_MAX_DIRS=2000`，逐包逐 .mbt 深读找 `pub fn program` | `walk.mbt:32`、`walk.mbt:281` |
| MoUI 仓库根是 moon.work 工作区：无 moon.mod、4744 目录 / 650 包 / 3986 .mbt | `moon.work`、find 统计（2026-10-07） |
| 持久化先例（同款照抄）：`sessions_store_path` + EventBus 脏事件 + boot 读 + 写盘回执 | `app/app.mbt:1271-1382`、`update_ai.mbt:235` |
| 工程记录 = `{root, module_name, scanned}` 会话内存，重启即丢 | `app/project_workbench.mbt:11` |
| `upsert_project` 原位替换 + 新工程置 active | `app/project_workbench.mbt:54` |
| ServiceTask 无进度通道；compile 走 `on_progress` 回调 + Msg | `app/app.mbt:160` |
| i18n 键源在 `app/i18n/{en,zh-Hans}.json`，经 `scripts/generate-i18n-catalogs.mjs` 再生成 | scripts 目录 |
| 工作台计划（M0 导入/资源管理器/BuildService）已全部达成，本计划是其工作区延伸 | `docs/plans/active/moui-studio-workbench.md` |

## 设计决策

1. **扫描输出统一为 `ProjectScanOutput`**：`Single(ProjectSource)`（现行为）
   | `Workspace(WorkspaceScan)`（`root` + `loaded : Array[ProjectSource]` +
   `failed : Array[(成员路径, 原因)]`）。旧的
   `walk_project_task → Result[ProjectSource, String]` 收敛为唯一入口
   `walk_root_task`，两个调用点（导入、删除后重扫）全部迁移，不留双轨。
2. **moon.work 解析容忍规则**（同 mod_format 纪律）：`members = [ ... ]` 块内
   取双引号字符串，`#`/`//` 行注释跳过；members 缺失或块未闭合 = 结构化报错；
   成员路径归一（剥 `./`）。成员目录不存在或缺 `moon.mod` → 进 `failed`，不炸整单。
3. **规模治理（workspace 模式）**：
   - 入口判定**只按目录名约定**（`web_wasm`/`macos_skia`/`native_app`），不深读
     `.mbt`——54 成员 × 全量深读是当前失控的主因；`program_packages` 在
     workspace 模式为空（预览 harness 本来就跳过 workspace 成员）。
   - 上限：每成员沿用 `WALK_MAX_DIRS=2000`；workspace 级新增 `SCAN_MAX_MEMBERS=200`
     与 `SCAN_MAX_TOTAL_DIRS=20000`；超限报「哪个成员/哪一级」。
   - 跳过目录清单不变；进度回调每 64 目录节流一次。
4. **进度通道**：`walk_root_task` 增可选 `on_progress : (WalkProgress) -> Unit`
   （`scanned_dirs` + `current`），app 侧经 `Effect::dispatch(emit => …)` 同款
   线程纪律发 `ProjectScanProgress` Msg；资源管理器头部显示「已扫描 N 目录」。
5. **持久化 = 记录列表存 `{root, module_name}`，启动重扫**：不落整棵树
   （4744 目录 JSON 数 MB 且立刻陈旧）；`.studio/projects.json`
   （`moui.studio.projects v1`，未知版本拒绝不迁移，与 ai-sessions 同纪律）。
   启动加载 → 逐 root 后台重扫（有进度）；成员重扫失败 → 该记录静默降级为
   「仅名字」还是丢弃？**丢弃 + 汇总 notice**（工程在盘上，重新导入即可）。
   web 入口不传路径 = 显式关闭（同 ai-sessions）。
6. **单模块导入行为不变**（含深读与预览 harness）——G2 验收里 examples/momark
   不回退即指此。

## Milestones

### W1 moon.work 解析 + walk 收敛（纯层，先测后接）——完成（2026-10-07）

- [x] `services/project/work_format.mbt`：`parse_moon_work` + 成员归一 + 容忍规则
- [x] `walk.mbt`：`WalkProgress` / `ProjectScanOutput` / `walk_root_task`
      （probe 根目录 → Single 或 Workspace 分相）；workspace 成员复用同一
      BFS 状态机（成员队列）；上限三件套
- [x] `project_wbtest`：moon.work 解析（含注释/坏块）、workspace 聚合
      （成员失败不炸单）、上限触发、Single 路径回归
- 验收：纯层测试绿；`moon info` 面变化 review

### W2 app 接线：导入链 + 进度 + i18n——完成（2026-10-07）

- [x] Msg：`ProjectScanCompleted(ServiceTaskResult[Result[ProjectScanOutput,String]])`
      替换 `ProjectWalkCompleted`；`ProjectScanProgress(WalkProgress)`
- [x] Model：`scan_progress : String?`（资源管理器头部一行）
- [x] Workspace 臂：逐 loaded 建 record + upsert（active = 最后一个）；failed
      汇总 notice（`app.project.imported_n` / `app.project.import_skipped`）
- [x] 删除后重扫迁移到 `walk_root_task`
- [x] i18n 双 JSON + `generate-i18n-catalogs.mjs` 再生成
- 验收：app 测试绿；导入 MoUI 仓库根出 54 成员（failed 0）

### W3 工程记录持久化——完成（2026-10-07）

- [x] `project_workbench.mbt`：`encode_project_records` / `decode_project_records`
      （v1；未知版本结构化拒）
- [x] 程序参数 `projects_store_path?`；boot 读 → `ProjectsStoreLoaded` →
      逐 root 重扫（走 W2 链）；upsert/remove/删除 → 脏事件
      `EvProjectsDirty` → `ProjectsStoreWriteRequested` → 写盘回执
- [x] `macos_skia/main.mbt` 传 `.studio/projects.json`；web 不传
- [x] 通知/文案 + i18n
- 验收：导入 → 退出 → 重启，工程列表与 active 恢复；删文件后重扫仍持久

## 总验收

- MoUI 仓库根导入成功：资源管理器可见成员模块，进度可见，failed 汇总说话。
- examples/momark 单模块导入不回退（含预览 harness）。
- 重启后工程列表恢复（native）；web 行为不变。
- 受影响包 `moon test` 绿 + 静态五件套绿。

## 风险

| 风险 | 缓解 |
|---|---|
| 串行 BFS 4744 目录仍慢 | list_directory-only（无文件深读）+ 进度反馈；慢而可见优于无声失控 |
| .studio/projects.json 与重扫竞态（启动即导入） | 重扫走与手动导入同一链；upsert 原位替换幂等 |
| 成员名重复（同名模块路径） | upsert 按 root 键；module_name 仅展示 |
