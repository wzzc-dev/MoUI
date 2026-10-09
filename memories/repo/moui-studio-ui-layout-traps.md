# MoUI Studio UI layout traps (views.mbt)

- **Verify layout via MCP, not pixels**: studio's macos entry serves MCP NDJSON
  on its own stdin (`serve_with_diagnostics`, protocol 2024-11-05): 2 semantic
  tools + 4 diagnostics (runtime counters, paint summary with ALL drawn texts,
  raw pointer/keyboard event injection `{"kind":"Pointer","position":{x,y},
  "phase":"Down|Up"}`, command intents). `read_semantics` frames are numeric
  ground truth; `perform_action` drives the app (target node_id as decimal
  STRING, action `{"kind":"activate"}`, precondition `{"kind":"latest"}`).
  This closed the loop on: empty-canvas hint (paint texts), dirty marker,
  draft restore, canvas zoom hit-testing.
- Known leak (FIXED): text_field values are exposed verbatim in the semantics
  tree. The provider key now uses `password_field` (masked display + reveal
  toggle) and update ignores edits while masked (star-text would corrupt the
  real value).
- Design-canvas auto-fit: the canvas measure fills its constraints
  (`width = min(max_w, max_h/0.75)`), scale = frame.width/640 computed in the
  draw/tap/drag closures — the canvas column is `.flexible()` in the main row,
  so the canvas grows with the window and hit-testing stays consistent without
  model state. Drawing plan ops are pure design coords; transforms happen at
  draw time.
- Draft auto-save: `program()`'s update wrapper recomputes
  `@codec.encode_program(program)` per message; dirty = encoding !=
  `saved_encoding` (set on save/open), draft written to settings key
  `studio.draft` only when the encoding changed since `draft_encoding` (RunTick
  at 30fps doesn't rewrite). Restored drafts boot dirty (● next to the title).

- `@views.text` defaults to `width=160` and the width is a **minimum** (grows with
  measured text). Inside a fixed-width panel it silently inflates the scroll
  content wider than the viewport; sibling buttons stretch to the inflated width
  and get clipped square by the scroll clip. Always pass explicit `width=` for
  texts inside narrow fixed panels (studio left panel headers use 140).
- Scroll indicator geometry (framework): the thumb draws at the **viewport's
  right edge minus 7pt** (`scroll_indicator_thumb`), so "scrollbar at the panel's
  far right" means the scroll viewport itself must reach the panel edge — e.g.
  card `padding=0` + full-bleed `scroll_view(width=card_width)` (studio right
  panel: thumb lands ~4pt from the card border).
- A scroll container's child **frame is the viewport width** (tight on
  re-layout): a bare `column` directly inside `scroll_view` stretches every
  child to the full viewport. To get centered content + a scrollbar lane, wrap
  the column in `@views.container(width=<content>, background=transparent,
  padding=<vertical breathing>)` — ContainerBox centers the child inside the
  stretched frame, and the leftover right strip becomes the indicator lane
  (studio right panel: viewport 300 / content 250 → fields centered at 25pt
  margins, ~18pt clear of the thumb). Cap every child's `width=` to the content
  budget, or one wide text inflates the whole column again.
- Main-row horizontal centering: flex rows pack children at x=0; the top_bar is
  centered (ContainerBox centers its narrow child), so the two rhythms clashed
  and the left card sat flush with the window edge. Fix: `@views.spacer()`
  (weight=1) at both row ends centers the row content and degrades gracefully
  on narrow windows.
