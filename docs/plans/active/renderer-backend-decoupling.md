# MoUI 渲染器与后端解耦架构方案

- 文档状态：Proposal（待评审）
- 作者：高见远（首席架构师）
- 日期：2026-08
- 适用仓库：`/Volumes/Data/Code/moon/MoUI`
- 关联不变量：P5 / P6 / P9 / P11 / P12 / R1 / R2 / R3 / R7 / A2
- 关联 ADR：0019（provider 契约）、0020（平台适配器重复度）、0022（native WGPU 实验性）、0023（sun 实验性）
- 配套治理文书（非新 ADR）：`docs/decisions/0007-renderer-and-skia.md` 的 `## 0019-A` 小节（ADR 0019 补充条款 / Phase E close-out 补完，按主题合并归档）

本文档中所有标记使用 `[OK]` / `[NG]` / `[RISK]` 文字形式，不使用 emoji。

---

## 0. 结论速览

**本方案定位：ADR 0019 / Phase E 的 close-out 补完，不引入新架构范式。** 它补齐 Phase E（`docs/plans/done/moui-architecture-convergence.md:94-125`，2026-07-29 声明 E1-E8 complete）声称完成但未真正达到验收的遗留缺口，而非提出新设计。相应治理文书不新增 ADR，改为 ADR 0019 补充条款（errata/close-out），合并归档于 `docs/decisions/0007-renderer-and-skia.md` 的 `## 0019-A` 小节。

用户的原始命题是「每个后端都需要单独引入不同的渲染器，导致重复依赖和耦合，需要引入统一的渲染器抽象接口」。

**这个前提需要修正。统一的渲染器抽象接口在 MoUI 里已经存在并且已经落地**（ADR 0019，`moui/render/provider_contract.mbt`）。真正的问题是另外四条：

| 编号 | 真实问题 | 证据 |
|------|----------|------|
| D1 | 抽象**可被绕过**：平台基座暴露的注入点是 `<Platform>RendererProvider`（接受任意闭包），不是 `RendererProviderBinding`。13 个绑定包里有 6 个从未调用过 `select_renderer_provider_binding` | `moui/backend/macos/macos_backend.mbt:53`；grep 结果见 §1.2 |
| D2 | 注入点本身被复制了 4 份，差异仅在窗口类型 | `macos_backend.mbt:53`、`linux_backend.mbt:59`、`windows_backend.mbt:53`、`internal/embedded_runtime_backend/hosted_window_backend.mbt:33` |
| D3 | O(P×R) 组合爆炸 + 转发样板：**已恶化为功能缺陷**——9 条绑定线 7 条丢字段，合计 19 处能力丢失 | §1.3 实测；§1.3.1 漂移矩阵 |
| D4 | `backend/web`、`backend/wechat` 两个平台基座直接 import 具体渲染器，破坏了 native 侧已建立的解耦 | `web/moon.pkg:7`、`wechat/moon.pkg:5`、`wechat/host_runtime.mbt:12,37` |

**紧迫性（为什么这不是可延后的技术债）**：D3 的「样板复制」早已越过代码冗余，变成**已交付的功能缺陷**。`§1.3.1` 的字段漂移矩阵证明，当前 9 条桌面绑定线里有 7 条在透传 `AppOptions` 时丢掉了基座字段，合计 19 处——用户已经拿不到这些功能（例如 wgpu 线丢失 `platform_view_plugins`，使 WebView/原生地图整类平台视图插件在该路径下不可用）。这正是 `§6` 把「19 处丢失归零」设为机器验收门槛的原因。

对应用户三个诉求的回答：

- **统一抽象接口还是管理模块？** 接口已有，不要再造。需要补的是**装配复用机制**（composition helpers），放进已有的 `moui/render`，**不新建 `moui/render/composition` 包**（理由见 §3.6）。
- **依赖注入还是工厂模式？** 两者都已在用且应当保留：渲染器包出**工厂**（`create_*_provider`），平台基座收**注入**（`HostRendererAdapter[W]`）。要改的是让注入点变成**唯一且泛型**的，而不是每个平台一份。
- **新增后端时无需改动渲染器引入逻辑？** 通过「平台基座只认 `HostRendererAdapter[W]`，绑定包只出 provider 工厂」达成。新增平台 = 新增 1 个平台基座 + 每个需要支持的渲染器 1 个约 130 行的绑定包（当前约 340 行起）；**渲染器包一行不改**。

推荐方案：**方案 D（收敛装配壳 + 泛型注入点 + web/wechat 归位）**。方案对比见 §5。

**必须正面说明的硬约束**：MoonBit 的 `moon.pkg` 只支持按 target（native/wasm-gc/wasm）门控文件，**不支持按特性开关门控 import**。因此「一个平台包内注册多渲染器 + 特性开关」（方案 B）在链接层面不可实现——skia / wgpu / sun 各自携带 `native-stub` 与 `cc-link-flags`，无法在同一个二进制里条件排除。**编译期选择必须继续由「入口 main 包 import 哪个绑定包」来表达**，本方案完整保留这一机制。

---

## 1. 现状诊断（Ground Truth）

### 1.1 已经解决的部分：provider 抽象确实存在

`moui/render/provider_contract.mbt` 定义了完整契约：

| 契约 | 位置 | 内容 |
|------|------|------|
| `RendererProvider` | `provider_contract.mbt:80-96` | `id` / `descriptor` / `capabilities` / `negotiate` / `create`，struct + 函数字段手写 vtable |
| `RendererInstance` | `provider_contract.mbt:42-50` | `render_frame` / `recover` / `dispose` |
| `RendererProviderBinding` | `provider_contract.mbt:104-107` | `provider` + `create_host_renderer` |
| `RendererProviderRegistry` | `provider_contract.mbt:153-207` | `new` / `register` / `providers` / `lookup` / `select` |
| `select_renderer_provider_binding` | `provider_contract.mbt:128-140` | 按注册顺序 negotiate，首个接受者胜出 |
| 共享装配壳 | `provider_shell.mbt:16-116` | `new_provider_instance`（disposed guard + 单次 dispose）、`negotiate_cpu_raster_surface`、`negotiate_gpu_surface` |

平台基座包的 `moon.pkg` 也确实是干净的：`backend/macos/moon.pkg`、`backend/linux/moon.pkg`、`backend/windows/moon.pkg` 只 import `wzzc-dev/moui/render`（抽象层），不 import 任何 `render/<renderer>`。

**结论：不要重复造 provider 抽象。任何「把 `RendererProvider` 改成 trait」的提议都是倒退**——MoonBit 无 blanket impl，只有类型所属包或 trait 所属包能写 impl，外部渲染器包无法为 MoUI 自有类型 impl trait，手写 vtable 是当前语言条件下的正确解。

### 1.2 真问题 D1：Phase E E6 要求未被遵守（遗留缺口，非新问题）

> 定性更正：这**不是**新发现的架构问题。Phase E（ADR 0019）的 E6 条款（`docs/plans/done/moui-architecture-convergence.md:105-107`）白纸黑字要求「platform composition roots register compile-time provider bindings；selection = provider negotiation, not central switch」，且 2026-07-29 已声明「E1-E8 implementation is complete」（同文件 :116-117）。但 6 个绑定包绕过协商，使 E6 的既定要求**验收未达成**——属已完成 Phase 的遗留缺口，而非本方案新引入的缺陷。

平台基座暴露的实际注入点不是 ADR 0019 的 `RendererProviderBinding`，而是平台自有的 `MacosRendererProvider`：

```
moui/backend/macos/macos_backend.mbt:53-57
pub struct MacosRendererProvider {
  priv create_renderer : (@window_macos.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface   : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader   : @render.HostAsyncImageLoader?
}
```

`run_app_with_renderer_provider(provider~ : MacosRendererProvider, ...)`（`macos_app_runtime.mbt:5-21`）接受的是它。而 `MacosRendererProvider::new(create_renderer=<任意闭包>)` 对闭包内容没有任何约束，**于是 ADR 0019 的协商流程在实践中是可选的**。

实测：调用 `select_renderer_provider_binding` 的绑定包只有 7 个（`macos/skia:532`、`linux/skia:360`、`windows/skia:366`、`ios/skia:176`、`android/skia:157`、`harmonyos/skia:156`、`wechat/canvas:75`）加 `backend/web:38`。

**从未调用协商的 6 个绑定包**：`macos/sun`、`macos/wgpu`、`linux/sun`、`linux/wgpu`、`windows/sun`、`windows/wgpu`。

以 `macos/sun` 为例，它直接把裸闭包塞进注入点（`macos_sun_provider.mbt:128-137`）：

```
pub fn renderer_provider(options? : MacosSunAppOptions = ...) -> @macos_host.MacosRendererProvider {
  @macos_host.MacosRendererProvider::new(
    create_renderer=(window, metrics) => { create_renderer(window, metrics, options) },
    image_loader=Some(sun_native_image_loader()),
  )
}
```

`@sun_renderer.create_sun_provider` 存在（`moui/render/sun/provider.mbt:13`），但 `macos/sun` 根本没用它。这意味着 sun / wgpu 路径上，provider 的 `id`、`descriptor`、`capabilities`、`negotiate` 全部形同虚设，能力上报与 P11 预算校验对这 6 个包实际失效。

**这是「耦合」的真实形态：不是缺抽象，是抽象没有强制力。**

### 1.3 真问题 D3：O(P×R) 组合爆炸与样板复制（实测）

13 个绑定包，非测试代码合计 **8537 行**：

| 包 | 行数 | 是否走 ADR 0019 协商 |
|---|---:|---|
| `macos/skia` | 1293 | Yes |
| `linux/skia` | 1133 | Yes |
| `windows/skia` | 1012 | Yes |
| `macos/sun` | 758 | No |
| `windows/sun` | 665 | No |
| `ios/skia` | 636 | Yes |
| `android/skia` | 589 | Yes |
| `linux/sun` | 575 | No |
| `harmonyos/skia` | 523 | Yes |
| `macos/wgpu` | 478 | No |
| `windows/wgpu` | 343 | No |
| `linux/wgpu` | 341 | No |
| `wechat/canvas` | 191 | Yes |

