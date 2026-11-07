# Addon Package 指南

如何构建、校验并发布第三方 MoUI addon —— 一个由 MoUI 应用消费的版本化
MoonBit 模块，包含自定义控件、领域辅助函数和服务契约。状态：`canonical`。

本地脚手架：

```sh
moui new --template addon my_addon
cd my_addon && moon test --target native
```

## 模块布局

```text
my_addon/
├── moon.mod              # name = <owner>/my_addon；只 import wzzc-dev/moui
├── moon.work             # members = ["."]
├── moui.project.json     # 生成的身份清单
└── src/                  # 控件与契约源码
```

## 依赖边界

- addon 只依赖 `wzzc-dev/moui`（以及纯领域包）；不依赖 `runtime`、
  `render/*` 或平台 backend。
- 新控件实现 `@core.ViewNode` 具体子类型，用 `@core.View::from_node`
  构造，不新增 core view 枚举变体。
- 服务契约只通过 `moui/services` 的接口面声明。

## 校验

```sh
moon check --target native
moon test --target native
node scripts/validate-api-surface.mjs   # 仅发布方需要
```

## 发布

用 `moon publish` 发布到 mooncakes 仓库；版本遵循仓库兼容性策略
（`docs/compatibility-policy.md`）。发布前确认包的公开 API 有意导出，
并为每个公开控件补齐最小文档与测试。