- `@views.divider(axis=Vertical)` measures as **full available height** (mirror
  of the horizontal divider's full-width behavior). Inside a flex row it drives
  the row's cross size up to the window height; combine with `ContainerBox`
  centering this pushed the design canvas ~157pt down and pushed the footer
  notice off-window. Fix: bound the row `.frame(height=560.0)` (same as the
  panel cards) and `align=Start` so the 640x480 canvas top-aligns with panels.
- `shortcut_button` chip text is mono 16px: `Ctrl+Z` ≈ 58px, `Ctrl+Shift+Z` ≈
  116px. Chip width must be ≥ label + 12 padding (studio uses 84 / 140); smaller
  values clip the shortcut text on both sides.
- Button variant discipline after the "red wall" feedback: one solid Primary per
  panel (运行 / 生成提案 / 闸门确认); list entries, mode toggles, delete/duplicate
  use Tonal / Outline.

## 设计=运行 治本架构（2026-09）
- 设计舞台不再用 canvas 画"控件效果图"（双渲染器必然漂移：拟真按钮
  13px vs 真按钮 16px semibold 当场翻车）。改为三层：背景画布（窗体框+
  点阵+空态提示）+ 真实控件层（StageLayout 按 IR 矩形分配帧）+ 透明手势
  覆盖层（拦截全部指针，绘制选中描边/名牌/参考线，指针转设计坐标 Msg）。
- `form_widget` 是表单控件唯一构造点：运行舞台传真实回调，设计舞台传
  Noop（文本类回调必填，Noop 兜底防漏网点击）。
- StageLayout/两层画布的缩放都现算 min(帧宽/640, 帧高/480)，三层永不
  失配；导出 runner 模板内嵌同款 StageLayout（自包含副本）。
- 已知代价：zoom 对真控件是"盒子缩放、字号常量"（文字不随 zoom 放大）。

## 积木画布几何（2026-10，用户报「菜单向左/积木撑满/黑块」一轮）

- **块宽随内容**（Scratch 口径）：`blocks_item_rects` 按展示文本估宽收紧，
  不再撑满画布。估宽 = `text_estimate_width` ÷ `LABEL_WIDTH_SAFETY`（否则
  fit_label 的 5% 安全系数会把「按估宽定宽的块」再截一次省略号），下限 64。
  纪律：**凡是算矩形的路径（draw / 命中 / update 的落槽与 PaletteDrop /
  blocks_pane 的指示线）必须传同一份 `display_texts`**——宽度进了几何之后，
  缺了它就是另一组矩形，命中与绘制错开。
- **插槽洞的游标 = label_x + 引导宽**：引导 = 返回箭头 + 本地化标签 + 两
  空格（`block_row_texts` 与展示文本同源产出 `lead_texts`；宽度经
  `blocks_row_lead_width` 用真实度量）。洞游标曾从 label_x 直接累加段宽，
  而整行文字按默认 `TextCenter` 画——洞（近黑胶囊）孤零零留在左边，就是
  用户截图里的「积木上的黑块」。修法：标签 `align=TextStart` + 引导宽计入。
- **洞必须画在文字之下**：绘制按 ops 顺序叠层，`SlotHole` 先于 `BlockLabel`
  推入——反过来洞会把字形盖掉。
- 聚光灯不再加「▶ 」文字前缀（`BlockStroke` 描边已表达）：内容宽下前缀
  会让高亮行被 fit_label 挤出省略号。
- 右键菜单候选顺序 `BelowStart → AboveStart → BelowEnd → AboveEnd`：锚点
  是零尺寸指针点，`…End` 把菜单右缘对齐指针（向左弹）。零尺寸锚点下
  「主方向」完全由候选顺序决定。

## 运行语义与全屏页（2026-10，用户报「没点按钮标签就有内容 / 底栏只占左半」）

- **「运行」= 装填，不执行**：`start_run`/`start_compiled_run` 只进入运行页
  并建**空计划**运行态（舞台 = 设计初值），事件子程序只在真实控件事件
  （`ControlClicked`/`RunToggle`/`ControlChanged`/`ControlInputDone`）时经
  `run_handler` / `dispatch_compiled_event` 派发。此前 RunStart 直接把选中
  子程序跑完——用户「还没点按钮标签就有内容」。装填态判别：`plan.instrs
  == 0`（`merge_run_back` 据此跳过「运行完成」审计）。
- **全屏页（运行/预览/帮助）的底栏必须用 `side_width`**：`shell_chrome_widths`
  按「左右栏都在」算 `center_width`，而全屏页不渲染左右栏——底栏用
  center_width 就只铺左半段，右侧一条空白。
- 已知口径分歧（未修）：两轨事件派发的审计行号不同源——解释轨
  `run_handler` 走 IR 语句（line 0），编译轨走草稿 trace（真实行号）。
  跨轨比对审计时只能比 (op, detail)。

## 活动栏紧凑口径（2026-10-04，参考用户截图的 VS Code）

- `ICONBAR_WIDTH` 48→**34**、按钮 32→**28**、字形 15→**17**、**裸字形**
  （无常驻底块、**无选中条纹**——条纹方案试过被用户否掉；选中态只有字形
  亮度一层，几何验收里有「栏内不得出现强调色色块」的反断言防回潮）。
- `icon_button` 的选中底块是可关的（`tile? : Bool = true`）：活动栏传
  false，面板头等工具条按钮保持底块两态。
- 对比口径教训：给「VS Code 对比」下结论前先量用户的截图（信号灯间距可
  以标定两窗口是否同比例尺）——原版默认 48px ≠ 用户截图里那根 ~34pt。
- MoonBit：`1e9` 不是合法 Double 字面量（`e9` 被当标识符），写 `1000000.0`。

## 列间 sash（2026-10-04）

- 三列（左栏/中心/右栏）之间的分隔是 **4pt 可拖拽 sash**（`v_sash`，
  ide_root）：拖拽绝对映射（指针 x → 目标宽度），界限在视图构建期闭包；
  Model 存 `left_width`/`right_width`，`shell_chrome_widths` 消费并把 sash
  宽度计入三列预算。
- 可行前提：`on_drag_with_frame` 的手势在激活期**持有指针捕获**——被捕获
  的元素即使指针出界（或自己的 frame 拖拽中移动了）也照常收到 Move。
  需要「拖一个会动的分隔条」这类交互时直接用这个机制，不要造拖拽起点
  状态。
- 旧的 `usable = width - 2` 预算会在行尾留死区；分隔件宽度进了预算后要
  让「三列 + 分隔件之和 == 行宽」有几何测试锁着。

## VS Code 资源管理器（2026-10-09）

- **非模态浮层屏障曾吃掉整个 app 的 hover 与点击**（框架级，已修）：
  `PresentationBarrier` 对非模态（toast / 上下文菜单，`scrim=false`）也
  消费了 `Down` 以外的相位，而运行时的 `overlay_covered` 一旦置位就把
  覆盖点之下的在流子节点整帧跳过。表现：屏上只要有一条 toast（导入/保存/
  编译成功必发），**整个 app 的悬停与点击全部失效**——包括顶栏那些早就
  存在的图标按钮。原代码只为**滚轮**开了特例（`wheel_delta != 0` 的
  `Move`），于是「能滚但悬停/点击不灵」同时成立，把同一个根因拆成两个
  看起来无关的症状。修法：非模态屏障**只**吃 `Down`，其余相位放行。
  回归测试在 `moui/views/presentation/presentation_test.mbt`
  （非模态放行 / 模态仍吞，一对）。
- **hover 是转移沿回调，只有 `on_hover` 一种入口**：`View::on_hover(Bool)`；
  会写 `ViewStateContext::hovered` 是必需的——宿主不发明面上的 leave 事件，
  运行时只对「仍报告 hovered/pressed」的子树合成 `Exit`。自己存一个私有
  「上次悬停」槽会导致永远收不到 leave。
- **行内动作只在悬停出现时，宽度必须始终预留**：非悬停行用等宽空白占位。
  否则标签会在鼠标扫过整棵树时左右跳动（实测最刺眼的一处）。
- **就地新建/改名**：输入行挂在**目标目录行之下**（VS Code 口径），目标
  目录由 `file_create_dir` 携带；`FileRenameStart` 只把**文件名**填进草稿，
  提交时按原目录拼回 rele（填整个 rel 会拼两次）。
- **单树多根**：目录折叠键必须带根下标（`root_collapse_key`）——按 rel
  单键会让不同工程的同名 `app/` 一起折叠。点某棵树的文件走
  `SelectProjectFileAt`（同时切活动工程 + 选中），否则下游按活动工程拼
  绝对路径会读到另一棵树的同名文件。
- **`String::compare` 不是字典序**：它是**先比长度**的序
  （`"zeta".compare("Alpha") = -1`，`"ab".compare("b") = 1`）。给文件名/
  目录名排序必须用 `lexical_compare`，否则得到「短的在前」这种没人认得的
  顺序。
- **死消息门的剥离器不认字符字面量**：源码里出现一个内含引号的字符字面量
  （`if c == '"'`）会让它把该引号当成字符串起始、**此后整份文件被抹成
  空白**，该文件所有 `Msg` 变体随即被判成「没有构造点」而整套失败。
  写码点比较（`c.to_int() == 34`）绕过。同理，别把消息收进
  `(commit, dismiss)` 元组再 `on_tap(commit)`——`Variant =>` 被当作匹配臂，
  裸标识符不算构造点。

## 资源管理器:截图对齐与就地新建（2026-10-09 第二轮）

- **对齐截图的实测校正两处**（都白吃 24pt 纵向空间,是「像不像 VS Code」
  的第一观感差异）:① 没打开任何 tab 时**不画**「打开的编辑器」分区
  （连标题都不画,VS Code 同款;空壳白占两行）;② 顶层文件夹**直接铺在
  工具栏之下**,不套「文件夹」分区头（工作区根就是面板主体,多一层同名
  灰字只是噪音）。这两条被 wbtest 一对一锁着（有 tab / 无 tab）。
- **就地新建必须带目标目录**:`FileCreateAt(rel)` / `FolderCreateAt(rel)`
  成对。早先「新建文件夹」是无参的 `FolderCreateStart`,目录行悬浮 ＋ 按
  它会把文件夹**默默建到工程根**——树上看不出差别,直到发现东西不在点的
  那个文件夹里。两个入口必须同形,且都做「先把目标目录从折叠集里摘掉」
  （否则输入行折在树里,看着像点了没反应）。
- **一行只能有一个 `on_hover` 槽**:行级 `on_hover` 用于写
  `ExplorerHover`（控制行内动作显隐）;行内动作图标**不能**再挂
  `on_hover` 写状态栏提示——会互相覆盖,症状是「悬停行里点不到动作」。
  图标的名字走 `accessibility_label`,键盘/读屏用户拿得到。
- **溢出菜单的高度要进视口账**:`⋯` 菜单是就地展开的列
  （不用 `@views.dropdown`——自带锚点与 DropdownState,塞进 26pt 工具行会
  撑破行高）。菜单行数必须同时喂给 `explorer_toolbar_height`,否则虚拟化
  列表会多算一屏、底部行画到面板外。
- 未使用的 i18n key 无人把关（仓库**没有** unused-key 校验器）:改布局后
  要手工回查（本轮删掉 `app.explorer.{folders,editors_empty,new_in}`）。
- **文件类型要带颜色**（Seti 口径）:全灰的树要逐字读文件名才知道是什么文件,
  那是列表不是树。形状与颜色必须**同一个判据**产出（`file_tint` 一处判定,
  `file_icon` / `ide_file_color` 各自投影）——两处各写一遍后缀列表迟早出现
  「形状是 JSON、颜色是文档」的自相矛盾行（有测试锁着一一对应）。
- **空态才显示导入行**:有工程时那条「导入 MoonBit 工程…」白吃 28pt,而工作区
  的根才是面板主体;导入仍可从 `⋯` 菜单到达。工具栏高度算式必须跟着这个
  条件走（`projects.length() == 0` 时 54,否则 26）。

## 工作区根那一层（2026-10-09 第三轮,用户反馈「看不到根目录下的文件」）

- **根因**:`moon.work` 只列成员目录,而**工作区根自己**的文件
  （`moon.work`/`README.md`/`AGENTS.md`/`gradlew`…）不属于任何成员。早先
  把每个成员各自当成顶层行 → 根这一层根本不存在,那些文件在整棵树里**没有
  任何出现的位置**。诊断口径:`gradlew` 的 owner 数为 0。
- **正确形态**（截图二本来就画着）:**一棵工作区根行**,成员是它的子目录,
  根文件与成员目录**同级**。不是「N 个成员各一棵顶层树」。
- **命名空间随之统一**:工作区导入后,树上的 rel 是**工作区相对**路径
  （`moui_studio/app/app.mbt`）。不带成员前缀会让两个成员的同名文件撞成
  一行。两个成员的同名文件必须是不同的 rel（有测试锁着）。
- **路径解析收成一个漏斗**（`tree_root_of` / `tree_abs_path`）:改之前有
  **十处**各自拼 `{project.root}/{rel}` 并各自 `match active_project_of`。
  那种写法无法表达「这个 rel 属于工作区根、不属于任何工程」——根上的文件
  在每一处都落空。新增树上的寻址一律走漏斗,不要再拼 `project.root`。
- **归属反查用路径、不用行下标**:`project_index_of_tree_rel`（最长前缀
  胜出）。工作区根的下标是 `WORKSPACE_ROOT_INDEX = -1`,把它写进
  `active_project` 会让「当前工程」这个语义失效——根上的文件应保持原活动
  工程不变（有测试锁着）。
- **就地输入的守卫只看目标目录**:早先 `push_input_rows` 还要求
  `index == active_project`,工作区根（-1）永远不等于它 → 在根上点 ＋
  什么都不发生。`file_create_dir` 已是树相对路径、在整棵树里唯一,够判了。
- **折叠键的取值空间**:工作区根用负下标,成员的目录键仍用「成员下标 + rel」,
  两套永不互撞。

## 裸 container 的回落底色 = 黑方块（2026-10-09 第四轮,用户截图反馈）

- **症状**:树行左侧一排 12×16 的黑色圆角方块（截图红框）。用户看到的是
  「文件前面的黑色方块」,实际是**缩进导轨的占位格**。
- **根因**:`@views.container(w, h)` **不给 `background` 时会回落环境面板色**
  （深灰 `rgb(0.121,0.133,0.153)`）。在编辑器底色上就read成黑方块。
  同一次里一共三处:
  1. `explorer_guides` 给 divider 套的裸 container（用户框出的那排）
  2. 树行的**箭头热区**（`twisty=Some` 分支,同一个裸 container 写法）
  3. `explorer_tool_icon` 的工具栏图标外框
- **修法**:占位/热区一律给 `background=rgba(0,0,0,0)`（透明）;只有真正要
  画底的（`icon_button` 的选中态、溢出菜单展开态）才显式给色。
- **第三个坑（改的时候踩到的）**:不要试图用 `.frame(width=12,height=16)`
  给 divider 定尺寸——**竖放 divider 会填满可用宽**,整格变成实心竖条,
  比原来的方块更糟（实测:1pt 线数 20→0,12×16 实心块 0→25）。
  正解是 `center(width, height, background=透明)` 里放 1pt divider:
  格子占位、线居中。
- **回归门**:`explorer 缩进导轨:透明占位格 + 1pt 细线` 断言
  「导轨格里没有 alpha>0.5 的填充」+「1pt 细线确实存在」+「箭头/工具栏
  图标内格无实心底」——只断言前者会被「导轨压根没画出来」蒙混过关。
- 排查手法:把 draw_commands 里 `FillRoundedRectBrush` 的
  `origin/size/brush.alpha` 打出来按 x 区间过滤,一眼定位是谁画的底。

## 嵌套成员必须有中间目录节点（2026-10-09 第五轮,用户反馈）

- **症状**:`examples/` 下的模块被**平铺**到顶层,收起 `examples` 收不掉里面
  （因为 `examples` 这个节点压根不存在）。
- **根因**:成员路径可以是**多段**的（`examples/terminal`、
  `benchmarks/full_cycle`）。早先按 `model.projects` 遍历、一个成员一行,
  于是成员行直接落在工作区根之下,中间目录无处安放。
- **修法**:树按**层**拼装（`workspace_tier`）——某一层的子目录 =
  扫描到的真实目录 ∪ **成员路径在这一层的前缀段**（中间目录补出来）;
  递归下去,遇到「这一层正好是某个成员的根」就渲染成成员行
  （`member_index_at` 判定),否则当普通目录继续展开。