其中可机械消除的重复：

| 重复项 | 分布 | 每份行数 | 合计 |
|--------|------|---------:|-----:|
| `fn renderer_metrics_from_host` | **全部 12 个** desktop/embedded 绑定包 | 约 26 | 约 312 |
| `<Platform><Renderer>AppOptions` + `SmokeOptions` + `run_*` 逐字段拆装 | 12 个包（实测 179/110/97/97/74/64/64/46/46/10/10/10） | — | **807** |
| `MOUI_SKIA_RENDERER` 环境变量解析 + route 解析 | `macos/skia:89`、`linux/skia:34`、`windows/skia:45` | 约 24 | 约 72 |
| `<Platform>RendererProvider` 结构 + `::new` | macos/linux/windows + embedded adapter | 约 16 | 约 64 |

合计约 **1255 行**纯机械复制。

`macos/sun` 的 758 行里，前 125 行（`macos_sun_provider.mbt:2-125`）是教科书级样板：`MacosSunAppOptions` 的 6 个 `priv` 字段是 `@macos_host.MacosHostAppOptions` 的逐字拷贝，4 个 `run_*` 入口各自把它拆开再组装回去。`macos/skia` 的 `MacosSkiaSmokeOptions`（9 个字段，`macos_skia_provider.mbt:44-54`）同样是 `MacosHostSmokeOptions` 的逐字拷贝。

#### 1.3.1 D3 的能力丢失实质：19 处字段漂移矩阵

§1.3 的量纲是「代码行数」，只能论证冗余。本小节把 D3 的定性从「样板债」升级为「**已交付的功能缺陷**」：逐字段比对每个绑定包实际透传的字段与其平台基座 `HostAppOptions` 的字段集合（差集即丢失）。矩阵由项目总监在门禁复盘中实测（2026-08-02）：

| 绑定包 | 基座字段 | 透传 | 丢失 | 丢失明细 |
|---|---:|---:|---:|---|
| `macos/skia` | 7 | 7 | 0 | — 完整 |
| `macos/sun` | 7 | 6 | 1 | `event_sources` |
| `macos/wgpu` | 7 | 1 | 6 | `event_sources`、`platform_view_plugins`、`transparent_titlebar`、`platform_attributes`、`on_ready`、`min_window_size` |
| `linux/skia` | 5 | 3 | 2 | `transparent_titlebar`、`platform_attributes` |
| `linux/sun` | 5 | 2 | 3 | `event_sources`、`transparent_titlebar`、`platform_attributes` |
| `linux/wgpu` | 5 | 1 | 4 | `event_sources`、`platform_view_plugins`、`transparent_titlebar`、`platform_attributes` |
| `windows/skia` | 3 | 3 | 0 | — 完整 |
| `windows/sun` | 3 | 2 | 1 | `event_sources` |
| `windows/wgpu` | 3 | 1 | 2 | `event_sources`、`platform_view_plugins` |

**合计：9 条线 7 条受损、19 处字段丢失。** 三条必须点明的结论：

1. **wgpu 线丢 `platform_view_plugins` = 整类功能不可用。** `platform_view_plugins` 是平台视图插件（WebView、原生地图等）的注入点；macos/wgpu、linux/wgpu、windows/wgpu 三条 wgpu 线全部丢失它，意味着在这些路径下平台视图插件整类功能不可用，而非「少一个选项」。
2. **没有任何一条渲染器线是系统性正确的。** `linux/skia` 也受损（丢 `transparent_titlebar`、`platform_attributes`），说明漂移不只发生在实验性/诊断性渲染器上，主线的 skia 桌面线同样不保真。不存在「至少某条线是完整基线」的假设。
3. **漂移是单向增长的。** `on_ready` / `min_window_size` 只在 `macos` 基座 + `macos/skia` 中存在，其余 8 条线从未拥有过——证明字段是在「基座先有、绑定包后抄且越抄越少」的过程中单向流失的，不做 M3 整体透传只会继续累积。

M3 的整体透传正是为一次性消除这 19 处丢失：绑定包不再镜像字段，也就无从丢字段。§6 的迁移路径以「19 处丢失归零」作为贯穿各阶段的机器验收门槛。

### 1.4 真问题 D2：注入点被复制 4 份

```
macos_backend.mbt:53    create_renderer : (@window_macos.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
linux_backend.mbt:59    create_renderer : (@window_linux.Window,  @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
windows_backend.mbt:53  create_renderer : (@win.Window,           @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
hosted_window_backend.mbt:33  create_renderer : (UInt64,          @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
```

四份结构完全同构（`create_renderer` + `sync_surface`/`sync` + `image_loader`），**唯一差异是第一个参数的窗口类型**。

`internal/embedded_runtime_backend` 的 `RendererProviderAdapter` 已经把窗口类型擦除成 `UInt64` —— 这说明「类型擦除以复用」的思路在仓库内已有先例，只是用了最粗暴的擦除方式（丢失类型安全）。MoonBit 的泛型 struct 能同时拿到复用与类型安全，仓库内已有验证过的先例：

```
moui/backend/platform_bridge/window_slot.mbt:27
pub struct WindowSlotMap[W, X] { mut slots : Array[WindowSlot[W, X]] }
pub fn[W, X] WindowSlotMap::new() -> WindowSlotMap[W, X] { { slots: [] } }
```

并且它已被 macOS 基座实际使用：`@platform_bridge.WindowSlotMap[@window_macos.Window, Unit]`（`macos_app_runtime.mbt:103`）。

**这是本方案核心机制 M1 的直接依据。**

### 1.5 真问题 D4：web / wechat 架构违例

```
moui/backend/web/moon.pkg:7      "wzzc-dev/moui/render/webgpu_adapter" @webgpu
moui/backend/wechat/moon.pkg:5   "wzzc-dev/moui/render/canvas2d"
```

- **web**：`backend/web` 同时扮演「平台基座」和「渲染器绑定包」两个角色——`webgpu_renderer.mbt` 整个文件（179 行）是绑定逻辑，`web_renderer_provider_bindings`（:57-86）本应属于独立绑定包。
- **wechat**：更严重。`backend/wechat/canvas` 子包已经是**正确的**绑定包（191 行，走完整协商，`wechat_canvas_provider.mbt:75`），但平台基座 `host_runtime.mbt` 绕过了它，直接持有具体渲染器类型：

```
moui/backend/wechat/host_runtime.mbt:12   mut renderer : @canvas2d.Canvas2DRenderer?
moui/backend/wechat/host_runtime.mbt:37   let r = @canvas2d.Canvas2DRenderer::new(canvas_id~)
```

实测该文件对 `r` 的全部用法只有 `r.resize(...)`（:38）、`r.text_system()`（:39）、`r.render(commands)`（:121）——**三个方法 `@render.HostWindowRenderer` 全部具备**。这是一个纯粹的历史遗留，修复成本极低。

### 1.6 附带发现：工厂签名与校验器都还是「闭合矩阵」

`create_*_provider` 的形状其实**已经统一**了：

```
create_skia_raster_provider(create_raster~  : (RendererSurfaceMetrics) -> SkiaRasterRenderer) -> RendererProvider   // skia/provider.mbt:9
create_sun_provider       (create_sun~     : (RendererSurfaceMetrics) -> SunRasterRenderer)  -> RendererProvider   // sun/provider.mbt:13
create_wgpu_provider      (create_wgpu~    : (RendererSurfaceMetrics) -> WgpuRenderer)       -> RendererProvider   // wgpu/provider.mbt:9
create_canvas2d_provider  (create_canvas2d~: (RendererSurfaceMetrics) -> Canvas2DRenderer)   -> RendererProvider   // canvas2d/provider.mbt:9
```

真正**不统一**的是 host binding 工厂：只有 skia 有 `create_skia_raster_host_binding` / `create_skia_hybrid_host_binding`（`skia/provider.mbt:53,77`），其余渲染器包一个都没有。所以非 skia 的绑定包要么手搓 `RendererProviderBinding::new`（web:69、wechat/canvas:99），要么干脆放弃协商（sun/wgpu 那 6 个包）。

更值得注意的是，`scripts/validate-renderer-provider-open-extension.mjs:132-146` 的 Check 2 里写着一张**硬编码的渲染器包与工厂名清单**：

```js
{ dir: "moui/render/skia", expected: ["create_skia_raster_provider", "create_skia_hybrid_provider"] },
{ dir: "moui/render/wgpu", expected: ["create_wgpu_provider"] },
{ dir: "moui/render/sun",  expected: ["create_sun_provider"] },
...
```

ADR 0019 宣称消灭了「中央矩阵」，但矩阵只是从 `moui/render` 迁移到了校验器脚本里。新增渲染器仍然要改这份清单——**开放扩展性没有真正闭环**。

**E8 达成了它的设计目标，但该目标本身不覆盖 D1。** Phase E 的 E8（`docs/plans/done/moui-architecture-convergence.md:111`）要求把 `validate-renderer-provider-open-extension.mjs` 切到 enforce，这一点已做到；其 `restrictedDirs = ["moui/core","moui/backend/host","moui/runtime"]`（`:99-101`）精确等于 ADR 0019 §Consequences（`docs/decisions/0007-renderer-and-skia.md:526-529`）指定的射程——守的是「core/host/runtime 不得分支渲染器身份」，且守住了。真正的缺口是：没有任何校验器检查绑定包是否走 `select_renderer_provider_binding`。D1 这条不变量**从未有过执行器**——不是门禁失效，是从来没建过这道门禁。附带两处配置事实（均非门禁失效）：

(a) **PREFIXES 是死配置**：`SELECTION_ALLOWLIST_PREFIXES`（`:65-83`）的 12 条绑定包前缀（`moui/backend/*/skia`、`moui/render` 等）全部落在 `restrictedDirs` 之外，永不可能被命中；末条 `"moui/render"` 是 catch-all，会吞掉前面所有 `moui/render/*` 条目，前面那些本身就是冗余。这部分随本方案顺手清理，不影响门禁有效性。

