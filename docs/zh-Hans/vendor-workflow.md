# 外部应用的 Vendor 工作流

MoMark（`wzzc-dev/MoMark`）和 MoUI Studio（`wzzc-dev/moui_studio`）是**独立仓库**，
不再是本仓库的 submodule，也不是 `moon.work` 成员。它们使用已发布的
`wzzc-dev/moui*` 模块。

当这些应用需要修改框架时，不要只改 vendored 副本就结束。使用本地 vendor
checkout 在应用里验证，然后把框架改动作为 PR 提回 MoUI。

## 1. 并列 clone

```sh
git clone https://github.com/wzzc-dev/MoUI.git vendor/MoUI
git clone https://github.com/wzzc-dev/MoMark.git
# 或：git clone https://github.com/wzzc-dev/moui_studio.git
```

`vendor/` 不进入消费者仓库提交：

```gitignore
vendor/
```

## 2. 让消费者指向 vendor 源码

MoonBit 的 `moon.mod` 没有 path 依赖；用本地 `moon.work` override。在消费者
仓库里加入应用实际使用的框架模块：

```text
members = [
  ".",
  "vendor/MoUI/moui",
  "vendor/MoUI/moui_richtext",
  "vendor/MoUI/moui_markdown",
]
```

只有消费者入口真正 import 的渲染器/绑定模块才加入（例如
`moui_skia_renderer`、`moui_web_renderer`、`moui_i18n`）。列进 `moon.work`
的模块会用本地源码覆盖 registry pin。

## 3. 修改并验证

编辑 `vendor/MoUI`，先跑消费者自己的测试，再跑 MoUI 对应表面的门禁：

```sh
# 在 vendor/MoUI
moon test moui/core moui/runtime moui/views --target native
sh scripts/check.sh --profile pr
```

只在消费者里能跑、没有 MoUI 测试的改动，不算可以提 PR。

## 4. 把框架改动提回 MoUI

在 `vendor/MoUI` 建分支（它就是一个普通 clone），提交框架改动和测试，push 到
fork 或上游，向 `wzzc-dev/MoUI` 开 PR。遵循 `CONTRIBUTING.md` 和 `AGENTS.md`
的任务路由。

PR 不包含消费者仓库、生成的 bundle 或 `vendor/` 目录。

## 5. 发布后更新消费者 pin

MoUI 改动发布后：

1. 更新消费者 `moon.mod` 里的 `wzzc-dev/moui*` 版本。
2. 从消费者 `moon.work` 移除临时 `vendor/MoUI` 成员。
3. 用已发布包跑消费者测试。
4. 保持 `vendor/` 被 gitignore；删除它或留作未提交的本地缓存。

## 规则

- **不留孤儿补丁**：应用依赖的 `vendor/MoUI` 改动必须有对应的 MoUI PR。
- **不提交 vendor**：永远不要把 `vendor/` 提交进应用仓库。
- **新包/新模块先发布**：消费者需要新的公开包时，先在 MoUI 发布，再在消费者 pin。
- **外部 CI 仍走 registry**：本地 vendor override 只是开发工具；CI 必须解析已发布版本。
- **框架归属留在本仓库**：应用模型、页面、平台入口留在消费者仓库；只有可复用框架改动进入 MoUI。
