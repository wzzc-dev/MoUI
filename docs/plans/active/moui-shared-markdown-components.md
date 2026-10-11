# Plan: 提取共享 Markdown 组件（`moui_markdown`）——MoMark chrome → 公共组件

- **Status**: active · 起始 2026-10-11 · 来源会话：用户直接需求
- **Goal**: 把 MoMark（`examples/momark/app`）里与 Markdown 相关、且与具体 app
  状态无关的能力，提取为新的公共 addon 模块 `moui_markdown`：查找/替换引擎、
  大纲辅助与折叠、格式面板目录与 action→command 映射、文档信息统计、HTML
  导出、Msg-generic 的 chrome 视图（大纲面板、查找替换栏、格式面板）。
  让 MoUI Studio 的 `.md` 面板可以直接复用这些组件，把查看/编辑体验从
  "裸 session 编辑面" 提升到接近 MoMark 的水平。
- **Non-goals**:
  - 不把 `moui_richtext` 中已有的 Markdown 引擎/会话再次搬迁（那是
    `docs/plans/active/richtext-markdown-domain-relocation.md` 的范围，本计划只
    新增其上的 chrome 层）。
  - 不做 MoMark 的完整迁移：MoMark 侧接线（它自己的仓库）与 Studio app 侧接线
    各自单独提交；MoUI 仓库本轮只交付公共模块 + 测试 + 记账。
  - 不引入新的 `@core.ViewNode`：视图层用既有 `@views` 构造器拼装（既有
    硬边界：新内置控件才允许 node；这里没有新控件）。
  - 不做富文本 WYSIWYG 引擎增强（引擎侧只读消费）。

## 背景（已核实）

- Studio `.md` 与 MoMark **已共用同一引擎**：
  `moui_studio/plugins/markdown/markdown_view.mbt` 调
  `@richtext.controlled_markdown_session_editor`。差距全在 MoMark 的 app 层
  chrome：大纲侧栏、查找/替换、格式面板、源码模式、文档信息、HTML 导出。
- MoMark `app` 不用 `examples/momark/app` 内的 priv 函数名被 Studio 直接引用，
  必须有一个宿主无关的公共模块才能共享。
- `docs/plans/active/richtext-markdown-domain-relocation.md` 早已把
  `moui_markdown` 定为 Markdown 领域的目标模块名（addons 发布阶段），本计划
  与其分层一致：`moui_richtext`（L0 引擎）→ `moui_markdown`（L1 chrome 组件）
  → MoMark / Studio（L2 接线）。

## Acceptance

- [x] `moui_markdown/` 存在，`moon.work` / `checks/release-modules.json`
      （role=addon, releaseStage=addons, version 与 workspace pin 一致）/
      `checks/source-file-policy.json` / `checks/profiles.json` 记账齐备。
- [x] 纯函数层（find 引擎、大纲辅助/折叠、格式面板目录 + action→command 映射、
      文档信息统计、HTML 导出）带白盒测试，`moon test moui_markdown --target
      native` 绿。
- [x] Msg-generic 视图层（大纲面板、查找替换栏、格式面板）可被任意 `Msg`
      实例化，颜色/字体/文案参数注入，零 app 依赖、零 `runtime` 依赖
      （wbtest 除外）。
- [ ] 至少一个真实消费方证明可用：`moui_markdown` 尚未发布到
      registry（`~/.moon/registry/index/user/wzzc-dev/` 无索引），Studio
      standalone `git clone` + `moon build` 依赖 registry 解析；本轮不接线，
      发布后作为 follow-up（Studio `app/**` 同时存在他人未提交改动，也不宜
      在本轮触碰）。
- [x] 静态门绿：validate-maintenance-baseline / validate-api-surface /
      validate-release-module-closures / validate-guidance-consistency /
      validate-doc-references。
- [x] 文档更新：`docs/markdown-editor.md`（+zh-Hans）、
      `docs/architecture-map.md`（+zh-Hans）新增 `moui_markdown` 行。

## Decision log

| 日期 | 决策 | 理由 |
|---|---|---|
| 2026-10-11 | 新建独立 addon `wzzc-dev/moui_markdown`，作为 `moui_richtext` 的 peer（不是把 chrome 塞进 richtext） | richtext 要朝 generic rich-text 收缩（relocation plan）；chrome 是 Markdown 专有域，且 momark 是 native-only 应用，公共域必须 target-neutral |
| 2026-10-11 | 组件全部 Msg-generic、回调注入、主题/文案参数化（不硬编码 MoMark 的 `MarkdownEditorMsg`） | Studio 插件纪律：零 app 依赖；MoMark 与 Studio 的 Msg 类型不同 |
| 2026-10-11 | 不做自定义 ViewNode：视图用 `@views` 组合 | 仓库硬边界（新内置控件才进 `moui/views`）；组合层足够表达大纲/查找/格式面板 |
| 2026-10-11 | find 引擎的 whole-word 语义保持 ASCII word char（与引擎 `markdown_editor_ascii_word_char` 一致） | 迁移必须行为等价，MoMark 测试可直接平移断言 |
| 2026-10-11 | 状态文案（"Ready"/"Invalid regex"/"No match"/"n/m"）保留英文默认并作为参数注入 | 默认等价迁移；i18n 留给消费方 |

## 工作切片

1. **S1 模块骨架 + 记账**：`moui_markdown/moon.mod`（0.2.1，pin
   `wzzc-dev/moui@0.2.2` + `wzzc-dev/moui_richtext@0.2.1`）、`moon.pkg`、
   `moon.work`、release catalog、source policy roots、pr profile、scan scope。