(b) **EXACT 是有效豁免，且是 M5 的验收抓手**：`SELECTION_ALLOWLIST_EXACT`（`:85-88`）含 `moui/backend/host/host_rendering_test.mbt`，说明校验器作者**明知** host 层有文件在直接消费 `NativeGpuPlatform`，于是主动登记例外——这不是疏忽。实测该文件 `:119-159` 共 6 处使用 `@render.NativeGpuPlatform::` / `@render.NativeRendererMode::`，其豁免随 M5 下沉后缩短（见 §3.5.2 M5 完成信号）。

本方案新增的 `validate-options-field-drift.mjs` 正是要补 D1 没有执行器的那道口子（options 字段透传完整性），而非另起炉灶。

---

## 2. 目标架构

### 2.1 分层图

```
+--------------------------------------------------------------------------+
| examples/<app>/<platform>_<renderer>/main.mbt        [链接单元选择点]      |
|   import backend/<platform>/<renderer>  <- 决定链接哪套 native-stub        |
+-----------------------------------|--------------------------------------+
                                    | 注入 HostRendererAdapter[W]
                                    v
+--------------------------------------------------------------------------+
| moui/backend/<platform>/<renderer>   [合成根 Composition Root]            |
|   职责: 平台句柄 <-> 渲染器 surface 的粘合 + binding 装配 + 协商           |
|   目标体量: 约 130 行(当前 341-1293)                                       |
+------------------|----------------------------------|--------------------+
                   | 调用标准工厂                      | 产出 adapter
                   v                                   v
+-------------------------------+   +--------------------------------------+
| moui/render/<renderer>        |   | moui/backend/<platform>  [平台基座]  |
|   渲染器实现                   |   |   事件循环/窗口/输入/服务             |
|   标准导出: create_*_provider  |   |   渲染器无关: 只认                   |
|   能力上报 / negotiate         |   |   HostRendererAdapter[Window]        |
|   [禁止] import 任何 backend   |   |   [禁止] import render/<renderer>    |
+---------------|---------------+   +------------------|-------------------+
                |                                      |
                v                                      v
+--------------------------------------------------------------------------+
| moui/render   [抽象 + 装配壳]                                             |
|   RendererProvider / RendererInstance / RendererProviderBinding           |
|   provider_shell (negotiate_*, new_provider_instance)                     |
|   [新增] HostRendererAdapter[W]                                           |
|   [新增] RendererProviderBinding::from_provider                           |
|   [禁止] import moui/backend/*  (含 host)                                 |
+-----------------------------------|--------------------------------------+
                                    v
+--------------------------------------------------------------------------+
| moui/backend/host [契约] | moui/backend/platform_bridge [中性变换]        |
+-----------------------------------|--------------------------------------+
                                    v
+--------------------------------------------------------------------------+
| moui/core   值类型 / 协议 (DrawFrame, Size, TextSystem)                   |
+--------------------------------------------------------------------------+
```

### 2.2 职责边界表

| 层 | 拥有什么 | 禁止什么 | 不变量依据 |
|----|----------|----------|------------|
| `moui/core` | 跨运行时协议与值类型 | 控件词汇、运行时、渲染器 | P3 |
| `moui/render` | provider 抽象、`RendererInstance`、`RendererProviderBinding`、`provider_shell`、**新增 `HostRendererAdapter[W]`**、**新增 `RendererProviderBinding::from_provider`** | import `moui/backend/*`（含 `host`）；出现任何具体渲染器分支；读取环境变量（本包 target 含 wasm） | P6；`render/moon.pkg` 现仅依赖 core/zeno/svg |
| `moui/render/<renderer>` | 渲染器实现、provider-ID、能力上报、`negotiate`、**标准工厂 `create_<r>_provider`**；native-only 包可持有本渲染器族的选择策略（如 skia 的 `MOUI_SKIA_RENDERER` 解析） | import 任何 `moui/backend/*`；感知平台窗口类型 | P6、R1、R7 |
| `moui/backend/host` | 主机服务契约（`HostSurfaceMetrics`、`PlatformViewPlugin`、`HostWindowRequestQueue`）；**新增 `HostSurfaceMetrics::normalized()`** | 具体平台行为；import `moui/render`（当前主 import 块无此依赖，须保持） | P5、ADR 0018 |
| `moui/backend/platform_bridge` | 中性生命周期/坐标变换、`WindowSlotMap[W, X]` | import `moui/render` | P10、ADR 0020 |
| `moui/backend/<platform>` | 事件循环、窗口创建、原生输入解码、平台服务；**注入点收敛为 `@render.HostRendererAdapter[Window]`** | import `moui/render/<renderer>`（web/wechat 当前违例，见 §4）；定义平台私有的 `<Platform>RendererProvider` | P5、P6、P10 |
| `moui/backend/<platform>/<renderer>`（合成根） | 平台句柄 → surface descriptor 的映射、`RendererProviderBinding` 装配与注册顺序（即 `auto` 策略）、平台特有的 present target 与 image loader、渲染器特有 options | 复制平台 `HostAppOptions` 字段；自定义 metrics 转换；重复实现 `MOUI_SKIA_RENDERER` 解析；跳过 `select_renderer_provider_binding` | P6、P12、R2、R3 |
| `examples/*/app` | 应用逻辑 | 依赖 `moui/runtime`、`moui/render/*`、具体 backend、provider | P9 |
| `examples/*/<platform>_<renderer>` | 入口装配（决定链接单元） | 应用逻辑 | P1、R3 |

### 2.3 对用户三个诉求的明确回答

**诉求一：引入统一的渲染器抽象接口或渲染器管理模块。**

抽象接口已存在（ADR 0019），**不新增**。需要补的是两个装配复用件，放入已有的 `moui/render`：

1. `HostRendererAdapter[W]` —— 统一注入点，替代 4 份 `<Platform>RendererProvider`。
2. `RendererProviderBinding::from_provider` —— 通用 host binding 派生，替代 skia 专有的 2 个 `create_*_host_binding`，并让 sun/wgpu/canvas2d/webgpu 无成本获得 binding 能力。

**不新建 `moui/render/composition` 包**，理由见 §3.6。

**诉求二：依赖注入还是工厂模式？**

两者分工已经正确，保留并强化：

| 角色 | 模式 | 谁提供 | 谁消费 |
|------|------|--------|--------|
| 渲染器实例创建 | 工厂 | `moui/render/<renderer>` 的 `create_<r>_provider` | 合成根 |
| 平台句柄 → 渲染器 | 依赖注入 | 合成根产出 `HostRendererAdapter[W]` | 平台基座 |
| 多渲染器优先级 | 注册顺序 + 协商 | 合成根决定 `[gpu_binding, raster_binding]` 顺序 | `select_renderer_provider_binding` |
| 链接单元选择 | 编译期 import | 入口 main 包 | moon 构建系统 |

关键点：**依赖注入的方向必须是「合成根 → 平台基座」，绝不能反向**。当前 macOS/Linux/Windows 已经是对的，web/wechat 是反的（§4 修复）。

**诉求三：新增后端时无需改动渲染器引入逻辑。**

达成路径：

- 平台基座只依赖 `@render.HostRendererAdapter[Window]`，其中 `W` 由平台自己填。新增平台 = 新增基座，`moui/render` 与 `moui/render/<renderer>` **零改动**。
- 新增渲染器 = 新增 `moui/render/<r>` 并导出 `create_<r>_provider`，`moui/backend/<platform>` **零改动**。
- 唯一的 O(P×R) 剩余项是合成根本身——这是**不可消除的本质复杂度**：Metal layer 安装、X11/Wayland surface、HWND、Vulkan window 各自不同，`checks/platform-adapter-duplication-baseline.json` 已把「Texture native surface creation」「Discrete GPU enumeration and Metal/Vulkan/EGL device setup」列为 `allowUntil: null` 的永久豁免，本方案与该判断一致。

本方案能做到的是**把合成根压缩到只剩本质复杂度**：约 130 行 vs 当前 341-1293 行。

**E7 定义了验收形式却从未实现，本方案 Phase 5 补上。** Phase E 的 E7（`docs/plans/done/moui-architecture-convergence.md:108-110`）定义了「新增渲染器只加一个包 + 一行注册即挂上、不改 core/host/runtime」的机器验收形式，但全仓实测**不存在任何 throwaway / 测试用 provider 包**（`moui/` 下 grep 无命中，仅有 `.openseek/sessions/*.jsonl` 聊天日志误中），该测试从未落地；ADR 0019 §Consequences（`:521-523`）要求的 skia/wgpu 共享契约测试套件同样缺席（两侧 `*test*.mbt` 无一引用 `provider_contract`）。因此「渲染器选择」维度的开放扩展属性**本应由 E7 守护却无人值守**，「平台选项透传」维度则连验收形式都没定义过——两个维度目前都是无人值守。本方案 **Phase 5 补上这两项实现**——落地 throwaway provider 包 + 共享契约测试套件，用「加 1 包 + 1 行注册即挂上、core/host/runtime 零改动」来机器证明用户第三诉求。M1 的泛型注入点 + M3 整体透传是让该测试**能够通过**的结构前提（而非「让既有测试真实通过」——因为该测试本就不存在）。

---

## 3. 核心机制设计（MoonBit 代码示意）

以下代码遵循仓库已验证的 MoonBit 事实：struct + 函数字段手写 vtable（无 blanket impl）、`pub struct` + `priv` 字段、`pub fn[T]` 泛型函数、struct spread `{ ..x, f: v }`、可选参数 `x? : T = default`、命名参数 `a~`。

### 3.1 M1：泛型 `HostRendererAdapter[W]`（消灭 4 份注入点复制）

新增文件 `moui/render/host_adapter.mbt`。**关键设计点：metrics 用 `RendererSurfaceMetrics`（`moui/render` 自有类型）而非 `@host.HostSurfaceMetrics`**，这样 `moui/render` 不需要 import `moui/backend/host`，保住现有分层（`render/moon.pkg` 当前只依赖 core/zeno/svg）。

