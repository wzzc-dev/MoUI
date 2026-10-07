# MoUI Studio 对白转录改造要点（2026-10-07）

- **prompt 回显**：composer_run 在盖戳后、路由前 push `CardUserPrompt`
  （body = prompt 原文）；空 prompt 不推。用户气泡右对齐 = fill_row 里
  `spacer(weight=1)` 推右，宽钳 70% 行宽；气泡高度必须含 container
  padding 8×2（+16 不是 +10，否则文字被裁——text_area 内垫同族坑）。
- **时间线 = 卡管线复用**：用户气泡/AI 消息/diff/错误全是 AiCard，新增
  CardUserPrompt；at 戳由 push_ai_card 单点盖（civil_seconds(model.clock)）。
  时间线行按「连续工作卡成组折叠」构建；CardError 的真实 push 点 =
  proposal 解析失败 + 真实 provider 失败。
- **受控滚动**：TranscriptScrolled 对比新旧 offset.y 判滚动方向（±2px 死区）
  翻转 transcript_follow；follow_transcript 只在跟随态把 scroll 置
  (0, 1e9) + seq 自增（终端同款钳底）。**test 陷阱**：update 臂原地改 mut
  字段 → 保存「before 值」必须用 let 拷贝标量，别事后读旧模型字段
  （scrolled/restored 是同一记录别名，断言恒假）。
- **会话存储**：EvAiSessionsDirty 进 outbox → 组合根按 sessions_store_path
  注册总线监听器 → AiSessionsStoreWriteRequested → write_text.effect。
  读失败（文件不存在 = 首跑常态）保持默认会话不声不响；解码失败才
  with_notice。codec 布尔用 0/1 数值（Json::boolean 匹配面不确定，绕开）。
- **墙钟**：HostWallClock 在 runtime（app 禁 import）→ app 自定义
  StudioClock，组合根映射注入 program(wall_clock=)；clock 订阅只在
  PsAi 活跃（1s），承担时间线/相对时间刷新。
- **拆文件**：ide_ai.mbt 1814 触 1800 棘轮 → 会话列表整块拆
  ai_sessions_pane.mbt（418 行）。
- **既有 kernel 漂移**：本轮发现 kernel_*.mbt 快照有 moon fmt 风格漂移
  （非本轮改动），sync_kernel 已同步转绿。
- 破坏验证记录：置题/错误卡/芯片行/版本门/命令分发五处均故意破坏确认会红。

## 二期视觉复刻（VS Code 智能体模式,2026-10-07）

- **双行会话行**：36pt（AI_SESSION_ROW_HEIGHT）；元信息时间回退链
  created>0?created:updated,全 0 →「刚刚」；来源图标 = 有已采纳提案 ? Gear : Chat。
  created 经 AiSessionCreate(Int) 传入（切片无钟）;codec v1 追加可选字段
  解码回退 updated,不 bump 版本。
- **模式下拉**：脚注原位切换（收起=单芯片/展开=四胶囊行）,不引入浮层——
  88 预算不变;SetComposerMode 顺带收起。
- **提示头条**：三段着色文本（prefix/accent/rest）,整行 on_tap=ToggleAiHistory
  （着色词有真实行为,不做死链接）;hairline 与输入区分隔;仅空会话中心态渲染,
  composer_block_height 单点含 AI_TIP_HEIGHT（紧凑宿主预算不动,空闲卡 ≤140 保住）。
- **container border**：`border=Some(@core.BorderStyle{brush: @core.Brush::Solid(c),
  width: 1.0})` ——1px 描边不用 card（card 的 padding=24 固定默认）。
- **枚举构造器推断边界**：`let x = if c { Gear } else { Chat }` 裸构造器无法推断
  → 必须 `let x : @style.IconName = ...`（app 直接 import 了 views/style）。
- **截断教训**：`src[:start] + new` 重写文件会把尾部内容一起截掉（本轮截掉
  ai_host_is_bottom/AI_SESSION_HEADER_HEIGHT,编译错误找回）——批量重写后立即
  `wc -l` + 全文件 grep 核对。

## 二期真机复检缺陷（2026-10-07）

- **空态居中公式陷阱**：`top_pad=(H-块高)*k` 只补上不补下——列自然高 =
  (H+块高)/2,再被 ContainerBox 垂直居中,内容偏下且下方留大空白。修法 =
  上下等重 `spacer(weight=1)`（定高容器里加权 spacer 吸收 slack,列铺满）。
- **宿主高度账统一**：底栏 chrome/钉底占位一律用 composer_block_height
  （含芯片行/提示头）;ai_bar_composer 包装层纵向内垫必须为 0——卡片自身
  已有四周 8 内衬,双重计账 16pt 在块足迹变宽后刚好裁掉脚注。
- **截图驱动调试通路**：C 编译 CGWindowList 枚举窗口 id → `screencapture -o -l <id>`
  按窗截取;**改完必须 rebuild 再截**（直接跑 _build 里的 exe 是旧二进制,
  本轮因此误判修复未生效一轮）。

- **居中稳健写法（二期定案）**：垂直居中 = 上下等重 spacer + 列显式
  `.frame(height=height)`。只加 spacer 不钉高:ContainerBox 测量期拿 min 高、
  渲染期二次居中,内容偏下;定高公式(top_pad=k*(H-块高))列高只有一半,同病。
  验证:posture 行必须贴区域底（回归断言 posture_y > 阈值）。
- **零高占位**：占位高度为 0 时不要推 `text("", h=0)`——text 有最小行高
  (~16pt),会在 composer 上方顶出空带。用 `container(text, h=0)` 或干脆不推。

- **Composer 边距与宿主区分**：中心态输入面走 `ai_composer_framed`
  （左右 16/底 8 一圈留白,VS Code 口径）;底栏/停靠宿主保持贴边——同一个
  composer(),包装在宿主分支做,别把边距写进 composer 本体。
- **拖拽区随顶栏内容演进**：顶栏新增窗控钮必须同步 topbar_actions_width
  （右簇）与 topbar_drag_x（左簇——左栏开关在拖拽区左侧,漏算=点开关变拖窗口）。
  破坏验证:frame 高度×0.62 → posture 位移被 `posture_y > 700` 断言红线命中。

- **RvWorkspace 工作区面板**：AI 模式右栏展开 = 更改/文件 双页签（非停靠、
  非检查器）。更改数据源 = proposal_history + pending;改动文件从 DiffEntry.path
  前缀推导（control/window→form.mbt,handler/variable→handlers.mbt——注意前缀
  是 control. 不是 controls.）。文件页签复用 project_explorer（空态内置）。
  新枚举变体记得 `pub extend X with Eq::{not_equal, equal}`（derive(Eq) 的
  implicit promotion 已弃用,check 会报 0079）。