- **连带**:成员的折叠键必须带**成员在树上的 rel**
  （`root_collapse_key(index, member_rel)`),不能只带下标——否则
  `examples` 与 `examples/terminal` 会互相折叠。
- **验收判据**:折叠 `examples` 后,归属 `examples/*` 成员的**行数必须为 0**
  （只数成员下标对应的 key,别用 `contains("examples/")` ——成员的**内部**
  也可能有同名子目录,如 `moui_skia/examples/…` 会误报)。同时要断言
  「折叠前 > 0」,否则判据本身失效、测试变成空断言。
- 单段成员（`tools`、`moui`）没有中间目录,它自己就是那一层的目录行,
  这是正确形态,不要为它硬造一层同名节点。

## 行数预算两套目录都要同步（2026-10-10）

- **症状**：`node scripts/validate-maintenance-baseline.mjs` 直接失败并只打一行
  `moui_studio/app/app.mbt`；`moon run tools/moui/validate_source_file_policy`
  则报另外两个文件。
- **根因**：仓库里有**两套**独立的行数预算目录，同一份文件要在两处登记：
  1. `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt`
     （`validate-maintenance-baseline.mjs` 读，按物理行数比较）；
  2. `checks/source-file-policy.json`
     （`moui/validate_source_file_policy` 读，按**逻辑行数**比较）。
  只改一处等于没改。
- **触发场景**：子仓 `moui_studio` 的实现增长后只更新了主仓的子模块指针，
  两套预算都没跟，于是主仓的门禁在指针对齐的那一刻开始失败。
- **修法**：跑两个校验器，各自按报出的实测值结算预算（仓库先例是把
  `maxLines` 设成当前实测值，并在 `reason` 里写清抬升区间与原因），
  再复跑确认两者都退出 0。