```moonbit
///|
/// Renderer-agnostic host injection point. `W` is the platform window handle
/// type (`@window_macos.Window`, `@window_linux.Window`, `UInt64` for embedded
/// runtimes). `moui/render` never names `W`, so this contract stays free of
/// any window, platform, or host dependency.
///
/// Replaces the per-platform `MacosRendererProvider` / `LinuxRendererProvider`
/// / `WindowsRendererProvider` / `RendererProviderAdapter` copies.
pub struct HostRendererAdapter[W] {
  priv create_renderer : (W, RendererSurfaceMetrics) -> HostWindowRenderer?
  priv sync_surface : (W, RendererSurfaceMetrics) -> Unit
  priv image_loader : HostAsyncImageLoader?
}

///|
pub fn[W] HostRendererAdapter::new(
  create_renderer~ : (W, RendererSurfaceMetrics) -> HostWindowRenderer?,
  sync_surface? : (W, RendererSurfaceMetrics) -> Unit = (_window, _metrics) => (),
  image_loader? : HostAsyncImageLoader? = None,
) -> HostRendererAdapter[W] {
  { create_renderer, sync_surface, image_loader }
}

///|
pub fn[W] HostRendererAdapter::create(
  self : HostRendererAdapter[W],
  window : W,
  metrics : RendererSurfaceMetrics,
) -> HostWindowRenderer? {
  (self.create_renderer)(window, metrics)
}

///|
pub fn[W] HostRendererAdapter::sync(
  self : HostRendererAdapter[W],
  window : W,
  metrics : RendererSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(window, metrics)
}

///|
/// Named `async_image_loader` rather than `image_loader` to keep the accessor
/// unambiguous against the private field of the same name.
pub fn[W] HostRendererAdapter::async_image_loader(
  self : HostRendererAdapter[W],
) -> HostAsyncImageLoader? {
  self.image_loader
}
```

平台基座改造（`moui/backend/macos/macos_app_runtime.mbt`）：

```moonbit
///|
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @runtime.AppRuntime,
  provider~ : @render.HostRendererAdapter[@window_macos.Window],
  options? : MacosHostAppOptions = MacosHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  // ... 其余逻辑不变，provider.image_loader 改为 provider.async_image_loader()
}
```

`MacosRendererProvider` 在迁移期保留为 3 行 shim，Phase 4 删除：

```moonbit
///|
/// Deprecated: use `@render.HostRendererAdapter[@window_macos.Window]`.
/// Kept for one release so downstream entrypoints migrate incrementally.
pub fn MacosRendererProvider::new(
  create_renderer~ : (@window_macos.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit = (_w, _m) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> @render.HostRendererAdapter[@window_macos.Window] {
  @render.HostRendererAdapter::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, host_metrics_from_renderer(metrics))
    },
    sync_surface=(window, metrics) => {
      sync_surface(window, host_metrics_from_renderer(metrics))
    },
    image_loader~,
  )
}
```

[RISK] MoonBit 的 `typealias` 语法在本仓库无任何使用先例（全仓 grep `typealias` 零命中），因此本方案**不依赖 typealias**，直接在签名中书写 `@render.HostRendererAdapter[@window_macos.Window]`。若后续验证 `pub typealias` 可用，可作为纯美化步骤单独提交。

### 3.2 M2：通用 host binding 派生（统一渲染器包导出契约）

在 `moui/render/provider_contract.mbt` 追加。这段代码把 `skia/provider.mbt:53-96` 里两份重复的 rewiring 逻辑提取为一份通用实现：

```moonbit
///|
/// Derive a host-facing binding from any `RendererProvider`. The binding
/// rewires the provider's `create` so the `RendererInstance` contract stays
/// truthful for diagnostics and isolated provider tests, while production
/// hosts build the richer `HostWindowRenderer` through `create_host_renderer`.
///
/// This replaces per-renderer `create_*_host_binding` factories. It introduces
/// no new provider ID and no new capability surface, so it is P11
/// shrink-or-stay compliant.
pub fn RendererProviderBinding::from_provider(
  provider : RendererProvider,
  create_host_renderer : (RendererSurfaceMetrics, BoundSurface) -> HostWindowRenderer,
) -> RendererProviderBinding {
  let host_provider = {
    ..provider,
    create: (metrics, bound) => RendererInstance::from_host_window_renderer(
      create_host_renderer(metrics, bound),
    ),
  }
  { provider: host_provider, create_host_renderer }
}
```

**渲染器包导出契约（新规范）**：每个 `moui/render/<r>` 只需导出

```
pub fn create_<r>_provider(create_<r>~ : (RendererSurfaceMetrics) -> <R>Renderer) -> RendererProvider
```

host binding 由合成根统一派生，渲染器包**不再需要**任何 `create_*_host_binding`：

```moonbit
// 合成根内，对任意渲染器同构：
let binding = @render.RendererProviderBinding::from_provider(
  @skia_renderer.create_skia_hybrid_provider(create_hybrid=make_hybrid),
  (metrics, bound) => host_renderer_from_skia(make_hybrid(metrics), bound),
)
```

收益：
- 删除 `create_skia_raster_host_binding` + `create_skia_hybrid_host_binding`（约 44 行）
- sun / wgpu / canvas2d / webgpu_adapter **零改动**即获得 binding 能力 —— 这是让那 6 个绕过协商的包能够低成本归队的前提
- 校验器 Check 2 的硬编码清单可简化为一条统一规则：`moui/render/<dir>` 必须存在 `create_<dir>_provider`（`webgpu_adapter` 需保留别名映射）

### 3.3 M3：消灭 `<Platform><Renderer>AppOptions` 逐字段拷贝

**关键洞察：当前绑定包必须镜像字段，唯一原因是它要「拆开再组装」。只要改成整体透传，就完全不需要访问字段——`pub struct` + `priv` 字段的透传是合法的。** 这一点决定了改造成本极低。

改造前（`macos/sun/macos_sun_provider.mbt:2-73`，约 72 行）：

```moonbit
pub struct MacosSunAppOptions {
  priv scene_resolver : @runtime.HostWindowSceneResolver
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
  priv on_ready : (() -> Unit)?
  priv min_window_size : @dpi.LogicalSize?
}
// ... MacosSunAppOptions::new 的 6 个可选参数 ...
pub fn run_app_with_options(title, runtime, options~, window_requests?) -> Unit {
  @macos_host.run_app_with_renderer_provider(
    title, runtime,
    provider=renderer_provider(options~),
    options=@macos_host.MacosHostAppOptions::new(
      scene_resolver=options.scene_resolver,          // 逐字段拆装
      platform_view_plugins=options.platform_view_plugins,
      transparent_titlebar=options.transparent_titlebar,
      platform_attributes=options.platform_attributes,
      on_ready=options.on_ready,
      min_window_size=options.min_window_size,
    ),
    window_requests~,
  )
}
```

改造后（约 12 行，`MacosSunAppOptions` 与 `MacosSunSmokeOptions` 整体删除）：

```moonbit
///|
/// Sun has no renderer-specific options; the platform host options pass
/// through untouched. Field mirroring is gone because nothing reads fields.
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options? : @macos_host.MacosHostAppOptions = @macos_host.MacosHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @macos_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(),
    options~,
    window_requests~,
  )
}
```

对确有渲染器专属选项的 skia，拆成**正交的两个 options**，而不是镜像合并：

```moonbit
///|
/// Only the two fields that are genuinely Skia-specific. Platform host
/// options are passed through as `@macos_host.MacosHostAppOptions`.
pub struct MacosSkiaRendererOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @render.SkiaSurfaceRoute
}

///|
pub fn MacosSkiaRendererOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @render.SkiaSurfaceRoute = @skia_renderer.desktop_surface_route(
    platform=@render.NativeGpuPlatform::Macos,
    gpu_available=@skia_native.Surface::metal_gpu_context_runtime_available(),
    route_override_env="MOUI_MACOS_SKIA_SURFACE_ROUTE",
  ),
) -> MacosSkiaRendererOptions {
  { font_resolution, surface_route }
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options? : @macos_host.MacosHostAppOptions = @macos_host.MacosHostAppOptions::new(),
  renderer_options? : MacosSkiaRendererOptions = MacosSkiaRendererOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @macos_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options=renderer_options),
    options~,
    window_requests~,
  )
}
```

`MacosSkiaSmokeOptions`（9 字段，`macos_skia_provider.mbt:44-54`）整体删除，直接用 `@macos_host.MacosHostSmokeOptions` —— 它本来就是逐字拷贝，`MacosSkiaSmokeOptions::from_environment()` 移到 `@macos_host` 作为 `MacosHostSmokeOptions::from_environment()`，三个桌面平台共享。

**MoonBit 能帮到什么程度（诚实评估）**：
- [OK] 可选参数默认值：让透传入口无需为每个字段写样板
- [OK] `priv` 字段透传：整体传递不需要可见性，这是消除镜像的关键
- [OK] struct spread `{ ..options, field: v }`：若将来需要「透传并覆盖单个字段」，同包内可用
- [NG] **跨包无法用 spread 覆盖 `priv` 字段** —— 绑定包不能写 `{ ..host_options, on_ready: Some(f) }`。因此若合成根确实需要改写某个平台 option，必须由平台基座提供 `with_*` 方法。当前 12 个绑定包**没有任何一个**需要改写，所以这条限制在本次改造中不构成阻塞，但新增平台时需注意。
- [NG] MoonBit 无 `pub(crate)`，绑定包与平台基座之间无法共享「半公开」字段，透传是唯一干净解。

#### 3.3.1 入口侧迁移实测成本：0 个包必须改

M3 改造后，绑定包的 `run_app_with_options` 改为接收 `@macos_host.MacosHostAppOptions` 等平台基座 options（§3.3 改造后代码）。一个自然担忧是：46 个平台入口包的 `moon.pkg` 是否需要同步改写？实测结论——**不需要改任何入口包**，依据如下（项目总监门禁复盘实测，2026-08-02）：

