///|
/// 积木画布：语句链的 Scratch 式投影——拼图块外形（榫头/卯口）+ 分类配色 +
/// 同层拖拽重排。绘制计划是纯数据（可快照测试）；命中/落槽/拖拽在
/// update 里转 typed Msg。与设计画布同契约：paint 命令是窗口全局坐标、
/// measure 忽略约束返回自身尺寸、不用 PushClip/PushTransform。

///|
/// 布局常量（画布局部坐标）。
let block_step : Double = 40.0

///|
let block_height : Double = 34.0

///|
let block_indent : Double = 24.0

///|
let block_margin : Double = 10.0

///|
let block_width : Double = 430.0

///|
/// C 形块左壁的厚度（与块体同色的一条竖边，读作「包裹」）。
let block_arm_width : Double = 10.0

///|
/// **画布局部 y → 链条 y** 的换算：绘制与命中**共用这一个函数**。
///
/// 为什么必须抽出来：说明横幅会把积木链整体下移 `note_height`，于是
/// 「画在哪里」与「点在哪里」之间多了一个偏移。两处各写一遍的后果是
/// **点击落到所点那块上方的块**（或落空），而且**只在有说明时**才出现
/// ——没说明时一切正常，不带说明的用例永远发现不了。
///
/// 推导（`y_offset = 0` 时）：
/// - 绘制：`dy = frame.y + note_height`，所以链坐标 `c` 渲染在
///   `frame.y + note_height + c`；
/// - 点击：用户点在那个可见位置，`local = position.y - frame.y
///   = note_height + c`；
/// - 求逆：`c = local - note_height`。
///
/// **是减不是加**。写成加会得到一个偏下 `2 × note_height` 的链坐标，
/// 于是点击落到所点那块**下方**的块——而且只在有说明时出现。
pub fn blocks_chain_y(
  local_y : Double,
  y_offset : Double,
  note_height : Double,
) -> Double {
  local_y - note_height + y_offset
}

///|
/// 脚本说明横幅的高度（含上下间距）。
///
/// 由调用方（`blocks_pane`）同时用于「画布高度」与「积木链下移量」，
/// 常量放这里保证两处同源。
pub const BLOCKS_NOTE_HEIGHT : Double = 22.0

///|
/// 拖拽时触发自动滚动的边缘带高度：指针进入画布上/下 24pt 内即开始滚动。
pub const BLOCKS_EDGE_ZONE : Double = 24.0

///|
/// 按可用宽度把标签截成「…」结尾（设计稿 `.blk` 的 `text-overflow: ellipsis`）。
///
/// 逐字符累加而不是按平均字宽估算：块标签是中英混排
/// （`命令 set_text(显示, "你好，MoUI Studio！")`），中英字宽差近一倍，
/// 用平均值会算出「刚好放下」然后仍然溢出几个字符。
/// 口径与 `text_estimate_width` 一致（ASCII 7.9 / 全角 13.0），并留
/// `WIDTH_SAFETY` 的余量：实测估算比实渲**偏窄约 2%**（「…悬停积木…」
/// 估算 294.4、实渲 300.8）。曾按 98% 截断——2% 余量被估算误差吃穿后
/// 仍会越界（1100 宽窗格实测超出裁剪区 5px），收紧到 95%：宁可早切
/// 一到两个字，也不要越界半个字。
///
/// 两个已踩过的坑：
/// ① 曾按 `12/13` 折算字号（以为文字按 12pt 渲染）——实际主题正文是
///    16pt，凭空折算让预算**虚高 8%**，截断了却仍然溢出；
/// ② 只截断不预留余量，2% 的估算误差在长句上就是 5-6pt 的越界。
pub const LABEL_WIDTH_SAFETY : Double = 0.95

///|
pub fn fit_label(label : String, max_width : Double) -> String {
  let budget = max_width * LABEL_WIDTH_SAFETY
  let full = text_estimate_width(label)
  if full <= budget {
    return label
  }
  // 省略号本身也要占位（全角，13.0 @13pt）
  let ellipsis_cost = text_estimate_width("…")
  let mut used = 0.0
  let mut kept = ""
  for c in label {
    let cost = if c.to_int() < 0x80 { 7.9 } else { 13.0 }
    if used + cost + ellipsis_cost > budget {
      break
    }
    used = used + cost
    kept = kept + c.to_string()
  }
  kept + "…"
}

