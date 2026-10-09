# MoUI Studio 独立子仓库化

- Status: done
- Goal: 把 `examples/moui_studio` 提取为独立仓库 `wzzc-dev/moui_studio`,
  按 `examples/momark`（`wzzc-dev/momark`）的既有模式以 git submodule 形式
  挂载在本仓库根目录 `moui_studio/`，并保持 `moon.work` workspace 成员身份
  与全部校验/文档引用一致。

## 方案

- 历史：`git subtree split -P examples/moui_studio` 生成仅含 studio 的提交
  历史，落地到独立仓库（dev 侧 `/Volumes/Data/Code/moon/moui-studio`，
  待推送 GitHub `wzzc-dev/moui_studio` 后切 submodule URL）。
- 模块名：`examples/moui_studio` → `wzzc-dev/moui_studio`（对齐 momark）。
  - moon.pkg 内部 import 同步改模块限定名。
  - .mbt / 脚本 / 文档中的**文件路径与命令**引用改为目录名 `moui_studio/...`。
  - `tools/sync_kernel` 路径字符串与生成文件头联动：改完后重跑生成
    （非 `--check`），kernel 镜像头注释同步更新。
- MoUI 侧：删除 `examples/moui_studio`；`moon.work` 成员换为
  `./moui_studio`；更新 `checks/profiles.json`（pr profile studio 步骤）、
  `checks/source-file-policy.json`、`checks/dead-message-catalog.json`、
  `examples/catalog.json`（移除 studio 条目）、`scripts/run-studio-smoke.sh`、
  `scripts/studio-export-smoke.sh`、README、`docs/examples.md`、
  `docs/moui-studio.md`（含 zh-Hans）、`docs/repository-facts.md`、
  `docs/platform-notes-{macos,windows,linux}.md`、`memories/repo/`。
- 独立仓库自带 `.gitignore`（target/.moon/.mooncakes/.config.json 等）；
  `.config.json`（本地 AI 配置，含密钥，不入库）随工作区迁移。

## Non-goals

- 不在本仓库内创建 GitHub 远端仓库；推送由人工完成。
- `sync_kernel` 路径仍按 workspace 根相对（MoUI 根运行）；studio 仓库独立
  运行该工具的路径方案留待后续。
- 历史 plan 文档（`moui-studio-*.md`）保留旧路径作为历史记录，不回写。

## 验证

- `node scripts/generate-i18n-catalogs.mjs --input moui_studio/app/i18n/catalogs.json --out moui_studio/app/i18n_catalog_generated.mbt --check`
- `moon run moui_studio/tools/sync_kernel --target native -- --check`
- `moon test moui_studio/{app,services/compiled_runtime,services/diff,services/compile_native,services/export} --target native`
- 静态校验器六件套 + `validate-check-profiles` / `validate-package-manifest` / `validate-dead-messages`

## 跟进（人工）

1. 创建 GitHub 仓库 `wzzc-dev/moui_studio` 并从 dev 侧仓库推送 main。
2. `git submodule set-url moui-studio git@github.com:wzzc-dev/moui_studio.git`
   （当前 .gitmodules 暂指本地 dev 路径）。