1. **「入口包同时依赖基座包 + 绑定包」是既定实践，占比 57%，不是本方案引入的新耦合。** 46 个入口包中 26 个已同时 import 基座包与绑定包（showcase 全部 12 个、markdown_editor 6 个、pdf_workbench 3 个、excel 2 个、mo_desktop、mo_workbench 等）。例如 `examples/mo_desktop/macos_skia/moon.pkg:2-3` 同时含 `backend/macos/skia` 与 `backend/macos`，其 `main.mbt` 已在直接调用 `@macos_backend.macos_service_bridge()` / `macos_timer_source()`。新增的「入口引用基座包」只是沿用既有写法，且约束对象是薄入口包 `examples/<name>/<platform>_<renderer>`，不是 app 主体 `examples/<name>/app`（P9 不受影响）。
2. **剩余 20 个只 import 绑定包的入口包走简化路径、零改动。** counter、agent_counter、webview_demo、multi_window、code_editor、design_systems、button_freeze_probe 等只 import 绑定包，调用其简化 `run_app()` 入口、不传 options。M3 后 `options?` 仍是带默认值的可选参数，这些包的调用签名不变。
3. **综上 M3 入口侧迁移成本实测为 0 个包必须改**，可作为 §5 迁移成本一栏的量化依据——本方案不引入「用户须重写入口」的破坏面。

### 3.4 M4：metrics 转换归位（消灭 12 份 `renderer_metrics_from_host`）

因 M1 已把 adapter 的 metrics 类型定为 `RendererSurfaceMetrics`，转换职责自然上移到**平台基座**（每平台一次，共 4 处），12 个绑定包里的 `renderer_metrics_from_host` 全部删除。

归一化逻辑（scale <= 0 回落 1.0、physical == 0 由 logical × scale 推导）下沉到 `moui/backend/host`：

```moonbit
///|
/// Normalize degenerate surface metrics once, so every platform base and
/// renderer binding stops re-deriving the same fallbacks.
pub fn HostSurfaceMetrics::normalized(
  self : HostSurfaceMetrics,
) -> HostSurfaceMetrics {
  let scale_factor = if self.scale_factor > 0.0 { self.scale_factor } else { 1.0 }
  let width = if self.physical_size.width > 0.0 {
    self.physical_size.width
  } else {
    self.logical_size.width * scale_factor
  }
  let height = if self.physical_size.height > 0.0 {
    self.physical_size.height
  } else {
    self.logical_size.height * scale_factor
  }
  HostSurfaceMetrics::new(
    logical_size=self.logical_size,
    physical_size=@core.Size::new(width~, height~),
    scale_factor~,
  )
}
```

平台基座里一次性转换：

```moonbit
///|
fn renderer_metrics(metrics : @host.HostSurfaceMetrics) -> @render.RendererSurfaceMetrics {
  let m = metrics.normalized()
  @render.RendererSurfaceMetrics::new(
    logical_size=m.logical_size,
    physical_size=m.physical_size,
    scale_factor=m.scale_factor,
  )
}
```

### 3.5 M5：`--renderer` / `MOUI_SKIA_RENDERER` 收敛到一处

当前三份拷贝：`macos/skia:82-105`、`linux/skia:34`、`windows/skia:45`。

收敛目标包选择：**`moui/render/skia`**，理由有三：

1. 它是 native-only（`render/skia/moon.pkg:16 supported_targets = "native"`），可安全承载 Skia 族专有的「字符串 → `NativeRendererMode` → `SkiaSurfaceRoute`」解析决策（见 §3.5.3）；`moui/render` 是 `+native+wasm-gc+wasm`，**不能**放那里。按 B5 边界，env 读取点（`@env.get_env_var("MOUI_SKIA_RENDERER")`）留在各平台 provider，不下沉到此处。
2. 它**已经** import `moonbitlang/core/env`（`render/skia/moon.pkg:5`），零新增依赖，不触发 A2。
3. `SkiaSurfaceRoute` 与 `NativeRendererMode` 都是 Skia 族概念，R2/R3 也只约束 Skia 路径。放这里语义正确，且不会把 Skia 策略泄漏给 sun/wgpu。

```moonbit
// moui/render/skia/desktop_selection.mbt  (下沉：仅「mode -> route」决策逻辑)
///|
/// Skia-only decision helper: maps a resolved `NativeRendererMode` to a
/// `SkiaSurfaceRoute`. It does NOT read env (B5 边界：env 读取点留在 provider).
pub fn[P : @render.NativePlatformSurface] desktop_surface_route(
  platform~ : P,
  gpu_available~ : Bool,
  requested~ : @render.NativeRendererMode,
) -> @render.SkiaSurfaceRoute {
  @render.resolve_surface_route(
    platform,
    requested,
    gpu_available~,
    gpu_promoted=@render.NativePlatformSurface::gpu_promoted(platform),
  )
}
```

各平台 skia provider 读取 env 并解析后调用它（env 读取点在 provider，满足 R3 `has_env` 硬依赖；调用 `resolve_surface_route` 满足 R3 `has_parse` 的 OR 分支）：

```moonbit
// moui/backend/<platform>/skia/*_provider.mbt
fn select_route(platform~ : P, gpu_available~ : Bool) -> @render.SkiaSurfaceRoute {
  let requested = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) =>
      @render.NativeRendererMode::parse(value).unwrap_or(@render.NativeRendererMode::Auto)
    None => @render.NativeRendererMode::Auto
  }
  @render.resolve_surface_route(platform, requested, gpu_available~)  // has_parse OR 分支
}
```

签名依据实测的 `pub fn[P : NativePlatformSurface] resolve_surface_route(P, NativeRendererMode, gpu_available~ : Bool, gpu_promoted~ : Bool) -> SkiaSurfaceRoute`（`moui/render/pkg.generated.mbti:92`）。

三个桌面 skia 绑定包各自退化为一行调用（示例见 §3.3 的 `MacosSkiaRendererOptions::new` 默认值）。

[RISK] **这不会打破 R3 校验器，前提是遵守 B5 边界。** `tools/moui/validate_harness_invariants/main.mbt:433-457` 中 `has_env = body.contains("MOUI_SKIA_RENDERER")` 是**硬条件**，`has_parse = body.contains("NativeRendererMode::parse") || body.contains("resolve_surface_route")` 是 OR。按 B5 边界，env 读取点留在各平台 skia provider（其函数体含 `MOUI_SKIA_RENDERER` 字面量，`has_env` 为真），provider 直接调用 `resolve_surface_route`（`has_parse` 的 OR 分支为真），R3 自然通过——**R3 校验器无需任何放宽**。早期草稿曾提议把 `has_env` 放宽为「含 `desktop_surface_route` 调用」，那会掩盖 env 读取被误下沉的回归，已撤销。

### 3.5.1 `native_gpu_selection.mbt` 混装根因与拆分（ADR 0019 §Consequences 第 1 条未执行的根）

> `native_gpu_selection.mbt` 应删未删的根因是**混装了两类性质相反的东西**：`GpuHostSurfaceDescriptor` 是必须留在中立层的跨渲染器契约载荷，`NativeGpuPlatform`/`NativeRendererMode`/`gpu_promoted` 是应下沉 skia 族的中央策略矩阵。ADR 0019 §Consequences 第 1 条（`:516-517`）要求「删除该文件」，但整文件删不掉（一删就废掉契约载荷），于是整个留下。这是删除类 ADR 条款执行不下去的典型模式——**条款粒度是文件，而文件内耦合了不同生命周期的东西**。M5 的动作不是「删文件」，是「按职责一分为二」：契约载荷留 `moui/render`（可考虑更名为 `gpu_surface_descriptor.mbt` 以正名），策略矩阵迁 `moui/render/skia`。

拆分边界（全量消费者实测）：

**必须留在 `moui/render`（跨渲染器契约载荷）—— `GpuHostSurfaceDescriptor`**
- `provider_contract.mbt:9` 作为 `SurfaceDescriptor::GpuSurface` 载荷、`:220` 构造参数
- `provider_shell.mbt:91` `route_for~ : (GpuHostSurfaceDescriptor) -> SkiaSurfaceRoute` 字段签名
- 5 个平台 skia provider 的构造器调用（macos:483 / linux:316 / windows:326 / android:117 / ios:136）
- `render/skia/provider.mbt:191-202` 模式匹配
- 它是中立层的 surface 句柄载荷，**不能动**。

**应下沉 skia 族 —— `NativeGpuPlatform` / `NativeRendererMode` / `gpu_promoted`**
- `native_gpu_selection.mbt:10,24`（enum 定义）、`:99-130`（`NativePlatformSurface for NativeGpuPlatform` impl）、`:140` parse、`:150` label
- `native_platform_surface.mbt:14,21,22,28` —— **残留耦合的确切位置**：该文件是 ADR 0019 的开放扩展点，`resolve_surface_route` 已泛型化为 `pub fn[P : NativePlatformSurface](P, NativeRendererMode, ...)`，但第二个参数**仍硬依赖 `NativeRendererMode` 这个具体 enum**。泛型化做了一半：平台维度开放了，渲染器模式维度没开放。
- `render/skia/hybrid_renderer.mbt:9,16,17,61`
- 3 个 desktop provider 的 parse 调用（macos:91 / linux:36 / windows:47）
- `backend/host/host_rendering_test.mbt:119-159`（见 §3.5.2 / B1(b)）

> 顺带：`native_platform_surface.mbt:11` 那句注释「`NativeGpuPlatform` can reuse this logic without editing a central matrix」值得引用——它证明 ADR 0019 的意图确实是消灭中央矩阵，而 enum 本身留在中立层就是矩阵没消灭干净的残迹。

### 3.5.2 M5 完成信号（E8 EXACT 豁免缩短 = 不变量棘轮 shrink-or-stay 实证）

`NativeGpuPlatform` / `NativeRendererMode` 下沉 skia 族后，`SELECTION_ALLOWLIST_EXACT`（`validate-renderer-provider-open-extension.mjs:85-88`）中 `"moui/backend/host/host_rendering_test.mbt"` 一行可被删除且 `validate-renderer-provider-open-extension.mjs` 仍通过。豁免名单缩短 = 不变量棘轮 shrink-or-stay 的实证，正好接上 P11「provider 预算只减不增」的口径。

