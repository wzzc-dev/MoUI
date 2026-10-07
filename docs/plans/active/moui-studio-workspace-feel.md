# Plan: MoUI Studio 工作区手感——多标签 / 文件 CRUD / 全文搜索 / live 诊断

- **Status**: active
- **Goal**: 把工程工作台从「单文件查看器」升级到 VS Code 日常手感:
  多文件并行编辑、资源管理器内新建/重命名、全局搜索跳转、保存即诊断。
- **Non-goals**: file watcher（需原生 host 新能力,另行评估）;SCM;LSP 级
  重构/跳转;目录级新建/移动/拖拽（需 FileServices 目录原语,属框架层变更,
  本轮只做文件级——服务原语见下）。

## 已核实事实

| 事实 | 锚点 |
|---|---|
| `open_project_file` 是单槽 `Option`（rel/saved_content/draft） | `app/model.mbt:481,669` |
| 编辑面渲染在 `code_workspace` 的 `Some(open)` 分支,`.md` 已分流插件 | `app/code_view.mbt`（G3） |
| 保存 = `SaveProjectFile` → files().write_text → `ProjectFileSaveFinished` 对齐脏基准 | `app/app.mbt`、`update_shell.mbt` |
| FileServices 面:list_directory/read_text/write_text/delete_file/pick_directory——**无 create/rename/move** | `moui/services/files.mbt` |
| 组合出文件级原语:新建 = write_text;重命名 = read+write+delete(失败即中止);目录原语缺位 = 结构化降级 | 本计划决策 |
| 确认流先例:破坏性动作走 `pending_confirm` + ConfirmAccepted 重放 | `update_confirm_msgs` |
| Problems 汇聚 build 诊断;`ProjectBuildRun(kind)` 已事件化 | `app/app.mbt`(M0-7) |

## 设计决策

1. **多标签 = 打开文件数组 + active 下标**：
   `open_project_files : Array[OpenProjectFile]` + `open_file_index : Int`
   （旧单槽字段删除,读写点全量迁移;`selected_project_file` 保留为「资源
   管理器高亮」不动）。tab strip 画在文件面板头下沿:rel + 脏 ● / 中键外
   点 = 关闭;脏 tab 关闭走既有确认流（ConfirmAccepted 重放 CloseFile）。
   「保存全部」chip 在任一 tab 脏时出现。
   光标/选区状态随 tab 走:迁入 OpenProjectFile（caret/selection 字段）,
   切 tab 恢复——避免全局单光标状态串台。
2. **文件 CRUD（文件级,目录原语缺位显式降级）**：
   - 新建文件：资源管理器工程行尾「+」→ 输入 rel（包内路径）→ 空内容
     write_text → 回执重扫（复用删除后重扫链）+ 打开新 tab。
   - 重命名：文件行 hover「✎」→ 输入新 rel → read_text(old) →
     write_text(new) → delete_file(old) → 重扫;中途任一步失败 = 结构化
     notice(不静默半完成——已写新文件时提示手动清理)。
   - 打开中的文件被删/改名:对应 tab 关闭(脏内容丢弃前经确认流)。
3. **全文搜索**：模型存 `search_query` + `search_results`(扫描任务逐文件
   read_text 找子串,上限 200 命中/50 文件,进度节流);结果面板挂底栏新页签
   `BtSearch`;点击结果 = 打开该文件 tab + selection 定位到命中行
   （caret 通道已有）。搜索是 @services.ServiceTask 状态机(walk 同款)。
4. **live 诊断 = 保存即构建**:`ProjectFileSaveFinished` 成功后,若
   `compile_track_available` 且无 build 忙,自动发既有
   `EvBuildSubmit(BkStudioCompile)`——诊断汇 Problems 的链路原样复用;
   不做独立防抖计时器(保存是天然节流点)。

## Milestones

### F1 多标签（先做:CRUD/搜索都落在这块地基上）
- [ ] Model:数组化 + 光标状态迁入 tab + Msg(CloseFileTab/SelectFileTab/
      SaveAllFiles/CloseTabConfirmed)+ tab strip 渲染
- [ ] 迁移:open_project_file 全部读写点(编辑/保存/.md 面板/光标回传)
- [ ] 测试:多开/切换/脏关闭确认/保存全部/删除打开中的文件
- 验收:两个文件并行编辑互不串台;脏关闭有确认;保存全部写盘

### F2 文件 CRUD
- [ ] Msg+链:ProjectFileCreateRun/ProjectFileRenameRun + 服务回执 + 重扫
- [ ] 资源管理器交互:+ / ✎ 入口(包行与文件行),输入复用 rename 草稿模式
- [ ] 测试:新建落盘并开 tab;重命名三步链;失败结构化提示
- 验收:资源管理器内完成新建/改名,盘上生效

### F3 全文搜索
- [ ] `app/search_task.mbt`:ServiceTask 状态机(内存树按需 read_text)
- [ ] 底栏 BtSearch 页签:输入 + 结果行(文件/行/摘录) + 点击跳转开 tab
- [ ] 测试:命中上限/跳转打开/空态
- 验收:全工作区搜子串,点击结果落到对应文件

### F4 保存即诊断
- [ ] ProjectFileSaveFinished 成功臂 → compile_track_available 且闲时发
      EvBuildSubmit(BkStudioCompile)
- [ ] 测试:保存触发构建事件;忙时不重复发
- 验收:保存 .mbt 后 Problems 出现编译诊断

## 风险

| 风险 | 缓解 |
|---|---|
| 单槽→数组迁移面广 | 先 F1 全量迁移(编译器兜底),后两层叠加 |
| 重命名三步链半完成 | 每步回执驱动,失败即 notice 说明已到哪步 |
| 搜索扫大仓库慢 | 文件数/命中数双上限 + 进度;树来自扫描缓存不重走 |
