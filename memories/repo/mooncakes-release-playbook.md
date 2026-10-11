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

## 文档 token 同步面

window 的混合版本号 `0.5.4-0.<moUI 序号>` 出现在:各 moon.mod pin、
moui/README.mbt.md、docs/{examples,platform-notes,platform-notes-linux,
development,release-readiness}.md + zh-Hans 镜像、
skills/moui-framework-development-skill/SKILL.md、
examples/*/README.mbt.md、THIRD_PARTY.md。validate-guidance-consistency
会按工作区清单核对这些 token(含 README.mbt.md),plans/done 的历史记录
不改。website/web_wasm/docs 是生成物,改完 docs 跑
`node scripts/generate-repo-docs.mjs --write` 同步。