### 3.5.3 M5 与 R3 校验器的硬边界（B5）

**边界**：env 变量名与 `get_env("MOUI_SKIA_RENDERER")` 读取点**保留在各平台 skia provider**（R3 校验器 `has_env` 硬依赖）；下沉到 skia 族的只是「字符串 → `NativeRendererMode` → `SkiaSurfaceRoute`」的解析与决策逻辑。provider 侧改为调用 `resolve_surface_route`，满足 R3 的 `has_parse` OR 分支。

- `has_parse` 是 OR——M5 把 `NativeRendererMode::parse` 下沉走之后，只要 desktop skia provider 文件体里仍出现 `resolve_surface_route`，R3 依然通过。**M5 有安全通道，不会被 R3 卡死。**
- `has_env` 是硬条件——`MOUI_SKIA_RENDERER` 字面量必须**留在 provider 文件里**。M5 如果把 env 读取一起下沉到 skia 包，R3 立即 fail。

### 3.6 关于是否新建 `moui/render/composition` 包

**结论：不新建。** 决策依据：

| 维度 | 放入已有 `moui/render` | 新建 `moui/render/composition` |
|------|------------------------|-------------------------------|
| 依赖隔离收益 | `moui/render` 现仅依赖 core/zeno/svg，本身已是最干净层；新增件不引入任何依赖 | 无额外隔离收益 |
| A2 成本 | 0（无新 `@pkg` 前缀） | 需为 12+ 个 `moon.pkg` 增加 import 与前缀 |
| P6 影响 | `RendererProviderBinding` 本就在 `moui/render`，`from_provider` 与之同址，边界不变 | 装配契约与 binding 定义分家，P6 表述需改写 |
| P11 影响 | 预算校验器只看 `moui/render/provider_contract.mbt`（`validate-renderer-provider-open-extension.mjs:200-212`），无需改动 | 校验器需新增扫描路径 |
| API surface | `checks/api-surface-report.json` 增量最小 | 新包整体进入 API surface |
| 环境变量读取 | `moui/render` 含 wasm target 无法承载 env 读取；实际 `@env.get_env_var("MOUI_SKIA_RENDERER")` 位于 `moui/backend/{macos,linux,windows}/skia/*_provider.mbt`（R3 硬扫这三个路径，见 `validate_harness_invariants/main.mbt:67-72`），**必须留在原处**；下沉到 native-only 的 `moui/render/skia` 的只有「字符串 → mode → route」解析决策（见 §3.5.3） | 若设为 native-only 则不能服务 web/wechat，需再拆包 |

新建包的唯一潜在理由是「隔离 native-only 的选择逻辑」，而这个需求已由 native-only 的 `moui/render/skia` 完美满足（§3.5）。为零收益付出 A2 + 校验器 + API surface 三重成本不划算。

**P6 措辞需微调**（不改语义）：现表述「平台合成根拥有 `RendererProviderBinding` 装配」仍然成立；建议补一句「`moui/render` 可提供与渲染器无关的装配壳（`provider_shell`、`HostRendererAdapter`、`RendererProviderBinding::from_provider`），合成根仍是唯一决定注册顺序与平台句柄映射的地方」。

**P11 评估**：M1/M2/M4/M5 全部**不新增任何 provider ID，不扩大能力表面**。`HostRendererAdapter[W]` 是注入容器不是 provider；`from_provider` 复用入参 provider 的 id 与 descriptor。按 shrink-or-stay 判定为 **stay**（`create_*_host_binding` 的删除实际是 shrink），**不触发 RFC allowlist**。这是本方案能小步落地的关键前提。

---

## 4. web / wechat 违例修复方案

### 4.1 wechat（低成本，优先做）

问题：`backend/wechat/host_runtime.mbt:12,37` 直接持有 `@canvas2d.Canvas2DRenderer`，绕过已存在且正确的 `backend/wechat/canvas` 绑定包。

修复：状态字段改为渲染器无关类型，构造函数由调用方注入。

```moonbit
// moui/backend/wechat/host_runtime.mbt
///|
priv struct WechatState {
  mut driver : @runtime.HostRuntimeDriver?
  mut renderer : @render.HostWindowRenderer?   // was @canvas2d.Canvas2DRenderer?
  mut needs_render : Bool
}

///|
/// The renderer factory is injected by the mini-program entrypoint, which
/// already links `backend/wechat/canvas`. `backend/wechat` itself no longer
/// names a concrete renderer.
pub fn run_app(
  canvas_id~ : String,
  runtime~ : @runtime.AppRuntime,
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 2.0,
  create_renderer~ : (String, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer,
) -> Unit {
  let d = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let host_metrics = @host.HostSurfaceMetrics::new(
    logical_size=@core.Size::new(width=logical_width, height=logical_height),
    physical_size=@core.Size::new(
      width=logical_width * scale_factor,
      height=logical_height * scale_factor,
    ),
    scale_factor~,
  ).normalized()
  let r = create_renderer(canvas_id, host_metrics)
  r.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=host_metrics.logical_size,
      physical_size=host_metrics.physical_size,
      scale_factor=host_metrics.scale_factor,
    ),
  )
  d.set_text_system(r.text_system())
  state.driver = Some(d)
  state.renderer = Some(r)
  state.needs_render = true
  wechat_render_frame()
}
```

可行性已实测：`host_runtime.mbt` 对渲染器的全部调用只有 `resize`（:38）、`text_system()`（:39）、`render(commands)`（:121），`@render.HostWindowRenderer` 三者皆有。

入口侧一行接线：

```moonbit
@wechat_host.run_app(
  canvas_id~, runtime~, logical_width~, logical_height~,
  create_renderer=(id, metrics) => @wechat_canvas.wechat_canvas_create_renderer(canvas_id=id, metrics~),
)
```

`backend/wechat/moon.pkg` 删除 `"wzzc-dev/moui/render/canvas2d"`。

### 4.2 web（中等成本）

问题：`backend/web` 同时是平台基座与渲染器绑定包。`webgpu_renderer.mbt`（179 行）整体属于绑定层。

修复：新建 `moui/backend/web/webgpu` 绑定包，与 `backend/wechat/canvas` 对称。

- 迁出到 `moui/backend/web/webgpu`：`WebRenderer::create`（:23-50）、`web_renderer_provider_bindings`（:57-86）、`host_renderer_from_webgpu`（:158-176）、`webgpu_renderer_backend_info`（:10）、`webgpu_canvas_surface_contract`（:15）、`WebRendererError`（:2）
- 留在 `backend/web`：`WebRenderer` 包装结构（:5-7）及其转发方法（`resize`/`render`/`render_frame`/`text_system`/`image_*`/`dispose`，:96-155）—— 它们只操作 `@render.HostWindowRenderer`，已是渲染器无关的
- 新增注入构造：

```moonbit
// moui/backend/web (平台基座保留)
///|
pub fn WebRenderer::from_host_renderer(
  host_renderer : @render.HostWindowRenderer,
) -> WebRenderer {
  { host_renderer, }
}
```

- `backend/web/moon.pkg` 删除 `"wzzc-dev/moui/render/webgpu_adapter" @webgpu`
- 浏览器入口改为 import `moui/backend/web/webgpu`，与 `examples/*/macos_skia` 的模式一致

[RISK] `backend/web` 的 `link.wasm-gc.exports` 列出 8 个导出符号。若被迁出的代码触及这些导出，需确认导出仍从 `backend/web` 解析。实测这 8 个符号均为 `web_dispatch_*` / `web_complete_async_*` 事件与异步回调，与渲染器构造无关，风险低。Phase 3 需以 `moon check moui/backend/web --target wasm-gc` 实测确认。

### 4.3 修复后的一致性

三类平台的模式将完全统一：

| 平台 | 平台基座 | 绑定包 | 注入类型 |
|------|----------|--------|----------|
| macos/linux/windows | `backend/<p>` | `backend/<p>/{skia,sun,wgpu}` | `HostRendererAdapter[@window_<p>.Window]` |
| ios/android/harmonyos | `backend/<p>` + `internal/embedded_runtime_backend` | `backend/<p>/skia` | `HostRendererAdapter[UInt64]` |
| web | `backend/web` | `backend/web/webgpu`（新） | `HostRendererAdapter[String]`（canvas id） |
| wechat | `backend/wechat` | `backend/wechat/canvas`（已存在） | 注入 `create_renderer` 闭包 |

---

## 5. 方案对比矩阵

| 维度 | A. 保持 P×R 包 + 抽公共壳 | B. 平台包内多 provider 注册 + 特性开关 | C. 独立 `moui/render/composition` 层 | **D. 收敛装配壳 + 泛型注入点（推荐）** |
|------|---------------------------|----------------------------------------|--------------------------------------|------------------------------------------|
| 包数量变化 | 0 | -10（13 → 3） | +1 | +1（`backend/web/webgpu`），13 绑定包保留 |
| 样板削减估算 | 约 350 行（仅 metrics + 部分 options） | 理论最大，但不可实现 | 约 400 行 | **约 830-900 行**；单个绑定包 341-1293 → 约 130 |
| 新增 (P,R) 组合边际成本 | 约 300 行 | N/A | 约 250 行 | **约 130 行** |
| 消除 D1（抽象可绕过） | 否 | 是 | 部分 | **是**（`from_provider` 使协商成为零成本默认路径） |
| 消除 D2（4 份注入点） | 否 | 是 | 否 | **是**（`HostRendererAdapter[W]`） |
| 修复 D4（web/wechat） | 独立处理 | 独立处理 | 独立处理 | **纳入方案（§4）** |
| P6 影响 | 无 | **违反**（渲染器实现选择逻辑渗入平台包） | 需改写边界表述 | 措辞微调，语义不变 |
| P11 影响 | stay | **增长，需 RFC** | stay | **stay，不触发 RFC** |
| P12 影响 | 略改善 | 不可评估 | 略改善 | **改善**（重复度单调下降，符合 shrink-or-stay） |
| MoonBit 可实现性 | 高 | **不可实现** | 高 | **高**（依赖已验证的 `WindowSlotMap[W,X]` 泛型模式） |
| 链接期开销 | 不变（保持一包一链接单元） | **致命：无法条件排除 native-stub** | 不变 | **不变**（编译期选择机制原样保留） |
| 迁移成本 | 低 | 不适用 | 中 | 中（可分 5 阶段，每阶段独立可回滚） |
| 校验器改动 | 无 | 大量 | 中 | 小（1 处简化：Check 2 随 `from_provider` 收敛；R3 无需改动） |

