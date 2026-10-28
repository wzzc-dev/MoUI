# Mooncakes Release Playbook

2026-09-29 的 0.2.0 全量发布实测(19 个目录模块 + window 子模块)。发布目录
以 `checks/release-modules.json` 为唯一权威(4 阶段:base-bindings →
renderers → addons → entrypoints),模块内部依赖关系决定阶段顺序。

2026-10-06 的 0.2.1 增量发布(window@0.5.4-0.2.1 + dock icon 特性)沿用本
手册一次通过:19 个公开模块 + window 全部 200 OK,阶段间 `moon update`。
新增经验:`moon publish --dry-run` 在服务器 202 后仍可能以非零码退出,以
"Server status" 行为准,不代表失败。

## moon publish 的三个坑(都会以 "moon check failed" 假象出现)

1. **索引滞后**:刚发布的依赖版本,下一个模块的发布沙箱解析不到
   (`no version satisfies requirement`)。对策:每次发布之间跑
   `moon update`(输出 "Registry index updated successfully" 才算刷新)。
2. **license 字段必填**:moon.mod 没有 `license = "Apache-2.0"` 直接
   400 Bad Request(报错信息会明说)。补在 version 行之后。
3. **默认 wasm 校验**:moon.mod 没有 `preferred_target` 时,发布沙箱用
   wasm 后端跑 check;native-only 模块(moui_agent/moui_i18n 等
   supported_targets 不含 wasm)会报
   `does not support target backend 'wasm'`。对策:moon.mod 里显式写
   `preferred_target = "native"`(先例:moui_3d_physics),不要为过校验虚报
   `+wasm` 支持。

## 依赖 pin 与工作区屏蔽

- 工作区把 moonbitlang/x 等第三方依赖解析到所有成员的最大版本——模块
  自己的旧 pin(如 x@0.5.1)在工作区里编译通过,发布沙箱按模块 pin 解析
  才爆出 API 不存在(moui_cli 的 `lexical_compare` 需要新 x)。发布前
  每个模块单独 `cd <dir> && moon check` 不能暴露这个,要用发布沙箱或
  在模块目录里 `moon update && moon check` 按自身 pin 验证。
- `checks/external-consumer/moon.mod` 的 `wzzc-dev/moui@0.1.7` 是**故意的**
  兼容测试钉(docs/testing.md "Until 0.2 is published" 句),不要跟随
  全量 bump;0.2 发布后是否切到 registry 模式测 0.2 是独立决策。
- 从未上过 mooncakes 的内部模块(moui_tests/moui_tools/
  moui_product_tools/moui_3d_web_renderer/moui_3d_wgpu_renderer/momark)
  只 bump 版本号不发布,保持工作区 override 无警告。
- 新增的**公开** addon(moui_markdown@0.2.1 之类)原则上进 release catalog,但
  首次发布前只存在于工作区;此时下游独立仓库(如 moui_studio,moon.work 不
  覆盖其 standalone clone)不能 pin 它——独立 `moon build` 会按 registry 解析
  失败。顺序是:在 MoUI 内验证通过 → 发布模块 → 下游再 pin + moon update。
  判断模块是否已上架:`~/.moon/registry/index/user/<owner>/<name>.index`
  是否存在。
- **模块内新增的包(package)同样受这条时序约束**,不只新模块。例:`moui_cli`
  里新增的 `scaffold_plan` 纯生成器包在 `moui_cli` 下次发布前只存在于工作区,
  Studio 若加 `wzzc-dev/moui_cli` 依赖,独立 clone 会解析到注册表里**没有这个包**
  的旧版本而编译失败;`validate_workspace_pins` 又把 pin 钉在
  `checks/release-modules.json` 的已发布版本上,所以「先发布再 pin」在这里是
  门禁强制而不是可绕的工程选择。
- **发布必须从已提交的干净树执行**(2026-10-16 实测):`moui_cli@0.2.3` 从
  未提交的中间态树发布(发布 18:24,最终提交 22:15),注册表内容与同版本号
  的源码不一致——缺 `scaffold_plan` 的 `app_alias` 参数与 `web_abi.mbt`,
  Studio 独立 CI 全线 4085/4021。版本不可重发,只能 bump `0.2.4` 重 pin。
  发布前先 `git status` 确认无未提交改动,并抽查 tarball
  (`moon publish --dry-run` 后解包 `_build/publish/*.zip`)与工作区一致。

