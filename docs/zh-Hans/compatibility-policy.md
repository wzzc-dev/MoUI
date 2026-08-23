# 兼容性与生态策略

MoUI 在 [`checks/compatibility-policy.json`](../../checks/compatibility-policy.json) 和 [`checks/component-quality.json`](../../checks/component-quality.json) 中发布机器可读的权威来源。本页说明包消费者应如何使用它们。

## 版本

MoUI 对已发布模块使用 SemVer。补丁版本包含修复与文档；小版本新增向后兼容的应用 API；大版本可能改变公开 API、包边界或宿主连线契约。在 `0.x` 阶段，小版本仍可能包含破坏性变更，但必须在同一版本中提供升级说明与迁移示例。

## 废弃

API 废弃需记录其替代方案、开始通知的版本、计划移除版本以及迁移说明。默认通知期至少两个版本且不少于六个月。安全或法律原因的移除可在 ADR 与发布说明解释影响的前提下缩短窗口。

## 质量等级

`stable` 表示已具备聚焦测试、文档与可维护的消费者/示例。`preview` 表示 API 已公开但宿主覆盖或行为仍不完整。`experimental` 为诊断或平台特定能力，不附带产品就绪承诺。证据路径由 `node scripts/validate-ecosystem-metadata.mjs` 校验。

## 消费者门禁

每个包变更都应从仓库外部校验：

```sh
node scripts/validate-ecosystem-metadata.mjs
node scripts/external-consumer-ci.mjs --source package --profile base
```

该门禁会解析已暂存的包闭包，拒绝 monorepo 源码路径，检查依赖闭包并编译/测试外部消费者。CI 会在源码可用的 base、Skia、Web profile 上运行该门禁。新建控件与宿主服务请使用 [`docs/templates.md`](templates.md) 中的扩展模板。