### 5.1 为什么否决方案 B（必须正面回答的链接期约束）

方案 B 的设想是：把 `backend/macos/{skia,sun,wgpu}` 合并进 `backend/macos`，用特性开关在运行时或构建时选择渲染器。**在 MoonBit 构建模型下不可实现**，证据链：

1. `moon.pkg` 的 `options(targets: {...})` 只能按 **target** 门控文件。实测语法形如 `targets: { "error.mbt": [ "native" ], "os_error_test.mbt": [ "native" ] }`（`checks/external-consumer/.mooncakes/moonbitlang/async/src/os_error/moon.pkg:14`）。合法取值是 native/wasm/wasm-gc/js，**没有自定义特性开关维度**。
2. `import { ... }` 块无任何条件语法。一旦 `backend/macos` 同时 import `render/skia` 与 `render/wgpu`，两者的依赖即无条件进入链接图。
3. 各绑定包携带互斥的原生链接配置，同时链接不可行：
   - `macos/skia/moon.pkg`：`stub-cc-flags: ${build.MOUI_SKIA_STUB_CC_FLAGS}`
   - `macos/wgpu/moon.pkg`：`native-stub: ["macos_wgpu_surface_host.m"]`，`cc-link-flags` 含 `-framework CoreText -framework Foundation`，并依赖 `Milky2018/wgpu_mbt/c`
   - `macos/sun/moon.pkg`：依赖 `wzzc-dev/moui_sun/softbuffer`，`cc-link-flags` 含 `-framework WebKit`
4. 同一个二进制不可能同时链接 skia + wgpu + sun 的全部 native 依赖——这既是构建约束，也与 R1（skia 主线、wgpu 仅诊断）、R7（sun 不上默认合成根）的产品定位冲突。

**因此「一个 (platform, renderer) 组合 = 一个包 = 一个链接单元」是 MoonBit 构建模型下的必然结论，不是历史包袱。** 方案 D 接受这一约束，只压缩每个链接单元的体量，不试图消灭链接单元本身。这也正是「编译期选择如何保留」的答案：**选择点就是入口 main 包的那一行 import，本方案完全不动它。**

### 5.2 推荐理由

方案 D 是唯一同时满足以下四条的方案：

1. 消除四个真问题（D1/D2/D3/D4）中的全部四个
2. 不触发 P11 RFC 棘轮（无新 provider ID、无能力表面增长）
3. 不破坏 MoonBit 链接期选择机制
4. 可拆成 5 个独立可验证、独立可回滚的阶段

---

## 6. 分阶段迁移路径

每阶段独立可编译、可验证、可回滚。**任一阶段失败即在该阶段回滚，不影响已合入的前序阶段。**

**前置依赖（关键排序）**：本方案的 Phase 1 **不得先于** `validation-hygiene-cleanup` 计划（active，Phase 2 执行中，用户 2026-08-03 决策，`docs/plans/active/validation-hygiene-cleanup.md`）的 **Phase 2** 落地——否则会抢改 `checks/profiles.json` 与 `moui-runtime-gates.yml`，与该计划 Phase 2（:85-86）的同一批文件冲突。该计划 Phase 4/5（:89-92）将新增两个行为校验器 `validate_renderer_capability_consistency` 与 `validate_doc_references`。

**`validate-options-field-drift.mjs` 的挂靠方式**：作为 `validation-hygiene-cleanup` 的增补项接入，不独立成「自测型」校验器，避免将来被误当 validator 自测连坐删除。遵守其验收口径第 3 条（:100-101）「接入 pr profile 并带规格测试」：
- 规格测试 fixture：`fixtures/options-field-drift/lost/` 含已知丢字段的绑定包快照，断言 **fail**；`fixtures/options-field-drift/intact/` 含完整透传的绑定包快照，断言 **pass**；迁移中随阶段从红转绿。
- 接入 `checks/profiles.json` 的 `pr` profile（待该计划 Phase 2 完成同一文件后再追加，避免冲突）。

**与 `validate_renderer_capability_consistency`（Phase 4）的关系——正交，不合并**：前者校验「options 字段透传完整性」（D3 能力丢失维度），后者校验「代码自报 vs renderer-capability-report.md 的能力一致性」（E8 延伸维度）。两者输入不同、失败模式不同，合并会模糊责任边界；保留为两个独立校验器，但共用 `validation-hygiene-cleanup` 的 pr profile 接入与规格测试范式。

### Phase 1：装配壳落地（纯新增，零破坏）

产出：
- `moui/render/host_adapter.mbt`：`HostRendererAdapter[W]` + 4 个方法（M1）
- `moui/render/provider_contract.mbt` 追加 `RendererProviderBinding::from_provider`（M2）
- `moui/backend/host` 追加 `HostSurfaceMetrics::normalized()`（M4）
- `moui/render/skia/desktop_selection.mbt`：`desktop_surface_route`（M5）
- `scripts/validate-options-field-drift.mjs`（**新增**）：抽取各 `<Platform>HostAppOptions` 的字段集与对应绑定包实际透传字段做差集，非空即 fail。这是 §1.6「闭合矩阵」问题的解药——比对是**推导**出来的，不是硬编码渲染器→工厂列表

本阶段**不修改任何调用方**，纯增量。

验证：
```
moon check moui/render
moon check moui/render/skia
moon check moui/backend/host
moon test moui/render --target native
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-options-field-drift.mjs   # 基线测量，预期 19（本阶段仅建立基线，不改绑定包）
```

回滚点：删除 4 个新增/追加片段即可，无调用方依赖。

### Phase 2：单平台单渲染器试点（macos/sun）

选 `macos/sun` 而非 `macos/skia` 试点，理由：它是 R7 实验性渲染器，不在产品 `auto` 路径上，出问题不影响主线；且它是「绕过协商」的典型（D1），能一次验证 M1+M2+M3 三个机制。

产出：
- `backend/macos` 注入点切换到 `@render.HostRendererAdapter[@window_macos.Window]`，`MacosRendererProvider::new` 保留为 shim（§3.1）
- `backend/macos` 内置 `renderer_metrics` 转换（M4）
- `macos/sun` 删除 `MacosSunAppOptions` / `MacosSunSmokeOptions` / `renderer_metrics_from_host`，改为透传（M3）
- `macos/sun` 改用 `@sun_renderer.create_sun_provider` + `RendererProviderBinding::from_provider` + `select_renderer_provider_binding`，归队 ADR 0019（消除 D1）

预期：`macos/sun` 758 → 约 400 行。

验证：
```
moon check moui/backend/macos
moon check moui/backend/macos/sun
moon test moui/backend/macos --target native
MOUI_MACOS_SUN_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/macos_sun --target native
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-platform-adapter-duplication.mjs
node scripts/validate-options-field-drift.mjs   # 预期 18（macos/sun 的 event_sources 丢失已归零）
```

回滚点：`macos/sun` 与 `backend/macos` 的 diff 独立成一个 commit，`git revert` 即可；Phase 1 的新增件无害保留。

### Phase 3：web / wechat 违例修复

优先 wechat（成本最低，§4.1），再 web（§4.2）。两者互不依赖，可并行。

产出：
- `backend/wechat/host_runtime.mbt` 渲染器类型中性化；`wechat/moon.pkg` 删除 `render/canvas2d`
- 新建 `moui/backend/web/webgpu`；`backend/web` 保留中性包装；`web/moon.pkg` 删除 `render/webgpu_adapter`
- 相关入口接线更新

验证：
```
moon check moui/backend/wechat --target wasm-gc
moon check moui/backend/web --target wasm-gc
moon check moui/backend/web/webgpu --target wasm-gc
moon test moui/backend/wechat/canvas --target wasm-gc
node scripts/validate-host-import-baseline.mjs
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-options-field-drift.mjs   # 预期 18（web/wechat 不在本矩阵，D4 单独归零）
sh scripts/check.sh --profile pr
```

重点确认：`backend/web` 的 8 个 `wasm-gc` 导出符号仍可解析（§4.2 [RISK]）。

回滚点：wechat 与 web 各自独立 commit。

### Phase 4：桌面 skia 三平台收敛 + 校验器同步

产出：
- `MacosHostSmokeOptions::from_environment()` 等下沉到三个平台基座
- `macos/skia`、`linux/skia`、`windows/skia` 应用 M3 + M4 + M5
- `MacosSkiaSmokeOptions` / `LinuxSkiaSmokeOptions` / `WindowsSkiaSmokeOptions` 删除
- **同步修改 `tools/moui/validate_harness_invariants/main.mbt:443`**，接受 `desktop_surface_route` 作为 R3 证据（§3.5 [RISK]）
- 简化 `scripts/validate-renderer-provider-open-extension.mjs:132-146` 的 Check 2 为统一规则

预期：`macos/skia` 1293 → 约 900 行；三包合计约 -450 行。

验证：
```
moon check moui/backend/macos/skia
moon check moui/backend/linux/skia
moon check moui/backend/windows/skia
moon test moui/backend/macos/skia --target native
MOUI_SKIA_RENDERER=skia-raster sh scripts/macos-skia-renderer-smoke.sh
MOUI_SKIA_RENDERER=skia-gpu    sh scripts/macos-skia-renderer-smoke.sh
MOUI_SKIA_RENDERER=auto        sh scripts/macos-skia-renderer-smoke.sh
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-options-field-drift.mjs   # 预期 16（linux/skia 的 transparent_titlebar/platform_attributes 丢失已归零）
sh scripts/check.sh --profile pr
```

