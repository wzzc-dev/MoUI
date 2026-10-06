# ADR 0038: MoUI Studio 静态插件架构（kernel + 贡献点 + 事件 + profile）

- **Status**: accepted (2026-10-06)
- **Context**: MoUI Studio 从单一大 app 包（Model ~100 字段 / Msg ~150 变体 /
  手写接力分发）向「一切皆插件」形态演进，参照 Cordis（deepseek-harness 的
  插件内核：无特权内核、Context=服务容器、贡献点、事件扩展点、profile 组合）。
- **Decision**:
  1. **静态插件**：MoonBit 无动态加载/反射/存在类型——插件 = 包 + 注册函数，
     组合根静态装配。Cordis 的运行时注册/卸载/disposer/patch 层/HMR 刻意
     不做（能力边界，非遗漏）。
  2. **内核（kernel 包）**：Plugin 契约（建在 `Feature::scope` 上，settings
     样板）、类型化服务容器 `StudioServices[Msg]`（结构体即注册表——MoonBit
     无异构运行时映射，字段增删即时显编译错误）、事件总线（静态注册、注册序
     派发、**纯监听器** `(Event) -> Array[Msg]`——副作用走 update 臂，P13
     合规）、贡献点类型（PanelView/ActivityItem/BottomTab/CommandContribution/
     Perspective）、MoonBit 词法器。内核对任何插件零知识。
  3. **协作三缝（Cordis 对照）**：能力走服务键（build/run/terminal/files/
     webview/provider/highlight）；通知走事件（outbox + 包装层排空，跨域
     flag 全部消灭——pending_code_project/pending_build/build_seq 已迁）；
     共享真源（program/selection/当前会话指针）根持有、各插件 read 投影。
  4. **三模式工作台**：活动栏 = 任务模式切换器（图形化/代码/AI + ⚙ 钉底），
     每模式绑定全区域预设（唯一事实表）；`right_visible × ai_anchor` 的
     2×2 收敛为 `RightView` 单枚举 + 宿主推导（AI：右栏停靠 > AI 模式中心 >
     底栏页签）。
  5. **教学版 profile**：组合根裁剪（Teaching = 只注册图形化模式所需能力，
     PTY 强制 unavailable、模式切换守卫 no-op）——「无特权内核」的验收证明。
- **Consequences**:
  - 跨 workspace 模块导入不可行（moon.mod import 仅版本化 registry 依赖）
    → examples/terminal 的 PTY 宿主技术以 **vendor** 形式进组合根
    （macos_skia/pty.c + FFI 绑定），provider 形态 = queue + worker +
    task group（terminal composition 成熟模式）。
  - 新增面板/模式/服务 = 插件包 + 组合根一行注册；内核与既有插件零改动。
  - 教学版裁剪不崩不藏：缺什么显式不可用（终端空态、模式切换 no-op）。
- **Verification**: M0–M7 验收记录见
  `docs/plans/active/moui-studio-plugin-kernel.md` Progress；全量双目标
  测试与六静态门每次里程碑独立验证。