///|
/// C 形块（控制流「包裹」形态）的几何：哪一行是 C 的**顶**，它的弧要拉多高。
///
/// Scratch 的核心视觉语义是「C 形包裹」：`如果/重复/当` 的块体向下包住
/// 它自己的子栈，子栈因此看起来**在里面**，而不是靠缩进「大概在里面」。
///
/// **为什么是纯视图**：`BlockItem` 是扁平链 + `depth`，控制流被展开成
/// `if → 子栈 → elseIf/else → 子栈 → end` 的兄弟序列。C 的边界可以从这个
/// 序列**推导**出来（不需要 IR 或投影改动）：
/// - 顶 = `BkIf / BkElseIf / BkElse / BkCountLoop / BkWhile`；
/// - 底 = 下一个**同深度**的装饰块（`BkElseIf / BkElse / BkEnd`——
///   它们的 `path` 为空，是既有的「装饰块没有对应语句」标记）；
/// - `end` 是最后一个 C 的收尾，`elseIf/else` 同时收上一个 C、开下一个。
///
/// 返回 `(行下标 → 壁长)`，即该顶块要向下延伸多少才够包住子栈。
/// 逐个头块找**最近的**同深度装饰块：`if` 与它后面的 `elseIf` 各自成 C，
/// 各由自己的收尾行结束。
///
/// **顶块本身保持一行高**（它是 C 的「帽」），壁负责从帽底拉到收尾块顶边
/// ——「帽 + 左壁 + 底口」才是 Scratch 的 C 形。早先的实现改成把**顶块矩形
/// 拉高**去包住子栈，于是顶块的填充盖住了子行的上半部分（实测顶块
/// 10..130 覆盖了子行 50..124），子块看着像陷进父块里。
///
/// `rects` 只读 `origin.y`（各行的顶边不因扩张而变），所以传基础矩形或
/// 视觉矩形都得到同一结果。
pub fn blocks_c_arms(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
) -> Map[Int, Double] {
  let arms : Map[Int, Double] = Map([])
  let mut i = 0
  while i < blocks.length() {
    let head = blocks[i]
    let is_head = match head.kind {
      @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkCountLoop |
      @blocks.BkWhile => true
      _ => false
    }
    if is_head && i < rects.length() {
      // 找同深度的下一个装饰块（else-if / else / end）
      let mut j = i + 1
      let mut terminator = blocks.length()
      while j < blocks.length() {
        let item = blocks[j]
        if item.depth == head.depth &&
          (item.kind is @blocks.BkElseIf ||
            item.kind is @blocks.BkElse ||
            item.kind is @blocks.BkEnd) {
          terminator = j
          break
        }
        j = j + 1
      }
      // 弧高 = 顶块**基础底边**到收尾块**顶边**的距离。
      //
      // 基础底边用常量 `block_height` 算，**不**用 `rects[i].size.height`：
      // 传入的 rects 可能是已扩张的视觉矩形（顶行被拉高），用它会把上一段
      // 弧叠进来。所有基础行都是 `block_height` 高（`blocks_item_rects`
      // 恒设），所以 `origin.y + block_height` 在两种 rects 下都成立。
      // **只依赖 origin.y**（扩张不改顶边），函数因此对两种输入都安全。
      let head_bottom = rects[i].origin.y + block_height
      let terminator_top = if terminator < rects.length() {
        rects[terminator].origin.y
      } else {
        head_bottom
      }
      arms[i] = (terminator_top - head_bottom).max(0.0)
    }
    i = i + 1
  }
  arms
}

///|
/// 把基础行矩形调成**视觉矩形**：给 C 的子行右缩，让 C 的右墙看得见。
///
/// 这里**不再拉高顶块**。早先的实现把顶块矩形拉高去「包住」子栈，结果顶块
/// 自己的填充盖住了子行的上半部分（实测顶块 10..130 覆盖了子行 50..124），
/// 子块看着像陷进父块里。正确的 C 形由三段拼成：
///
/// - **帽** = 顶块本身（一行高，正常绘制）；
/// - **左壁** = `BlockArm`（从帽底拉到收尾块顶边，见 `blocks_c_arms`）；
/// - **底口** = 收尾块（`end` / `else` / `elseIf` 自己那一行）。
///
/// 所以视觉矩形与基础矩形只差**子行的右缩**这一件事——高度完全不动。
/// 缩进是「在里面」的第二个信号（第一个是左壁）。
///
/// 右缩必须对**同一个体内的所有行**生效。判据不能是「向上第一个更浅的行
/// 是 C 头就返回」——同层兄弟会提前短路（实测子栈里只有第一行被缩、
/// 第二行没有）。见 `blocks_in_c_body`。
pub fn blocks_visual_rects(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
) -> Array[@geometry.Rect] {
  let out : Array[@geometry.Rect] = []
  let mut i = 0
  for r in rects {
    let inset = if blocks_in_c_body(blocks, i) {
      block_arm_width
    } else {
      0.0
    }
    out.push(
      @geometry.Rect::new(
        x=r.origin.x,
        y=r.origin.y,
        width=(r.size.width - inset).max(40.0),
        height=r.size.height,
      ),
    )
    i = i + 1
  }
  out
}

///|
/// 第 `index` 行是否在某个 C 形块的**体内**。
///
/// 判据：**向上跨过所有同层兄弟**（它们与自己在同一个体内，不该短路），
/// 直到遇到一个更浅的行；那一行是 C 头（`if/elseIf/else/loop/while`）就
/// 说明本行在它的体内。
///
/// 早先的实现在遇到**第一个同层行**时就返回 false——于是子栈里只有紧邻
/// 头块的那一行被缩进，其余同层兄弟全都不缩（实测第一子行 w=416、
/// 第二子行 w=426）。「同层」恰恰是「同一个体内的兄弟」，不是「不在体内」。
pub fn blocks_in_c_body(blocks : Array[@blocks.BlockItem], index : Int) -> Bool {
  if index <= 0 || index >= blocks.length() {
    return false
  }
  let depth = blocks[index].depth
  let mut j = index - 1
  while j >= 0 {
    let item = blocks[j]
    if item.depth < depth {
      // 找到所属的父层：它是 C 头才算「在体内」
      return match item.kind {
        @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkCountLoop |
        @blocks.BkWhile => true
        _ => false
      }
    }
    j = j - 1
  }
  false
}