R2/R3 是本阶段的核心风险面：必须逐一验证三种 `--renderer` 模式与 sticky recovery fallback 行为不变。

回滚点：三个平台各自独立 commit；校验器改动单独 commit 且**先于**代码改动合入（否则 CI 红）。

### Phase 5：剩余包收敛 + shim 清理 + 预算重置

产出：
- `macos/wgpu`、`linux/{sun,wgpu}`、`windows/{sun,wgpu}` 归队协商（消除 D1 残余）
- `ios/skia`、`android/skia`、`harmonyos/skia` 应用 M1（`HostRendererAdapter[UInt64]` 替代 `RendererProviderAdapter`）
- 删除 `MacosRendererProvider` / `LinuxRendererProvider` / `WindowsRendererProvider` / `RendererProviderAdapter` 四个 shim
- 删除 `create_skia_raster_host_binding` / `create_skia_hybrid_host_binding`
- **重新测量并下调 `checks/platform-adapter-duplication-baseline.json`**（P12 shrink-or-stay：预算只减不增，收敛完成后必须落基线）

验证：
```
moon check --target native
moon check --target wasm-gc
moon test --target native
node scripts/validate-platform-adapter-duplication.mjs
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-options-field-drift.mjs   # 预期 0（剩余 16 处全部归零，迁移完成）
sh scripts/check.sh --profile pr
```

回滚点：本阶段每个包独立 commit；基线下调必须**最后**合入。

### 阶段收益汇总（估算）

| 阶段 | 净行数变化 | 剩余丢失字段数（§1.3.1 矩阵） | 消除的问题 |
|------|-----------:|----------------------------:|-----------|
| 1 | +约 120（新增装配壳） | 19（基线） | — |
| 2 | -约 360 | 18（macos/sun 的 1 处归零） | D1（macos/sun）、D2（macos） |
| 3 | -约 40（含新包开销） | 18（web/wechat 不在本矩阵，D4 单独归零） | **D4 全部** |
| 4 | -约 450 | 16（linux/skia 的 2 处归零） | D3 主体、R3 三份拷贝 |
| 5 | -约 600 | **0**（剩余 16 处全部归零） | D1 残余、D2 残余、D3 残余 |
| 合计 | **-约 1330** | 19 → 0（单调递减） | D1 / D2 / D3 / D4 全部 |

---

## 7. 风险与未决项

### 7.1 风险

| 编号 | 风险 | 等级 | 缓解 |
|------|------|------|------|
| R-1 | M5 实施时误将 `@env.get_env_var("MOUI_SKIA_RENDERER")` 一并下沉到 `moui/render/skia`，导致三个 desktop provider 失去 `MOUI_SKIA_RENDERER` 字面量、R3 `has_env` 判定失败 | 中 | R3 校验器**保持原样不放宽**，正好充当这一误操作的自动拦截网（见 §3.5.3 B5 边界）。Phase 4 提交前跑 `validate_harness_invariants` 即可暴露 |
| R-2 | native 链接约束：任何试图减少绑定包数量的后续提议都会撞上 §5.1 | 高（认知风险） | 已写入 ADR 草案 Consequences，作为长期约束记录 |
| R-3 | embedded runtime（android/ios/harmonyos）由宿主 App 驱动生命周期，`HostRendererAdapter[UInt64]` 的 `W = UInt64` 丢失类型安全 | 中 | 可进一步收紧为 `HostRendererAdapter[@window_android.Surface]` 等具体类型；但 Phase 5 先做等价替换，类型收紧另开工单 |
| R-4 | P11 判定依赖「不新增 provider ID」。Phase 2/5 让 sun/wgpu 归队协商后，它们的 provider ID（`sun-raster`、`wgpu`）会**首次真正出现在**能力上报中 | 中 | 这些 ID 在 `render/sun/provider.mbt:18`、`render/wgpu/provider.mbt:17` 已定义并已被校验器 Check 2 覆盖，属于「已声明未启用」而非新增。**但需要在 Phase 2 用 `validate-renderer-provider-manifests.mjs` 实测确认 manifest 不报增长**，这是 Phase 2 的 go/no-go 判据 |
| R-5 | `macos/skia` 的 `create_renderer_from_provider_bindings` 有 GPU→raster 的嵌套回退逻辑（:455-540），M3 改造时容易破坏 sticky recovery | 高 | Phase 4 单独为该函数写回归测试；三种 `--renderer` 模式 + context loss 注入全覆盖 |
| R-6 | `pub using` 重导出不保留 `pub(all)`，若合成根想重导出 `HostRendererAdapter` 会丢失字段可见性 | 低 | `HostRendererAdapter` 字段本就是 `priv` + 访问器，不受影响 |

### 7.2 未决项（需要总监或用户拍板）

1. **`run_*` 入口是否保留 4 个？** 当前每个绑定包有 `run_app` / `run_app_with_options` / `run_smoke_app_with_options` / `run_app_with_options_async_pump`。最激进的方案是绑定包**只导出 `renderer_provider()`**，由入口直接调用 `@macos_host.run_app_with_renderer_provider(...)`，可再省约 200 行，但会破坏所有 examples 的入口写法。**建议保留 `run_app` + `run_app_with_options` 两个，删除另两个**（smoke 与 async pump 由入口直接调平台基座）。需要拍板。

2. **`typealias` 是否可用？** 若可用，`pub typealias @render.HostRendererAdapter[@window_macos.Window] as MacosRendererProvider` 能让 Phase 2/5 的 API 破坏降为零。需要一次 5 分钟的语法验证实验。本方案不依赖它，但收益明显。

3. **`ios/android/harmonyos` 的 `W` 类型是否收紧？**（R-3）等价替换还是顺带收紧类型安全。

4. **P12 基线下调幅度**：Phase 5 收敛后重新测量，是否同时把 `allowUntil: "2026-12-01"` 的「per-platform redraw frame loop」豁免一并处理（该项与本方案无关，但到期时间临近）。

5. **是否将「渲染器包导出契约」写入 `docs/invariants.md`**：建议新增一条 P13「每个 `moui/render/<r>` 必须且仅需导出 `create_<r>_provider`；host binding 由 `RendererProviderBinding::from_provider` 统一派生」，由简化后的 Check 2 机械校验。需要拍板是否新增不变量编号。

---

## 8. 附录：证据索引

| 断言 | 证据位置 |
|------|----------|
| provider 抽象已存在 | `moui/render/provider_contract.mbt:80-96,104-107,128-140,153-207` |
| 共享装配壳已存在 | `moui/render/provider_shell.mbt:16-42,49-78,87-116` |
| 平台基座不 import 具体渲染器 | `moui/backend/{macos,linux,windows}/moon.pkg` |
| 真实注入点是平台私有结构 | `moui/backend/macos/macos_backend.mbt:53-57`；`macos_app_runtime.mbt:5-21,80-101` |
| 注入点被复制 4 份 | `macos_backend.mbt:53`、`linux_backend.mbt:59`、`windows_backend.mbt:53`、`internal/embedded_runtime_backend/hosted_window_backend.mbt:33-45` |
| 6 个包绕过 ADR 0019 协商 | grep `select_renderer_provider_binding` 命中 8 处，均不含 sun/wgpu 绑定包 |
| `macos/sun` 使用裸闭包注入 | `moui/backend/macos/sun/macos_sun_provider.mbt:128-137` |
| options 逐字段拆装样板 | `macos_sun_provider.mbt:2-125`；`macos_skia_provider.mbt:31-54,209-315` |
| `renderer_metrics_from_host` 复制 12 份 | 12 个绑定包各 1 处，如 `macos_sun_provider.mbt:396` |
| `MOUI_SKIA_RENDERER` 复制 3 份 | `macos/skia:89`、`linux/skia:34`、`windows/skia:45` |
| web 违例 | `moui/backend/web/moon.pkg:7`；`webgpu_renderer.mbt:57-86` |
| wechat 违例 | `moui/backend/wechat/moon.pkg:5`；`host_runtime.mbt:12,37` |
| wechat 渲染器用法仅 3 个方法 | `host_runtime.mbt:38,39,121` |
| 泛型 struct 已验证可用 | `moui/backend/platform_bridge/window_slot.mbt:27,32`；使用处 `macos_app_runtime.mbt:103` |
| 工厂签名已统一 | `render/skia/provider.mbt:9`、`render/sun/provider.mbt:13`、`render/wgpu/provider.mbt:9`、`render/canvas2d/provider.mbt:9` |
| host binding 工厂仅 skia 有 | `render/skia/provider.mbt:53,77` |
| 校验器内嵌闭合矩阵 | `scripts/validate-renderer-provider-open-extension.mjs:132-146` |
| R3 校验依赖字符串字面量 | `tools/moui/validate_harness_invariants/main.mbt:440-451` |
| `moon.pkg` 只能按 target 门控 | `checks/external-consumer/.mooncakes/moonbitlang/async/src/os_error/moon.pkg:14` |
| 渲染器包链接配置互斥 | `macos/skia/moon.pkg`、`macos/wgpu/moon.pkg`、`macos/sun/moon.pkg` 的 `cc-link-flags` 与 `native-stub` |
| `render/skia` 为 native-only 且已含 env | `moui/render/skia/moon.pkg:5,16` |
| `moui/render` 依赖极简 | `moui/render/moon.pkg:1-5`（core/zeno/svg） |
| `moui/backend/host` 主块不依赖 render | `moui/backend/host/moon.pkg:1-6` |
| `resolve_surface_route` 签名 | `moui/render/pkg.generated.mbti:92` |
| P12 永久豁免项 | `checks/platform-adapter-duplication-baseline.json` budget.allowlist |
| ADR 0019 原文 | `docs/decisions/0007-renderer-and-skia.md:390-470` |
| ADR 0020 原文 | `docs/decisions/0011-platform-class-and-convergence.md:83` |
| ADR 0023 原文 | `docs/decisions/0023-sun-experimental-renderer.md` |
