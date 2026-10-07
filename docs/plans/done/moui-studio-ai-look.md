# Plan: MoUI Studio AI 模式二期——VS Code 智能体模式空态复刻

- **Status**: done（2026-10-07）
- **Goal**: 在一期对白转录工作台(见 `docs/plans/done/moui-studio-ai-chat.md`,时间线/
  会话分组/持久化已落地)之上,向 **VS Code 智能体模式**(Copilot Chat agent mode)
  空态基准做视觉与交互复刻。七处差距:双行会话行(常显相对时间)、区头动作形态、双
  芯片行(工程+模型,带图标与下拉)、提示行并入 composer 卡头(关键词着色可点)、
  模式选择收敛为单下拉芯片、模型 chip 移入脚注、空态 50/50 居中 + 姿态读数常驻。
- **Non-goals**: 麦克风/语音;+ 附件与图片;Automations/Customizations 导航区与
  「聊天」固定条目(VS Code 专属产品面);新建工作树/分支读数;Autopilot 与
  Allow all 放行(以「闸门 · 逐条采纳」读数替代);推理档/上下文窗口读数(极高·1.1M
  ——无对应数据,只显示模型名);真实 provider SSE 流式;Markdown 链接/表格富渲染;
  VS Code 顶栏导航形态(Studio 保留运行/编译 IDE 顶栏)。

## 已核实事实(2026-10-07,直接采信)

- 一期已真机可见:会话分组(默认工程 N)、新建+Meta+N、搜索、提示行、离线模型芯片、
  四模式胶囊、圆形发送;对白时间线/采纳闸门/持久化(.studio/ai_sessions.json)在册。
- 会话行不显示时间:新会话 `updated=0`(未发生结构性事件),`relative_time_bucket`
  对 0 渲染空串;`AiSession` 无 `created` 字段——时间常显缺口的数据根源。
- AiSessions 是共享可变容器;update 臂别名陷阱:断言 before 值先 let 拷贝标量
  (memories/repo/moui-studio-ai-chat.md)。
- 可复用件:info_chip/fill_row(带权重 spacer 的行必须定宽)、group_create_action
  内联候选先例、fit_label、@views.shortcut_button、IconName.Pin、studio.settings
  命令、ToggleAiHistory、SetComposerMode。
- i18n 生成链 + 棘轮;死消息门要求新 Msg 变体有真实构造点。

## 里程碑

### V1 会话行双行化 + created 戳
- `AiSession.created : Int`;codec v1 追加可选字段 "created"(解码缺省 0,不 bump
  版本);`AiSessions::create` 改带时间戳入参(`AiSessionMsg::AiSessionCreate(Int)`,
  调用方传 `civil_seconds(model.clock)`),created=updated=now。
- 显示回退链:created>0 ? created : updated;全 0 显示「刚刚」,不出现空白。
- 行渲染双行(ai_sessions_pane.mbt):第一行 = Chat 图标 + 标题(fit_label);
  第二行 = 来源图标 · 相对时间(淡色小字号;来源 = 有已采纳提案 ? Gear : Chat)。
- 行高 `AI_SESSION_ROW_HEIGHT = 36`;区头/过滤行高度账同文件内同步。
- 新增 `IconName.Chat`(气泡)+ 视图框边界测试。

### V2 区头与列表观感
- 「新建」蓝色大按钮 → 「新」Ghost 描边小按钮(@views.shortcut_button variant)+ ⌘N
  键帽;+ 滑块图标(Gear → StudioCommandRun("studio.settings"));搜索图标保留。
- 分组头加 FolderOpen 图标;「AI 会话」面板头不动。

### V3 composer 信息层重排
- 芯片行两枚带图标下拉芯片:工程(FolderOpen + active_project 名 + ChevronDown,
  点击=SetLeftView(LeftProject) 既有消息/命令);模型(「离线模型」或 provider_model,
  点击=studio.settings)。芯片行在提示行上方。
- 提示行并入 composer 卡头(空会话中心态):带框分隔条(hairline 下边),「提示: 」
  前缀 + 「结构化提案」着强调色,整行可点 = ToggleAiHistory;高度 TIP_HEIGHT=22,
  只进中心态空会话预算(紧凑宿主不动,保住「空闲卡 ≤140」)。