///|
/// 语句链逐项矩形（顺序即链条顺序；x 随深度缩进）。
/// 积木行矩形。`avail_width` 是画布可用宽：**必须传**（默认值是历史常量，
/// 只在没有视口信息的纯逻辑测试里用）。
///
/// **块宽随内容**（Scratch 口径）：每行的宽度由展示文本估宽决定，不再
/// 撑满画布（用户报的「积木左右撑满了」）。估宽与 `fit_label` 同一把尺
/// （`text_estimate_width`），除以 `LABEL_WIDTH_SAFETY` 抵消 fit_label 的
/// 安全系数——否则「按估宽定的块」会被 fit_label 再截一次（估宽刚好等于
/// 预算时省略号照样出现）。上限仍是画布预算：超长语句照旧截成省略号，
/// 下限 64 保证小积木（如「结束」帽）仍有可点的命中区。
///
/// `display_texts` 是**绘制侧展示文本**（本地化标签 + 语句文本）。宽度
/// 从它算，命中侧就必须传同一份——两处各算一份宽度，「画的块」与「命中
/// 的块」会错开一截。缺省（纯逻辑测试）按 `item.text` 估，几何自洽。
pub fn blocks_item_rects(
  blocks : Array[@blocks.BlockItem],
  avail_width? : Double = block_width,
  display_texts? : Array[String] = [],
) -> Array[@geometry.Rect] {
  let rects : Array[@geometry.Rect] = []
  // 预算下限必须**不超过可用宽**：下限高于画布可用宽时块体本身就越出
  // 画布（实测 1100 窗口下画布 155、下限 160，块文字越出裁剪区 5px）。
  // 下限只防「画布极窄时块缩成 0」——取可用宽与 160 的较小者，再兜底 80。
  let budget = (avail_width - block_margin * 2.0).max(
    (avail_width * 0.5).max(80.0).min(160.0),
  )
  for item in blocks {
    let x = block_margin + item.depth.to_double() * block_indent
    let display = if rects.length() < display_texts.length() {
      display_texts[rects.length()]
    } else {
      item.text
    }
    // 行首内边距：条件块先画一枚徽标（占 28pt），其余 10pt。
    // 与 `blocks_draw_plan` 的 label_x 偏移同一口径（两处各算会错位）。
    let lead_pad = match item.kind {
      @blocks.BkIf | @blocks.BkElseIf | @blocks.BkWhile => 28.0
      _ => 10.0
    }
    // 内容宽 = 内边距 + 展示文本估宽（含返回箭头前缀）÷安全系数 + 右缘余量。
    // 估宽偏窄 ~2%（见 `fit_label` 的注释），除以安全系数后实渲必然放得下。
    let prefix = if item.kind is @blocks.BkReturn { "↩ " } else { "" }
    let content = lead_pad +
      text_estimate_width("\{prefix}\{display}") / LABEL_WIDTH_SAFETY +
      12.0
    let max_width = (budget - item.depth.to_double() * block_indent).max(64.0)
    let width = content.min(max_width).max(64.0)
    rects.push(
      @geometry.Rect::new(
        x~,
        y=block_margin + rects.length().to_double() * block_step,
        width~,
        height=block_height,
      ),
    )
  }
  rects
}

///|
/// 命中测试：返回压点所在行（链条下标），无命中返回 -1。
///
/// `avail_width` 与 `display_texts` **必须与绘制侧同值**（画布可用宽 +
/// 展示文本）：绘制用真实宽算块体，命中用不同的宽/文本就会在「块右缘 →
/// 旧默认宽」那段空白里误判命中，或把块内点击判到块外。默认值只服务
/// 没有视口信息的纯逻辑测试。
pub fn blocks_hit_index(
  blocks : Array[@blocks.BlockItem],
  x : Double,
  y : Double,
  avail_width? : Double = block_width,
  display_texts? : Array[String] = [],
) -> Int {
  let rects = blocks_visual_rects(
    blocks,
    blocks_item_rects(blocks, avail_width~, display_texts~),
  )
  let mut i = rects.length()
  while i > 0 {
    i = i - 1
    let r = rects[i]
    if x >= r.origin.x &&
      x <= r.origin.x + r.size.width &&
      y >= r.origin.y &&
      y <= r.origin.y + r.size.height {
      return i
    }
  }
  -1
}

///|
pub fn blocks_parent_of(path : Array[Int]) -> Array[Int] {
  let parent : Array[Int] = []
  let mut i = 0
  while i < path.length() - 1 {
    parent.push(path[i])
    i = i + 1
  }
  parent
}