## 主线加字段 = 发布线必须追（2026-10-26 实测）

`moui_studio` 是子仓库、**独立 CI 按自身 `moon.mod` 从 registry 解析
`wzzc-dev/moui`**，而它在母仓库里又是 workspace 成员（按主线源码编译）。
两边对同一个文件的要求因此会分叉，改主线 API 时判定顺序是：

1. 先问「这个东西下游子仓库会写吗」。会写就得发布，不是改子仓库能解决的。
2. 典型受害者是**结构性变化**：函数加参数（`web_dispatch_pointer_input`
   8→10）、`pub(all) struct` 加字段（`ImageRun.src_rect`）。子仓库照主线
   写完，独立 CI 必然 `requires 8 arguments` / `Record fields src_rect are
   undefined`。
3. 只发 base 不够：**中间 addon 也要跟着重发**。本次 `moui@0.2.5` 发完后
   Studio 仍红，因为 `moui_richtext@0.2.2` 自己也构造 `ImageRun` 字面量、
   缺 `src_rect`；补发 `moui_richtext@0.2.3` 才通。判断方法：在 workspace
   里 grep 该结构的构造点（`ImageRun::{`、`DrawImage({`），按发布模块分组。
4. 发布前用**干净 clone + 自身 pin** 实测，而不是 workspace：
   `git clone <subrepo> && moon update && moon check && moon build web_wasm
   --target wasm-gc`。workspace 里永远绿，掩盖问题。

本次提交链：`moui@0.2.5` → `moui_richtext@0.2.3` → `moui_studio@aec8746`
（pin 双升）→ 母仓库子模块指针。`moon publish` 在 workspace 成员目录里
**不能只发一个模块就完事**，被 pin 的中间层要一起走。

## 文档 token 同步面

window 的混合版本号 `0.5.4-0.<moUI 序号>` 出现在:各 moon.mod pin、
moui/README.mbt.md、docs/{examples,platform-notes,platform-notes-linux,
development,release-readiness}.md + zh-Hans 镜像、
skills/moui-framework-development-skill/SKILL.md、
examples/*/README.mbt.md、THIRD_PARTY.md。validate-guidance-consistency
会按工作区清单核对这些 token(含 README.mbt.md),plans/done 的历史记录
不改。website/web_wasm/docs 是生成物,改完 docs 跑
`node scripts/generate-repo-docs.mjs --write` 同步。

## 新增/搬移顶层模块时要登记的枚举位点(2026-10-27 L0.5 实测)

门禁按「显式列出模块名」工作,漏登记不会报错,只会静默失去覆盖。分两类:

- **会响亮失败**:`moon.work` 成员、`checks/release-modules.json` 行、
  `docs/architecture-map.md` 归属行、消费者 moon.mod pin。
- **静默失覆盖(必须逐条补)**:`checks/source-file-policy.json` `roots`(否则
  新目录整体离开行数门)、`tools/moui/validate_maintenance_baseline/scan_scope.mbt`
  的 `monitored_roots("full")`、`tools/moui/validate_runtime_state_render_ownership/validation.mbt`
  全局扫描根、`checks/backend-common-ownership.json` `sourceRoots`(注意
  `rendererModules` 只放渲染器)、
  `tools/moui/validate_renderer_provider_manifests/main.mbt` 各平台后端禁用清单
  (它原先靠 `wzzc-dev/moui_wgpu_renderer` 子串命中 provider)、
  `scripts/external-consumer-ci.mjs` 各 profile 的禁用闭包、
  `tools/moui/validate_api_surface/main.mbt` 里按路径 key 的 PackageBudget。

反向清单(核实过**不该**加):`compatibility-policy.json` `apiTiers` 全文无读取者
(repo 内只有自身定义 + 一条 session 记录提到);`backend-common-ownership.json`
`packageRules.forbiddenImports` 的匹配是「带引号的完整包 token」
(`validate_backend_common_boundary/validation.mbt:192-194`),所以既命不中子包
导入,也命不中不存在根包的模块名 —— 加了就是死配置。