### V4 脚注重排
- 四胶囊收敛为单个「当前模式 ⌄」下拉芯片:点击展开 = 脚注原位切换为四选一胶囊行
  (选中态强调色),`SetComposerMode` 后收起;高度不变(88 预算内原位切换)。
- 模型 chip 移入脚注;ghost 停靠/历史保留;composer 块加 ide_border 1px 描边。

### V5 空态布局 + 姿态读数常驻
- 空会话配重 42/58 → 50/50。
- 姿态读数常驻 composer 下方:无卡 = 「闸门 · 逐条采纳」弱读数;有未处理卡 =
  「待审计 N」警告色(pending_ai_cards);POSTURE_HEIGHT=20 进中心态高度账;
  右侧不放工作树/分支(non-goal)。

### 收尾
双目标全量测试 + 六静态门 + 死消息门 + i18n/sync_kernel --check;真机截图对照
VS Code 智能体模式基准逐项核对;更新 docs/moui-studio.md 与 memories。

## 硬约束

- 每个新 Msg 变体必须有真实构造点(死消息门);命令面板命令表同步。
- app 不 import moui/runtime;新交互走既有命令/消息通道。
- 双目标(native + wasm-gc)全绿;带权重 spacer 的行必须定宽;高度预算单点计算
  (ai_sessions_pane 与 composer_block_height 唯一口径,视图层不做算术)。
- 新断言故意破坏一次确认会红;布局改动跑 shell_layout/shell_responsive/
  ai_bar_layout/ui_regression 确认零回退。
- codec v1 只追加可选字段(解码缺省明确),不 bump 版本、不迁移。

## 验收

1. 双目标测试全绿 + 六静态门 + 死消息门 + i18n/sync_kernel --check。
2. 真机截图对照基准:双行会话行常显时间;区头=新+⌘N+设置+搜索;两枚下拉芯片;
   提示行带框+着色关键词(可点开历史);单「模式 ⌄」下拉四选一;脚注含模型 chip;
   空态居中 + 「闸门 · 逐条采纳」常驻。
3. 功能不回退:提交→气泡→流式→采纳→审计;重启恢复(created/updated/置顶/分组/改名);
   Ctrl+N/F/K;搜索过滤;删除;↓回底(一期口径复测)。
4. 双行会话行在窄左栏(232)与宽左栏都不截断:标题 fit_label,元信息行优先保时间。

## 实施记录（2026-10-07）

- V1–V5 全部落地：app 359/359、plugins/ai 12/12（双目标）；六静态门 + 死消息门
  （238 变体）+ i18n --check + sync_kernel current + 接口漂移门 + web 构建 +
  native 启动探针全绿。破坏验证：created 回退链、姿态读数两处确认会红。
- 新增 IconName.Chat（气泡）；会话行 36pt 双行（标题行/元信息行,created 回退链
  常显时间）；区头 = Ghost「新」+⌘N + Gear 设置 + 搜索；分组头 FolderOpen。
- composer：提示头条并入卡头（三段着色,整行可点开历史,hairline 分隔,仅空会话
  中心态）；双下拉芯片（工程→LeftProject,模型→studio.settings）；脚注 = 单模式
  下拉（原位展开四选一,SetComposerMode 收起）+ 模型 chip + ghost + 发送；中心态
  1px 描边；空态 50/50；姿态读数常驻（闸门 · 逐条采纳 / 待审计 N）。
- 真机截图核对（VS Code 智能体模式基准七项全部命中）：经组合根 MCP 诊断面
  （diagnostics_dispatch_event 指针注入）切到 AI 模式，`screencapture -o -l <id>`
  截取真机窗口——双行会话行（会话 1 + 「刚刚」常显时间）、区头 新建+Meta+N+⚙+🔍、
  双下拉芯片（默认工程/离线模型）、提示头条三段着色、脚注「修改 ⌄」下拉、模型 chip、
  空态居中 + 「闸门 · 逐条采纳」常驻，全部真实渲染。截图通路教训：FIFO stdin 的
  agent 在 Bash 块退出（写端 EOF）后即退出——后续注入必须与初始化同块并全程持有写端。