///|
pub fn blocks_same_path(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 落槽计算：同层兄弟中，中心线在指针上方的个数（0..=兄弟数）。
/// 只在拖拽块的兄弟层内计数——跨层移动不在 v1 范围。
pub fn blocks_drop_slot(
  blocks : Array[@blocks.BlockItem],
  list_path : Array[Int],
  pointer_y : Double,
  rects : Array[@geometry.Rect],
) -> Int {
  let mut slot = 0
  let mut i = 0
  for item in blocks {
    if blocks_same_path(blocks_parent_of(item.path), list_path) {
      let r = rects[i]
      if r.origin.y + r.size.height / 2.0 <= pointer_y {
        slot = slot + 1
      }
    }
    i = i + 1
  }
  slot
}

///|
/// 落点所在的**语句列表路径**：指针 `pointer_y` 停在哪个容器里。
///
/// Scratch 的「拖进洞里」：指针停在某个 C 形头（`if/重复/当`）的行上时，
/// 落点是**它的体内**（头块的 then 体路径 = 头语句路径 ++ `[0]`）；否则
/// 落点与源同层（同层重排）。
///
/// 判据用「指针落在头的**下半行**」而不是整行：头的上半部分属于「插到它
/// 前面」，下半部分才是「放进它里面」——与 Scratch 的命中区一致，也让
/// 「插在 if 前」与「放进 if 里」两个意图可以分别表达。
pub fn blocks_drop_list_of(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
  pointer_y : Double,
  fallback : Array[Int],
) -> Array[Int] {
  let mut i = 0
  for item in blocks {
    let r = rects[i]
    let mid = r.origin.y + r.size.height / 2.0
    // 指针落在该行的下半部分
    if pointer_y >= mid && pointer_y <= r.origin.y + r.size.height {
      // 是 C 形头 → 落进体内
      let is_head = match item.kind {
        @blocks.BkIf | @blocks.BkCountLoop | @blocks.BkWhile => true
        _ => false
      }
      if is_head && item.path.length() > 0 {
        // 体内路径：头语句路径 ++ [0]（If 的 then / 循环的循环体）
        let body_list : Array[Int] = []
        for part in item.path {
          body_list.push(part)
        }
        body_list.push(0)
        return body_list
      }
    }
    i = i + 1
  }
  // 指针落在**所有行之外**（画布下方空白）：目标是**顶层末尾**，不是源列表。
  //
  // 这里曾经回落成 `fallback`（= 源列表），对嵌套在循环里的块就是**循环体
  // 本身**——于是「拖到空白处」被当成「留在循环里」，`break` 这类只能在
  // 特定容器里的语句会被错误放行。空白处按 Scratch 语义是「放到最外层末尾」。
  if pointer_y > 0.0 && blocks.length() > 0 {
    let last = rects[rects.length() - 1]
    if pointer_y > last.origin.y + last.size.height {
      let top : Array[Int] = []
      return top
    }
  }
  fallback
}

///|
/// 落槽指示线（**链条坐标**）：拖拽中按同层兄弟中心线算出插入位置，
/// 返回 (y, 宽)。从绘制计划里提出来——画布在选中块处拆成两段后，「插在
/// 哪里」是链条坐标的事实，由调用方一次性算好、再按段换算成本地坐标
/// 下发；绘制层只画，不再自己解释拖拽态（两段各自用子集矩形推槽位，
/// 跨段的兄弟列表会算错位置）。
///
/// 返回 `(y, 宽, 是否有效)`。
///
/// 三条纪律，都由实测暴露：
///
/// 1. **按落点列表 `to_list` 算，不是源列表 `list_path`**——跨层拖拽
///    （拖进 C 形块的洞里）时，指示线必须出现在**目标容器**的兄弟之间；
///    用源列表算会让线画在原来的位置上（用户看到「插回原处」的假反馈）。
/// 2. **子块宽度要减右缩**：C 体内的行被 `blocks_visual_rects` 收窄了
///    `block_arm_width`，线跟着收窄才与目标行对齐。
/// 3. **无效落点用不同颜色**（`valid == false`）：Scratch 在放不进去时
///    不给插入线，这里给一条**红色**线——比「什么都不画」更明确
///    （否则用户以为拖拽坏了）。
pub fn blocks_insert_mark(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
  drag : BlocksDragState?,
) -> (Double, Double, Bool)? {
  match drag {
    None => None
    Some(d) => {
      // 目标列表**就是 `to_list`**，不要按「空数组」回落到源列表——
      // 空数组是**顶层**这个合法目标（Scratch 里拖到最外层是最常见的动作）。
      // 回落会让「拖到顶层」把线画在源容器（可能是某个 C 形体内）的位置上，
      // 与松手后的真实落点不符。
      // 按下时 `to_list` 已初始化为 `list_path`，所以它始终有意义。
      let target = d.to_list
      let mut mark_y : Double? = None
      let mut mark_w : Double = 300.0
      let mut seen = 0
      let mut i = 0
      for item in blocks {
        if blocks_same_path(blocks_parent_of(item.path), target) {
          let r = rects[i]
          mark_w = r.size.width
          if seen == d.to {
            mark_y = Some(r.origin.y - 3.0)
          }
          seen = seen + 1
        }
        i = i + 1
      }
      if seen == d.to && seen > 0 {
        // 落到最后一个兄弟之后：线画在其底缘下方
        let mut i2 = 0
        for item in blocks {
          if blocks_same_path(blocks_parent_of(item.path), target) {
            let r = rects[i2]
            mark_y = Some(r.origin.y + r.size.height + 3.0)
          }
          i2 = i2 + 1
        }
      }
      // **空容器**：目标列表一条语句都没有（如刚插入的「如果」的 then 体）。
      // 这是 Scratch 最经典的手势——把块拖进空着的洞里——但按兄弟扫描算不出
      // 任何 y（`seen == 0`），早先的 `seen > 0` 守卫会让它返回 `None`，
      // 于是**拖进空体时完全没有插入线**，用户以为拖不进去。
      //
      // 空容器没有「兄弟」可参照，改为锚在**容器头**上：头是那条拥有这个
      // 列表的语句（`target` 去掉最后一段就是它的路径），线画在头的底缘下方
      // ——正是空体的第一行该出现的位置。
      if seen == 0 && d.to == 0 && target.length() > 0 {
        let owner_path : Array[Int] = []
        let mut k = 0
        while k < target.length() - 1 {
          owner_path.push(target[k])
          k = k + 1
        }
        let mut i3 = 0
        for item in blocks {
          if blocks_same_path(item.path, owner_path) {
            let r = rects[i3]
            mark_y = Some(r.origin.y + r.size.height + 3.0)
            mark_w = r.size.width
          }
          i3 = i3 + 1
        }
      }
      match mark_y {
        Some(y) => Some((y, mark_w, d.valid))
        None => None
      }
    }
  }
}

///|
/// 拼图块绘制计划：逐块 = 体 + 文本 +（同层连续时）顶部榫头与底部卯口 +
/// 选中/聚光灯描边 + 落槽指示线。display_texts 与 blocks 一一对应
/// （控制流块的本地化标签由调用方预渲染，draw 闭包拿不到翻译器）。
/// `insert_mark` 是**本画布本地坐标**的指示线（调用方已按段换算）。
///|
/// 文本宽度度量：绘制计划**注入**它而不是自己拿 `TextSystem`——
/// 计划函数是纯的（便于单测），而 `TextSystem` 只在布局上下文里。
/// 默认实现返回 0（不画插槽），这样既有的无度量调用方行为不变。
pub fn no_text_measure(_text : String) -> Double {
  0.0
}

///|
/// 行首箭头前缀：返回块画「↩ 」——「离开子程序」的方向感。
/// 标签与插槽洞的引导宽度都由它拼出（两处各写一份条件就会错位）。
fn blocks_row_arrow(item : @blocks.BlockItem) -> String {
  if item.kind is @blocks.BkReturn { "↩ " } else { "" }
}

///|
/// 一行的**插槽引导宽度**：洞的游标从「标签起始 x + 引导宽」开始累加段宽。
/// 引导 = 箭头前缀 + 本地化标签与分隔空格（`lead_texts`，与展示文本同源
/// 产出）。绘制（`push_slot_holes`）与命中（`blocks_slot_hit`）都走这里。
fn blocks_row_lead_width(
  item : @blocks.BlockItem,
  lead_text : String,
  measure : (String) -> Double,
) -> Double {
  measure("\{blocks_row_arrow(item)}\{lead_text}")
}

///|
pub fn blocks_draw_plan(
  blocks : Array[@blocks.BlockItem],
  display_texts : Array[String],
  rects : Array[@geometry.Rect],
  selected : Int,
  spotlight : String,
  insert_mark : (Double, Double, Bool)?,
  dx : Double,
  dy : Double,
  measure? : (String) -> Double = no_text_measure,
  lead_texts? : Array[String] = [],
) -> Array[BlocksDrawOp] {
  let ops : Array[BlocksDrawOp] = []
  // C 左壁的长度 = **视觉高 − 基础行高**。不另算一份弧高：`blocks_visual_rects`
  // 已经把它加进了 `h`，这里减回去就是壁长。两处各算一份就会分叉
  // （画布上的壁与矩形对不上）。
  //
  // 基础行高只能从**基础矩形**取，所以这里要拿到同一组基础矩形。调用方
  // （`blocks_canvas`）传进来的 `rects` 是视觉矩形，其中行距与基础行距
  // 相同（只有顶行被拉高），所以「基础行高」用常量 `block_height` 即可——
  // 不需要重算整组矩形（重算就要再传一次 avail_width，多一个可漂移的入参）。
  // `rects` 此处是**视觉**矩形（顶行已拉高）；`blocks_c_arms` 只读各行的
  // `origin.y`（扩张不改顶边），所以传视觉矩形同样得到正确的弧高。
  let arms = blocks_c_arms(blocks, rects)
  match insert_mark {
    // 无效落点画成**红色拒收线**（比「什么都不画」明确：用户不会以为
    // 拖拽坏了）。有效落点是强调色插入线。
    Some((y, w, valid)) =>
      ops.push(InsertMark(dx + 10.0, dy + y, w, valid))
    None => ()
  }
  let mut i = 0
  for item in blocks {
    let r = rects[i]
    let x = r.origin.x + dx
    let y = r.origin.y + dy
    let w = r.size.width
    let h = r.size.height
    let display = if i < display_texts.length() { display_texts[i] } else { "" }
    let is_selected = i == selected
    // 聚光灯只画描边（`BlockStroke`），不再加「▶ 」文字前缀：块宽现在
    // 随内容收紧，前缀会把高亮行挤出一个省略号（运行态文字跳变）。
    let is_spotlight = item.text != "" && item.text == spotlight
    ops.push(BlockBody(x, y, w, h, item.kind))
    // 榫头：本块在列表中不是第一条才画——首块的上一项是父块（新栈开始）
    if item.path.length() > 0 && item.path[item.path.length() - 1] > 0 {
      ops.push(BlockTab(x + 20.0, y - 5.0, 18.0, item.kind))
    }
    // 卯口：底边中央挖去画布底色，下一块的榫头插进来
    if item.path.length() > 0 {
      ops.push(BlockNotchCut(x + 20.0, y + h - 1.0))
    }
    // **C 形左壁**：从顶块（帽）底边向下拉到收尾块顶边。帽本身保持一行高，
    // 壁与收尾块一起把子栈围成 C——「帽 + 左壁 + 底口」三段，缺一段就读成
    // 普通缩进。壁色跟顶块 kind（否则会读成另一块积木）。
    if item.depth >= 0 {
      match arms.get(i) {
        Some(len) =>
          if len > 0.0 {
            ops.push(
              // +2：壁的起点比帽底高 2pt（与帽重叠，接缝不露线），
              // 终点同理多伸 2pt 去接收尾块顶边——否则壁与底口之间
              // 会留一条 2pt 的缝，「包裹」就读断了。
              BlockArm(x, y + h - 2.0, block_arm_width, len + 2.0, item.kind),
            )
          }
        None => ()
      }
    }
    // 条件块（如果/否则如果/当）：标签前一枚「六角宝石」徽标——
    // 取值分支的视觉锚点（真实六角需要多边形绘制，圆角近似同位）。
    let badge = match item.kind {
      @blocks.BkIf | @blocks.BkElseIf | @blocks.BkWhile => {
        ops.push(BlockBadge(x + 8.0, y + 10.0, item.kind))
        true
      }
      _ => false
    }
    let label_x = if badge { x + 28.0 } else { x + 10.0 }
    // 标签按**块宽**截断（设计稿 .blk 是 `text-overflow: ellipsis` 口径）：
    // 块宽随内容收紧后，只有顶到画布预算的长语句才会截——用省略号收尾，
    // 让「这里有更多内容」是**看得见**的，而不是被画布边缘硬切掉一半。
    // 文字**左对齐**（TextStart）：插槽洞的游标正是从 label_x 起按段宽
    // 累加的，居中会让洞与字形整个错开（实测「如果」块上孤零零一枚黑洞）。
    let label_text = "\{blocks_row_arrow(item)}\{display}"
    let label_max = (w - (label_x - x) - 10.0).max(40.0)
    // **插槽凹槽**（reporter slot）：文本里可再塞一块积木的位置。
    //
    // 截断判定用**注入的真实度量**（与洞的位置同一把尺）。度量缺席（全 0）
    // 时保守跳过：宁可少画，也不要画在字形之外。
    // **洞必须画在文字之下**：先推洞、再推标签——绘制按 ops 顺序叠层，
    // 反过来洞会把字形盖掉（「洞里有字」读成「字被黑洞吃了」）。
    let measured_label = measure(label_text)
    let not_truncated = measured_label <= 0.0 ||
      measured_label <= label_max * LABEL_WIDTH_SAFETY
    if not_truncated {
      push_slot_holes(
        ops,
        blocks[i],
        label_x,
        y + 8.0,
        label_max,
        measure,
        blocks_row_lead_width(
          item,
          if i < lead_texts.length() { lead_texts[i] } else { "" },
          measure,
        ),
      )
    }
    ops.push(
      BlockLabel(
        label_text,
        label_x,
        y + 8.0,
        label_max,
        fit_label(label_text, label_max),
      ),
    )
    if is_selected || is_spotlight {
      ops.push(BlockStroke(x, y, w, h))
    }
    i = i + 1
  }
  ops
}

///|
pub(all) enum BlocksDrawOp {
  BlockBody(Double, Double, Double, Double, @blocks.BlockKind)
  /// C 形块的左壁：`(x, y, w, h, kind)`——从顶块底边向下延伸包住子栈。
  /// `kind` 决定壁色（与顶块同色，否则「包裹」会读成另一块积木）。
  BlockArm(Double, Double, Double, Double, @blocks.BlockKind)
  BlockBadge(Double, Double, @blocks.BlockKind)
  BlockTab(Double, Double, Double, @blocks.BlockKind)
  BlockNotchCut(Double, Double)
  BlockLabel(String, Double, Double, Double, String)
  /// 脚本说明横幅：`(文本, x, y, 宽)`。画在积木链**上方**。
  ///
  /// 为什么画在画布上而不是只放右栏：Scratch 的「给这段脚本加注释」是
  /// **贴在积木旁边**的——用户读代码时看到它。只在右栏显示的话，读代码
  /// 的人根本看不到说明，那这条注释就失去了意义。
  ScriptNote(String, Double, Double, Double)
  BlockStroke(Double, Double, Double, Double)
  InsertMark(Double, Double, Double, Bool)
  /// 插槽（reporter slot）的圆角凹槽：`(x, y, w, h, 是否有内容)`。
  /// 画在字形之下，读作「这里可以塞一块积木」。
  SlotHole(Double, Double, Double, Double, Bool)
}

///|
/// 逐段累加宽度，为**插槽段**产出凹槽矩形。
///
/// 段宽来自注入的 `measure`；`lead` 是**引导宽**（标签起始 x 到第一段
/// 字形的距离 = 箭头前缀 + 本地化标签宽，见 `blocks_row_lead_width`）。
/// 此前这里自己减「前缀宽」推游标，与命中层各算一份——两处一起偏，
/// 只测一边的用例发现不了。
///
/// 该函数按「行矩形 + 徽标占位」推 label_x = rect.x + (28 | 10)。
/// 这里的 `label_x` 已是绘制坐标，所以反推一个等价的行矩形交给它，
/// 避免把徽标判定再写一遍（写两遍就会分叉）。
fn push_slot_holes(
  ops : Array[BlocksDrawOp],
  item : @blocks.BlockItem,
  label_x : Double,
  label_y : Double,
  label_max : Double,
  measure : (String) -> Double,
  lead : Double,
) -> Unit {
  let badge = match item.kind {
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkWhile => true
    _ => false
  }
  let row_x = label_x - (if badge { 28.0 } else { 10.0 })
  let row = @geometry.Rect::new(
    x=row_x,
    y=label_y - 6.0,
    width=label_max + 40.0,
    height=20.0,
  )
  for entry in blocks_slot_rects(item, row, measure, lead~) {
    let hole = entry.1
    if hole.origin.x + hole.size.width <= label_x + label_max {
      ops.push(
        SlotHole(
          hole.origin.x,
          hole.origin.y,
          hole.size.width,
          hole.size.height,
          measure(entry.0.text) > 0.0,
        ),
      )
    }
  }
}

///|
/// 画布视图：绘制 + 点选/拖拽事件转 typed Msg。
/// `y_offset`：本段画布在**链条坐标**里的纵向原点。编辑卡把链条拆成
/// 上下两段后，下段画布的本地 y 要加上偏移才能与 update 里的链条矩形
/// （命中/落槽计算空间）对齐；整链画布传 0 即可。
pub fn blocks_canvas(
  blocks : Array[@blocks.BlockItem],
  display_texts : Array[String],
  selected : Int,
  spotlight : String,
  insert_mark : (Double, Double, Bool)?,
  width : Double,
  height : Double,
  semantics_label : String,
  y_offset? : Double = 0.0,
  palette_drag? : Bool = false,
  expr_drag? : Bool = false,
  script_note? : String = "",
  note_height? : Double = 0.0,
  lead_texts? : Array[String] = [],
) -> @moui.View[Msg] {
  // 文本度量：**布局期**量好、**绘制期**取用。
  //
  // 为什么必须跨这两个阶段：插槽洞的位置 = 前面所有段的宽度之和，而
  // 段宽只有 `TextSystem` 能给；`TextSystem` 挂在**布局上下文**上，
  // 绘制回调拿到的 `PaintContext` 刻意只装绘制指令（框架设计如此），
  // 量不了文本。所以用一格共享单元把结果从布局带到绘制——这也是
  // `measured_canvas` 存在的理由。
  let metrics : Ref[Map[String, Double]] = Ref(Map([]))
  @views.container(
    @views.measured_canvas(
      measure=fn(_constraints, text_system) {
        // 量本画布会用到的所有段（字面段 + 插槽段）、标签前缀与整行标签。
        // 逐段量而不是量整行：洞的位置正是逐段宽度的累加；整行与引导文本
        // 也要量——截断判定（`not_truncated`）与洞的起点（引导宽）读它们。
        let cache : Map[String, Double] = Map([])
        let measure_into = fn(text : String, cache : Map[String, Double]) {
          if !cache.contains(text) {
            let font = @text.FontSpec::new(size=12.0)
            let measured = text_system.measure_text(
              @core.TextLayoutInput::new(text~, font~),
            )
            cache[text] = measured.size.width
          }
        }
        let mut index = 0
        for item in blocks {
          match item.segments {
            None => ()
            Some(segments) =>
              for segment in segments {
                measure_into(segment.text, cache)
              }
          }
          // 引导文本（箭头前缀 + 本地化标签）：洞的起点 = 它的宽度
          let lead_text = if index < lead_texts.length() {
            lead_texts[index]
          } else {
            ""
          }
          measure_into("\{blocks_row_arrow(item)}\{lead_text}", cache)
          // 整行标签：截断判定的实尺
          let display = if index < display_texts.length() {
            display_texts[index]
          } else {
            ""
          }
          measure_into("\{blocks_row_arrow(item)}\{display}", cache)
          index = index + 1
        }
        metrics.val = cache
        // 宽度必须由调用方给定：scroll_view 给子节点的是无界约束
        // （纵向滚动、横向不滚），画布自己量不出视口宽——写死 470 会
        // 在窄窗格里溢出到隔壁面板。高度不设下限（旧的 160pt 下限是给
        // 整链画布的；编辑卡拆段后上段只有 ~50pt，下限会在块与编辑卡
        // 之间凭空垫出一段空白），调用方传的高度就是段的真实高度。
        @geometry.Size::new(width=width.max(160.0), height=height.max(1.0))
      },
      draw=fn(ctx, frame) {
        let dx = frame.origin.x
        // 有说明横幅时，积木链整体**下移** `note_height`，让横幅占住
        // 上方预留的空间（而不是叠在第一块积木上）。
        // 链坐标 → 画布局部：减去横幅偏移（`blocks_chain_y` 的逆）。
        let dy = frame.origin.y + note_height
        let base = blocks_item_rects(blocks, avail_width=width, display_texts~)
        // C 形包裹：顶行的矩形向下扩张，把子栈**包在里面**（Scratch 的核心
        // 视觉语义）。绘制用扩张后的矩形，落槽仍用基础行高——插入位置按
        // 「行」算，视觉包裹按「弧」算，两者刻意分开。基础矩形只算一次。
        let rects = blocks_visual_rects(blocks, base)
        let cache = metrics.val
        let measure = fn(text : String) -> Double {
          match cache.get(text) {
            Some(value) => value
            None => 0.0
          }
        }
        let ops = blocks_draw_plan(
          blocks,
          display_texts,
          rects,
          selected,
          spotlight,
          insert_mark,
          dx,
          dy,
          measure~,
          lead_texts~,
        )
        // **脚本说明横幅**：画在积木链上方（Scratch 的脚本注释贴在积木旁）。
        // 只在有说明时占位——空说明不画，否则每条子程序上方都会有一条
        // 空白带，把画布本来就不多的空间吃掉。
        // `note_height` 是调用方为横幅**预留**的高度：积木链整体下移，
        // 横幅画在空出来的上方。不用「画在积木上」的做法——那会遮住第一块
        // 积木的文本。调用方（`blocks_pane`）把同一数值加进画布高度，
        // 两处一致才不会让横幅被裁掉或与积木重叠。
        if script_note != "" {
          ops.push(
            ScriptNote(
              fit_label(script_note, (width - 24.0).max(60.0)),
              dx + 10.0,
              dy + 2.0,
              (width - 24.0).max(60.0),
            ),
          )
        }
        for op in ops {
          match op {
            BlockBody(x, y, w, h, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=h),
                  radius=block_corner_radius(kind),
                ),
                @graphics.Brush::solid(block_fill(kind)),
              )
            BlockArm(x, y, w, h, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=h),
                  radius=2.0,
                ),
                @graphics.Brush::solid(block_fill(kind)),
              )
            BlockBadge(x, y, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=14.0, height=14.0),
                  radius=4.0,
                ),
                @graphics.Brush::solid(block_badge_color(kind)),
              )
            BlockTab(x, y, w, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=7.0),
                  radius=2.0,
                ),
                @graphics.Brush::solid(block_fill(kind)),
              )
            BlockNotchCut(x, y) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=18.0, height=6.0),
                  radius=2.0,
                ),
                @graphics.Brush::solid(block_notch_color()),
              )
            BlockLabel(_text, x, y, maxw, fitted) =>
              // **左对齐**：插槽洞的游标从 frame.x 起按段宽累加，文字居中
              // 会让洞与字形整个错开（实测「如果」块上孤零零一枚黑洞——
              // 用户报的「积木上的黑块」）。
              draw_text(
                ctx,
                @text.TextRun::new(
                  text=fitted,
                  frame=@geometry.Rect::new(x~, y~, width=maxw, height=20.0),
                  font=@text.FontSpec::new(size=12.0),
                  color=block_text_color(),
                  align=TextStart,
                ),
              )
            BlockStroke(x, y, w, h) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=x - 2.0,
                    y=y - 2.0,
                    width=w + 4.0,
                    height=h + 4.0,
                  ),
                  radius=8.0,
                ),
                @graphics.Brush::solid(ide_accent()),
                2.0,
              )
            InsertMark(x, y, w, valid) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x~,
                    y~,
                    width=w,
                    height=if valid { 3.0 } else { 2.0 },
                  ),
                  radius=1.5,
                ),
                @graphics.Brush::solid(
                  if valid { ide_accent() } else { ide_danger() },
                ),
              )
            ScriptNote(text_value, x, y, w) =>
              // 说明用**斜体式的弱化色**画在浅底上，与积木文本区分开：
              // 注释不该和代码抢注意力（Scratch 的注释也是灰底灰字）。
              {
                fill_rounded_rect(
                  ctx,
                  @graphics.RoundedRect::new(
                    rect=@geometry.Rect::new(x~, y~, width=w, height=16.0),
                    radius=3.0,
                  ),
                  @graphics.Brush::solid(blocks_note_background()),
                )
                draw_text(
                  ctx,
                  @text.TextRun::new(
                    text=text_value,
                    frame=@geometry.Rect::new(x~, y~, width=w, height=16.0),
                    font=@text.FontSpec::new(size=11.0),
                    color=blocks_note_text(),
                  ),
                )
              }
            SlotHole(x, y, w, h, filled) =>
              // 插槽：**浅色内凹**读作「这里可以塞一块积木」。
              // 有内容时底色更亮一点（内容块坐上去），空槽更暗（等一块进来）。
              // 颜色取自画布栈的既有色阶，不新引入 token——插槽是积木的
              // 内部结构，不是独立表面。
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=h),
                  radius=6.0,
                ),
                @graphics.Brush::solid(
                  if filled { blocks_slot_filled() } else { blocks_slot_empty() },
                ),
              )
          }
        }
      },
      semantics_label~,
    )
    // 右键：命中测试与左键同一套几何（含真实 avail_width），把链下标
    // 交给 update 开菜单。**与左键共用 `blocks_hit_index`**——两处各算一份
    // 命中就会「点得中但右键点不中」。
    .on_secondary_tap_with_frame(fn(position, frame) {
      let lx = position.x - frame.origin.x
      // 画布局部 → 链坐标：与 draw 共用 `blocks_chain_y`（单一来源）。
      let ly = blocks_chain_y(
        position.y - frame.origin.y,
        y_offset,
        note_height,
      )
      let hit = blocks_hit_index(blocks, lx, ly, avail_width=width, display_texts~)
      // **存视口坐标**（`position` 就是），不是画布局部坐标：菜单要锚在
      // 指针所在的那一点上，而 `context_menu_region` 的 `Viewport` 锚点
      // 吃的是视口坐标。存局部坐标的话菜单会按画布原点的偏移弹出来，
      // 滚动或换行后位置就偏了。
      Msg::BlocksContextMenu(hit, position.x, position.y)
    })
    .on_tap_with_frame(fn(position, frame) {
      let lx = position.x - frame.origin.x
      // 画布局部 → 链坐标：与 draw 共用 `blocks_chain_y`（单一来源）。
      let ly = blocks_chain_y(
        position.y - frame.origin.y,
        y_offset,
        note_height,
      )
      // **点值就地编辑**优先于整行选中：值格子（叶子段）比整行小得多，
      // 用户点在数字上就是想改那个数字。用与绘制同一份几何判定
      // （`blocks_value_hit`），保证「画在哪就点在哪」。
      let cache = metrics.val
      let measure = fn(text : String) -> Double {
        match cache.get(text) {
          Some(value) => value
          None => 0.0
        }
      }
      let base = blocks_item_rects(blocks, avail_width=width, display_texts~)
      let visual = blocks_visual_rects(blocks, base)
      match blocks_value_hit(
        blocks,
        visual,
        lx,
        ly,
        measure,
        y_offset~,
        lead_texts~,
      ) {
        Some(hit) => Msg::EditBlockValue(hit.block_index, hit.expr_path)
        None =>
          // 宽度随消息带上：命中必须用与绘制同一组矩形（见 Msg 上的注释）。
          Msg::BlocksCanvasTap(lx, ly, width)
      }
    })
    .on_drag_with_frame(fn(event, frame) {
      let lx = event.position.x - frame.origin.x
      // 同上：与 draw 共用同一个换算。
      let ly = blocks_chain_y(
        event.position.y - frame.origin.y,
        y_offset,
        note_height,
      )
      // **从调色板拖进来的骨架**：画布这一侧才拿得到指针的落点。
      // 松手时按指针算出目标容器与位置，派发 DropStatement。
      // 调色板拖动期间：只有**松手**才产生消息（落点由这里算），
      // 移动过程不发消息——拖动中的高亮是调色板侧的事，画布不需要
      // 每个指针采样都过一次 update（那只是无谓的重渲）。
      // **拖到边缘自动滚动**：长链条拖拽的必需项——不自动滚就只能拖到
      // 可视区内，链尾的块永远拖不动。判据用指针在画布内的 y 位置：
      // 上缘 24pt 内向上滚、下缘 24pt 内向下滚。
      // 只在**拖动中**触发（`Changed`），松手后不再滚。
      let auto = if event.phase == @views.DragGesturePhase::Changed {
        if ly < BLOCKS_EDGE_ZONE {
          Msg::BlocksAutoScroll(-1)
        } else if ly > height - BLOCKS_EDGE_ZONE {
          Msg::BlocksAutoScroll(1)
        } else {
          Msg::Noop
        }
      } else {
        Msg::Noop
      }
      let _ = auto
      if expr_drag {
        // 报告块拖动：松手时按指针找**洞**（段级命中）。
        //
        // 解析放在这里而不是 update：洞的位置 = 逐段文本宽度累加，需要
        // `TextSystem`；它只在布局上下文里（`metrics` 已在布局期量好），
        // update 拿不到。与绘制读**同一份** `metrics`，才保证画哪点哪。
        if event.phase == @views.DragGesturePhase::Ended {
          let cache = metrics.val
          let measure = fn(text : String) -> Double {
            match cache.get(text) {
              Some(value) => value
              None => 0.0
            }
          }
          let base = blocks_item_rects(blocks, avail_width=width, display_texts~)
          let visual = blocks_visual_rects(blocks, base)
          match blocks_slot_hit(
            blocks,
            visual,
            lx,
            ly,
            measure,
            y_offset~,
            lead_texts~,
          ) {
            Some(hit) =>
              Msg::ExpressionDrop(hit.block_index, hit.expr_path)
            None =>
              // 没落在洞上：明确拒绝（松手毫无反应会让用户以为拖坏了）
              Msg::ExpressionDrop(-1, [])
          }
        } else {
          auto
        }
      } else if palette_drag {
        if event.phase == @views.DragGesturePhase::Ended {
          Msg::PaletteDrop(lx, ly, width)
        } else {
          auto
        }
      } else if event.phase == @views.DragGesturePhase::Started {
        Msg::BlocksCanvasPress(lx, ly, width)
      } else if event.phase == @views.DragGesturePhase::Changed {
        // 边缘时优先滚动（否则长链拖不到头）；不在边缘才是普通拖动。
        match auto {
          Msg::BlocksAutoScroll(_) => auto
          _ => Msg::BlocksCanvasDragTo(lx, ly, width)
        }
      } else {
        Msg::BlocksCanvasRelease
      }
    }),
    // 画布底板**显式钉住**：这个容器此前没有 background，回落到环境 Base →
    // `palette.surface`，于是画布底与相邻的 AI 保留带完全同色（实测同为
    // `#22262C`），两段之间的边界整个消失——同一条水平结构线，左半（窗格
    // 脚注 → 带）看得见、右半（画布 → 带）看不见。`blocks_canvas_background`
    // 因此曾经是一个零调用者的死函数，这里把它激活：积木画布与壳面板是两套
    // 配色纪律，画布底由积木域自己钉，不借邻居的回落色。
    background=blocks_canvas_background(),
    padding=0.0,
  )
}