2. **S2 纯函数**：`find.mbt`（匹配/正则/选区种子/next-prev-active/替换/状态
   文案/`MarkdownFindOptions`）、`outline.mbt`（折叠、label、缩进、active
   index、reading label）、`palette.mbt`（条目目录、过滤、
   `markdown_command_from_palette_action`）、`document_info.mbt`（统计 +
   从 session/snapshot 派生）、`html_export.mbt`。
3. **S3 视图层**：`outline_panel`、`find_bar`、`format_palette`（Msg-generic，
   主题与回调注入）。
4. **S4 消费方**：MoMark 仓库侧迁移（在其仓库提交后 bump 子模块指针）；Studio
   `plugins/markdown` 接线（app/** 脏文件不碰，接线若需要动 app 则先交付纯函数
   + 面板 API 并记录 follow-up）。
5. **S5 收尾**：mbti 生成提交、双语文档、六个静态门、必要时
   `memories/repo/`。

## Follow-up：Studio 接线（发布 `moui_markdown` 之后）

1. `moon publish` 发布 `wzzc-dev/moui_markdown@0.2.1`（依赖已在上一批发布的
   `moui@0.2.2` / `moui_richtext@0.2.1`），然后 `moon update` 刷新索引。
2. 在 `moui_studio/moon.mod` 加 `wzzc-dev/moui_markdown@0.2.1`；在
   `moui_studio/plugins/markdown/moon.pkg` 用 `@mdchrome` 别名 import（本包
   自身 alias 是 `markdown`，直接用默认名会撞）。
3. 插件层（`plugins/markdown/markdown_view.mbt`）把现在手写的 chrome 换成
   `@mdchrome.markdown_find_bar` / `markdown_document_info_panel`；新增大纲
   与格式面板的 `Msg` 分支与折叠/替换状态（纯函数用 `@mdchrome.markdown_*`
   系列，避免 Studio 再维护第二份匹配语义）。
4. `app/code_view.mbt` 的 `project_file_body` / `project_file_body_height`
   接入面板高度与侧栏布局；`.md` 已有 `md_session` 与
   `ProjectFileMarkdownTransaction` 消息，直接在现有分流上加 chrome 状态。
5. MoMark 仓库侧同一批迁移（`view_chrome.mbt` / `view_inspectors.mbt` /
   `editor_actions.mbt` 的 priv 实现换成 `@mdchrome` 调用），迁移后 bump
   `examples/momark` 子模块指针并在 MoUI 仓库重建基线。

## Progress

| 日期 | 记录 |
|---|---|
| 2026-10-11 | plan 建立；基线：momark 472/472、moui_richtext 325/325、studio app 422/422 绿 |
| 2026-10-11 | S1 完成：新建 `moui_markdown`（0.2.1，pin `moui@0.2.2` + `moui_richtext@0.2.1`，addon/addons）+ `moon.work` / release catalog / source policy / pr profile（step 47）/ scan scope / doc-reference roots 记账 |
| 2026-10-11 | S2+S3 完成：`find` / `outline` / `palette` / `document_info` / `html_export` 纯函数 + 4 个 Msg-generic 视图（find bar、outline、format palette、document info）；6 个 wbtest 文件 native 33/33、wasm-gc 33/33 绿，`moon check --target wasm/wasm-gc` 绿；`moon info` 生成 `pkg.generated.mbti`，`check-generated-interfaces.mjs` ok（209 tracked packages） |
| 2026-10-11 | 六个静态门全绿：maintenance baseline / api surface / release-module closures / guidance consistency / renderer capability consistency（51 cells）/ doc references（112 files）；`generate-repo-docs.mjs --check` 绿 |
| 2026-10-11 | S5 文档完成：`docs/markdown-editor.md`（+zh-Hans）加共享 chrome 章节，`docs/architecture-map.md`（+zh-Hans）与 `docs/architecture.md`（+zh-Hans）加 `moui_markdown` 行；website docs 已 `generate-repo-docs.mjs --write` 同步，`--check` 绿 |
| 2026-10-11 | 回归：`moui_markdown` native 33/33、wasm-gc 33/33；`moui_richtext` 325/325、`examples/momark/app` 472/472、`moui_studio/app` 422/422 均与基线一致（引擎未动，无回归）。 |
| 2026-10-11 | S4 可用性探针：在 Studio `moon.mod` + `plugins/markdown/moon.pkg` 临时加依赖（`@mdchrome` 别名），`moon check` 在工作区内通过（workspace 解析未发布模块 OK）；确认插件包默认 alias `markdown` 与模块名冲突后，已 revert 探针改动，Studio 工作树恢复原状。 |
| 2026-10-11 | S4 决策：本轮不接 MoMark / Studio。`moui_markdown` 未发布（registry 无索引），Studio standalone clone 会因缺失依赖失败；Studio `app/**` 另有他人未提交改动。MoMark 迁移与 Studio 插件接线分别在发布后单独提交。 |
| 2026-10-11 | fmt 事故与恢复：在 `moui_markdown/` 内跑 `moon fmt` 时按 workspace 全量执行（2558 tasks），除本模块外还规范化了 `moui_studio/app/**` 下 14 个**他人未提交**文件（`app.mbt` 由 2566 → 2567 行触发 maintenance 棘轮）。全部 14 个文件已从子模块 `.git` 的 unreachable blob 中按"moonfmt(pre-image) == 现行 post-fmt 内容"唯一匹配恢复原始字节（`app.mbt` 恢复后 2566 行，diff stat 回到事故前 1019+/970-），无需 bump 棘轮；事后复验：studio app native 422/422、六个静态门 + generated interfaces + repo docs 全绿。教训：**不要在工作区内直接跑 bare `moon fmt`**（会全 workspace 重写），只对本模块文件用 `moonfmt <file> -w` 或 `moon fmt <path>`。 |
