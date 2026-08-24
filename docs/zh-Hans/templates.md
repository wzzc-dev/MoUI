# 包与插件模板

添加包、平台服务桥、渲染器能力或 Showcase 覆盖时使用这些模板。让每个新增切片都能
独立测试。面向最终用户的应用骨架使用 [应用模板](app-templates.md)；本文用于仓库维护模式。

## 包模板

```text
<package>/
  moon.pkg
  <feature>.mbt
  <feature>_test.mbt
  pkg.generated.mbti
```

检查清单：

- 在 `moon.pkg` 中维护 imports。
- 保持公共 API 小而有意图。
- 保留 `///|` 分隔符。
- 先添加包内测试，再扩展到更宽的示例。
- 公共 API 变化后运行 `moon info`。

## 宿主服务模板

```moonbit
pub fn platform_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(@moui.ColorScheme::Light)
        _ => @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}
```

检查清单：

- 先在 `backend` 中添加共享请求和响应类型。
- 让不可用服务受 capability gate 约束。
- 为成功路径和 unavailable 路径添加宿主与后端测试。

## 渲染器能力模板

检查清单：

- 添加中立绘制命令，或更新现有命令。
- 在 `renderer_feature_capability_report` 中添加功能状态。
- 为跳过的高级命令添加兜底 planner 覆盖。
- 更新原生/Web adapter 测试。
- 更新 `docs/renderer-capability-report.md`。
- 当渲染器能力与文本相关时，也要更新 `docs/text-system.md`。

## Showcase 入口模板

检查清单：

- 分类和可搜索标签。
- 预览视图规格。
- 构造器/API 说明。
- 语义说明。
- 测试覆盖说明。
- 相关时添加渲染器/平台说明。

## 文档与指南模板

检查清单：

- 保持根 `README.md` 作为简短入口和唯一源文件。
- 将设置和命令循环放在 `docs/development.md`。
- 将平台注意事项放在 `docs/platform-notes-<platform>.md`
  （例如 `platform-notes-linux.md`）。跨平台宿主契约放在 `docs/platform-notes.md`。
- 将文本架构放在 `docs/text-system.md`。
- 将 Markdown Editor 行为放在 `docs/markdown-editor.md`。
- 将验证策略放在 `docs/testing.md`。
- 当指南可能变旧时，检查 `AGENTS.md` 和 `skills/`。