- 真机复检揪出两个布局缺陷（用户截图 → 定位 → 修复 → 真机截图确认）：
  ① 空态不居中——top_pad 定高公式让列自然高只有面积一半,再被 ContainerBox
  垂直居中,内容整体偏下。修复 = 上下等重加权 spacer（列自然铺满,天然 50/50）;
  回归测试 = 高视口绘制断言 top_gap ≈ bottom_gap（容差 24 覆盖上/下 chrome 差 16）。
  ② 底栏 AI 输入被裁——两层账漏:ai_bar_composer 的 chrome 与 ai_card_body 的
  钉底占位都用 composer_height,没算芯片行(28+2);且外层包装与卡片自身内衬
  双重纵向 16pt。修复 = 统一 composer_block_height 口径 + 包装层纵向归零。
  回归测试 = ai_bar_height ≥ 面板头 + composer 块足迹 + 决策条 + 内衬 + 余量。
  修复后真机截图:底栏脚注完整可见,AI 模式空态居中（top 309.9 / bottom 326,
  差 16pt 为 chrome 固有高度差）。
- 用户真机复检（修复后构建再截）揪出两个布局缺陷,均已修复并真机确认:
  ① AI 空态 composer 偏下——「top_pad 定高公式」列自然高只有面积一半,再被
  ContainerBox 垂直居中。修复 = 上下等重 spacer + **列显式 .frame(height=height)**
  （Frame 钉死高度后加权 spacer 才拿得到 slack,ContainerBox 不再二次居中;
  破坏验证 frame*0.62 → posture 位移被回归测试红线命中）。姿态行贴区域底。
  ② 底栏 AI 输入面上下两头裁切——页签头与芯片行间 53pt 空带 + 脚注越界:
  钉底占位空文本零高仍占一行高(16pt 幻影) + chrome 双重计账。修复 = 占位
  零高时不推 text 节点 + chrome 统一 composer_block_height + 包装层纵向归零。
  绘制级探针（矩形+文本全量 dump 对照）定位,修复后芯片行上移 16pt 与页签头
  正常衔接。教训:零高占位要用零高 container,不要用 text（text 有最小行高）。
- 教训：拆文件/重写函数时 `src[:start] + new` 会截断尾部内容——本轮截掉了
  ai_host_is_bottom 与 AI_SESSION_HEADER_HEIGHT,靠编译错误找回（批量改动后
  必须立即 wc -l + 编译核对）。

## Decision log

| 日期 | 决定 |
|---|---|
| 2026-10-07 | 基准归属 = VS Code 智能体模式(非 ZCode/Codex);推理档/上下文读数不虚构。 |
| 2026-10-07 | created 经 `AiSessionMsg::AiSessionCreate(Int)` 传入(切片无钟,调用方持 model.clock);codec v1 追加可选字段不 bump 版本。 |
| 2026-10-07 | 模式下拉用「脚注原位切换」展开(收起=单芯片,展开=四胶囊行)——不引入浮层,88 预算不变。 |
| 2026-10-07 | 提示条只在中心态空会话渲染(Empty-state guidance;紧凑宿主预算不动,空闲卡 ≤140 保持)。 |

## 二期追加（2026-10-07 用户复检）

- 提示行按用户口径移除（composer 卡头/预算/i18n 三处回收,回归测试改为
  「不得再出现提示文案」契约）。
- composer 四周留白：中心态输入面与左右缘、底部各留一圈（16/16/8）,
  不再顶满——`ai_composer_framed` 两个分支共用;底栏/停靠宿主不套（面板内贴边）。
- 标题栏三开关（VS Code 布局开关口径）：左上 Sidebar=左栏收起/展开
  （新命令 studio.left.toggle:LeftHidden↔LeftTree）;右上 PanelBottom（新图标）=
  底栏、Columns=右栏。拖拽区单一计算源同步:topbar_drag_x（左栏开关带宽 34 之后
  才是拖拽区,否则点开关变成拖窗口）+ topbar_actions_width 图标簇 +2。
- moon check 清零：app 包全部警告（未用变量/弃用 trim/substring/模式载荷/
  blocks_code 未用包→pub 门面/UpdateWithServices 未用参）回收;仅剩
  moui/views/stage.mbt 框架固有 2 条（不在本仓范围）。
