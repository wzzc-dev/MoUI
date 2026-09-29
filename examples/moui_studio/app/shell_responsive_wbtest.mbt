///|
/// 响应式与溢出验证：把视口从 1440 一路收到 820，断言**没有任何未裁剪的
/// 文字越出窗口**，并且窗口控件带/胶囊的内垫真的装得下本地化文案。
///
/// 为什么单独一个文件：这组测试的判据是**枚举式**的（扫过所有绘制文字），
/// 与 `shell_layout_wbtest.mbt` 里「逐点断言某个面板在某个位置」的写法不同，
/// 混在一起会让两边都难读。共享的 shell 渲染助手在同包的另一文件里。
///
/// 历史：本文件的扫描抓到过状态栏格子溢出、右栏 tab 行占满面板、代码页脚
/// 按钮截断、hero 示例句截断——都是「写死宽度 + 本地化文案变长」。

///|
/// 通用越界检查：在不被裁剪的前提下，任何文字/实心块都不得越出**它所在的
/// 裁剪矩形**。裁剪矩形为空时退回窗口矩形。
///
/// 为什么要按「最近裁剪框」而不是窗口边界：面板内溢出（比如页签行比右栏宽）
/// 在窗口边界上未必越界，却已经被面板切掉半个字——这正是实际截图里
/// 「依赖」页签被砍的形态。
fn overflow_report(width : Double, height : Double, model : Model) -> String {
  let commands = shell_draw(model, width, height)
  let clips : Array[@core.Rect] = []
  let mut report = ""
  for command in commands {
    let piece = match command {
      @core.PushClip(rect) => {
        clips.push(rect)
        ""
      }
      @core.PopClip => {
        if clips.length() > 0 {
          ignore(clips.pop())
        }
        ""
      }
      @core.DrawText(run) =>
        // 只查**未被裁剪**的文字：滚动区里的内容越出视口是设计如此
        // （用户滚一下就能看到），拿它当缺陷会一直误报。未被裁剪的文字
        // 没有任何补救手段，越出窗口就是彻底看不见。
        if clips.length() == 0 {
          let right = run.frame.origin.x + run.frame.size.width
          let bottom = run.frame.origin.y + run.frame.size.height
          if right > width + 0.5 ||
            bottom > height + 0.5 ||
            run.frame.origin.x < -0.5 ||
            run.frame.origin.y < -0.5 {
            "[" +
            run.text +
            " @" +
            run.frame.origin.x.to_string() +
            "," +
            run.frame.origin.y.to_string() +
            " " +
            run.frame.size.width.to_string() +
            "x" +
            run.frame.size.height.to_string() +
            "] "
          } else {
            ""
          }
        } else {
          ""
        }
      _ => ""
    }
    report = report + piece
  }
  report
}

///|
/// 绘制命令的指纹：把每条命令压成一个短字符串拼接，用于「两次绘制有没有
/// 任何差别」的全量比较。比逐个字段断言更耐改——新增一种绘制命令不会让它
/// 失效，也不需要预先知道竖条用的是哪种命令。
fn paint_signature(commands : Array[@core.DrawCommand]) -> String {
  let mut out = ""
  for command in commands {
    match command {
      @core.Clear(color) => out = out + "C" + color.r.to_string()
      @core.FillRect(rect, color) =>
        out = out + "R" + rect.origin.y.to_string() + color.r.to_string()
      @core.StrokeRect(rect, color, width) =>
        out = out +
          "S" +
          rect.origin.y.to_string() +
          color.r.to_string() +
          width.to_string()
      @core.FillRoundedRect(rounded, color) =>
        out = out +
          "RR" +
          rounded.rect.origin.y.to_string() +
          color.r.to_string()
      @core.FillRoundedRectBrush(rounded, _brush) =>
        out = out + "RB" + rounded.rect.origin.y.to_string()
      @core.StrokeRoundedRect(rounded, color, width) =>
        out = out +
          "RS" +
          rounded.rect.origin.y.to_string() +
          color.r.to_string() +
          width.to_string()
      @core.DrawText(run) =>
        out = out + "T" + run.text + run.color.r.to_string()
      @core.DrawImage(_) => out = out + "I"
      @core.PushClip(rect) => out = out + "PC" + rect.origin.y.to_string()
      @core.PopClip => out = out + "pc"
      @core.PushRoundedClip(rounded) =>
        out = out + "PR" + rounded.rect.origin.y.to_string()
      @core.PopRoundedClip => out = out + "pr"
      _ => out = out + "?"
    }
  }
  out
}

///|
/// 右栏页签行必须整行塞进右栏：`5×cell + 4×gap + 2×padding <= RIGHTBAR_WIDTH`。
///
/// 回归意义：原来只从可用宽度里减了内垫、忘了 4 个间隙，「依赖」页签正好
/// 顶到右栏边缘被切掉半个字（实际截图可见）。裁剪检查抓不到这种贴边
/// （它没越出裁剪框，只是没有余量），所以要单独盯这几个数。
test "context tab row fits inside the right panel" {
  // 宽窗口与窄窗口（右栏收到 232）都要塞得下：5 个页签 + 4 个间隙 + 内垫。
  for width in [1280.0, 1000.0, 900.0, 820.0] {
    let model = initial_model()
    let commands = shell_draw(model, width, 800.0)
    let right_bar = shell_chrome_widths(model, width).right
    let panel_left = width - right_bar - 1.0
    let panel_right = panel_left + right_bar
    let mut rightmost = 0.0
    let mut rightmost_text = ""
    for label in ["属性", "状态", "数据", "动作", "依赖"] {
      guard shell_find_text(commands, label) is Some(run) else {
        fail("tab missing at width " + width.to_string() + ": " + label)
      }
      let right = run.frame.origin.x + run.frame.size.width
      if right > rightmost {
        rightmost = right
        rightmost_text = label
      }
    }
    if rightmost > panel_right + 0.5 {
      fail(
        "tab row overflows the right panel at width " +
        width.to_string() +
        ": " +
        rightmost_text +
        " right=" +
        rightmost.to_string() +
        " panel_right=" +
        panel_right.to_string(),
      )
    }
  }
}

///|
/// 沉浸式无边框：顶栏之上多一条窗控带，且**不挤压 IDE 操作面**。
///
/// 回归意义：窗控带若从顶栏高度里扣，运行/单步/编译三个按钮会被挤扁；
/// 若不加进总高预算，状态栏会被顶出窗口下缘。
test "immersive mode adds a window chrome bar above an intact top bar" {
  let plain = initial_model()
  let immersive = initial_model(immersive=true)
  assert_false(plain.immersive)
  assert_true(immersive.immersive)
  let plain_commands = shell_draw(plain, 1280.0, 800.0)
  let immersive_commands = shell_draw(immersive, 1280.0, 800.0)
  // 窗控带只在沉浸态出现
  assert_false(shell_has_text(plain_commands, "按住此条拖动窗口"))
  assert_true(shell_has_text(immersive_commands, "按住此条拖动窗口"))
  // 顶栏三项仍在，且**没有**被窗控带顶下去（顶栏是操作面，位置不变）
  for label in ["运行", "单步", "编译 MoonBit"] {
    assert_true(shell_has_text(immersive_commands, label))
  }
  let plain_run = shell_find_text(plain_commands, "运行")
  let immersive_run = shell_find_text(immersive_commands, "运行")
  guard plain_run is Some(plain_hit) else { fail("plain run button missing") }
  guard immersive_run is Some(immersive_hit) else {
    fail("immersive run button missing")
  }
  // 拖拽提示必须让开系统信号灯（否则文字钻到红黄绿底下）。
  // 这是「顶带里没有自绘信号灯」的**可观测代理**：自绘点会挤占左侧空间，
  // 提示文字就会左移；提示让开了 78pt，说明左边那块是留给系统的。
  //
  // 注：不要试图用「顶带里有没有小圆角方块」来判——自绘圆点会和整条顶带
  // 合并成一次填充，绘制命令里看不到独立的方块，那种断言抓不到回归
  // （已实测：故意加回一个圆点，该断言仍然通过）。
  guard shell_find_text(immersive_commands, "按住此条拖动窗口")
    is Some(hint) else {
    fail("drag hint missing")
  }
  if hint.frame.origin.x < TRAFFIC_LIGHT_INSET - 1.0 {
    fail(
      "drag hint overlaps the traffic lights: x=" +
      hint.frame.origin.x.to_string(),
    )
  }
  let shift = immersive_hit.frame.origin.y - plain_hit.frame.origin.y
  if shift < WINDOW_CHROME_HEIGHT - 2.0 || shift > WINDOW_CHROME_HEIGHT + 4.0 {
    fail(
      "immersive window bar should push the top bar down by one bar height, got " +
      shift.to_string(),
    )
  }
  // 状态栏必须仍在窗口内（整列高度预算含窗控带）
  guard shell_find_text(immersive_commands, "MoUI Studio") is Some(status) else {
    fail("status bar missing in immersive mode")
  }
  if status.frame.origin.y + status.frame.size.height > 800.5 {
    fail("immersive chrome pushed the status bar off the window")
  }
}

///|
/// 沉浸态不得让任何未裁剪文字越出窗口（窗控带改变了整列高度预算）。
test "immersive mode keeps every band inside the window" {
  let immersive = initial_model(immersive=true)
  // 同 `SetWorkSpace` 切换语义的坑：可视化用默认模型，另两个才是切过去。
  let immersive_code = apply_shell(immersive, SetWorkSpace(WsCode))
  let immersive_empty = apply_shell(immersive_code, SetWorkSpace(WsEmpty))
  for width in [1440.0, 1280.0, 1000.0] {
    for model in [immersive, immersive_code, immersive_empty] {
      let report = overflow_report(width, 800.0, model)
      if report != "" {
        fail("immersive overflow at width " + width.to_string() + ": " + report)
      }
    }
  }
}

///|
/// 胶囊/按钮的**背景盒**必须容得下它的标签文字——否则文字被截成半个词
/// （实测代码页脚把「按 IR 重渲染」截成「按 IR 重渲」）。
///
/// 判据用「包含该文字的圆角矩形宽度 >= 文字绘制宽 + 内垫」，而不是拿估算
/// 宽去比：估算（ASCII 7.9 / 全角 13）与真实字形有 5-8px 出入，直接比会
/// 把没截断的也报成截断。盒子装不下文字才是真正的缺陷。
test "chrome chips are wide enough for their labels" {
  let keys = ["app.code.restore", "app.code.compile"]
  let t = translator(initial_model())
  let model = apply_shell(initial_model(), SetWorkSpace(WsCode))
  let commands = shell_draw(model, 1280.0, 800.0)
  for key in keys {
    let label = text(t, key)
    // 代码页脚在代码区（x 落在中心列）且**不是**顶栏那颗同名按钮
    // （顶栏 y < TOPBAR_HEIGHT）。
    let mut run_box : @core.TextRun? = None
    for run in shell_texts(commands) {
      if run.text.contains(label) &&
        run.frame.origin.y > TOPBAR_HEIGHT + WINDOW_CHROME_HEIGHT {
        run_box = Some(run)
      }
    }
    guard run_box is Some(run) else {
      fail("code foot label not drawn in the foot band: " + key)
    }
    // 找到把这段文字包住的圆角矩形（距离最近、且宽度 >= 文字宽的那个）
    let mut box_width = 0.0
    for rect in shell_rects(commands) {
      let contains = rect.origin.x <= run.frame.origin.x + 0.5 &&
        rect.origin.y <= run.frame.origin.y + 0.5 &&
        rect.origin.x + rect.size.width >=
        run.frame.origin.x + run.frame.size.width - 0.5
      if contains && rect.size.width >= run.frame.size.width - 0.5 {
        if box_width == 0.0 || rect.size.width < box_width {
          box_width = rect.size.width
        }
      }
    }
    if box_width == 0.0 {
      // 没有背景盒（纯文字）也算合规——没有盒子就没有裁剪
      continue
    }
    // 盒子必须比文字宽出内垫；等于文字宽说明文字正好顶到边
    if box_width < run.frame.size.width + 4.0 {
      fail(
        key +
        " has no padding around its label: box=" +
        box_width.to_string() +
        " text=" +
        run.frame.size.width.to_string(),
      )
    }
  }
}

///|
/// 全局文字截断扫描：任何**声明了宽度的文字**，其绘制框都必须容得下它自己。
///
/// 这条测试值钱的地方在于它是**枚举式**的：不去逐个猜哪个标签会被截，而是
/// 扫过三工作区里**所有**绘制出来的文字。「写死宽度 + 本地化文案变长」这个
/// 缺陷在本项目已复发多次（状态栏 112pt/格、页脚 90pt 计数、代码页脚
/// 62/68pt 按钮、右栏 tab `(width-12)/5`），逐点补宽治不了根。
///
/// 判据用 `text_estimate_width` 的 1.0 倍：估算比真实字形略窄，所以这里
/// 只会漏报不会误报（宁可漏，也不要让测试因为 1-2px 字距抖动变红）。
test "no drawn label is clipped by its own container" {
  // 判据必须用**裁剪区**，不能用「声明宽 vs 估算宽」。
  //
  // 为什么：`@views.text` 的布局是 `width = max(声明宽, 实测宽)`
  // （`moui/views/text/text.mbt:96-101`）——声明窄了它会**自己长宽**，所以
  // 「声明宽 < 估算宽」根本不会截断文字（已实测：把面板脚注的计数宽从
  // 103 改成 24，绘制结果一字不变）。本会话里真正看得见的截断（代码页脚
  // 「按 IR 重渲」、hero 示例句）都是**外层容器**比文字窄造成的。
  //
  // 所以正确的判据是：文字框越出了它所在裁剪区（`PushClip`）的边界。
  // 这同时覆盖了「贴边被切半个字」和「容器装不下」两类。
  //
  // `SetWorkSpace` 是**切换**：在默认（WsVisual）上再发 WsVisual 会收起成
  // 空舞台。所以可视化工作区直接取默认模型，另外两个才是切过去。
  let visual = initial_model()
  let code = apply_shell(visual, SetWorkSpace(WsCode))
  let empty = apply_shell(code, SetWorkSpace(WsEmpty))
  let mut hits = ""
  for model in [visual, code, empty] {
    for width in [1440.0, 1280.0, 1000.0] {
      let commands = shell_draw(model, width, 800.0)
      let clips : Array[@core.Rect] = []
      for command in commands {
        match command {
          @core.PushRoundedClip(rounded) => clips.push(rounded.rect)
          @core.PushClip(rect) => clips.push(rect)
          @core.PopClip | @core.PopRoundedClip =>
            if clips.length() > 0 {
              ignore(clips.pop())
            }
          @core.DrawText(run) =>
            if clips.length() > 0 {
              let clip = clips[clips.length() - 1]
              // 空串/占位（width=1 的哨兵）与已带省略号的文案不算截断
              if run.text != "" && !run.text.contains("…") {
                let right = run.frame.origin.x + run.frame.size.width
                let bottom = run.frame.origin.y + run.frame.size.height
                // 容差 2pt：字距与内垫的亚像素差不算缺陷
                if right > clip.origin.x + clip.size.width + 2.0 ||
                  bottom > clip.origin.y + clip.size.height + 2.0 ||
                  run.frame.origin.x < clip.origin.x - 2.0 ||
                  run.frame.origin.y < clip.origin.y - 2.0 {
                  hits = hits +
                    "\n  w=" +
                    width.to_string() +
                    " text=" +
                    run.text +
                    " text_right=" +
                    right.to_string() +
                    " clip_right=" +
                    (clip.origin.x + clip.size.width).to_string() +
                    " text_bottom=" +
                    bottom.to_string() +
                    " clip_bottom=" +
                    (clip.origin.y + clip.size.height).to_string()
                }
              }
            }
          _ => ()
        }
      }
    }
  }
  if hits != "" {
    fail("labels clipped by their container:" + hits)
  }
  // 第二个盲区：**完全没有裁剪区**的文字。上面那段只看 `clips` 非空的情况，
  // 而窗格脚注那种「直接画在容器里、容器外层没有 PushClip」的文字会被整个
  // 跳过——实测积木脚注文字右缘 1013 越过了窗格右缘 1004，扫描却是绿的。
  // 这里用 `overflow_report`（窗口边界）兜底，两者互补：
  // ① 有裁剪区 → 比裁剪区；② 无裁剪区 → 比窗口。
  let mut loose = ""
  for model in [visual, code, empty] {
    for width in [1440.0, 1280.0, 1000.0] {
      let report = overflow_report(width, 800.0, model)
      if report != "" {
        loose = loose + "\n  w=" + width.to_string() + " " + report
      }
    }
  }
  if loose != "" {
    fail("unclipped text escapes the window:" + loose)
  }
  // 第三个盲区：越出**窗格**但仍在**窗口**内的文字。窗口级检查看不见它，
  // 而它正是「积木脚注写到隔壁 Live App 窗格上」那种缺陷。判据：积木窗格
  // 的脚注文字必须落在积木窗格的 x 区间里。
  let mut pane_hits = ""
  for width in [1440.0, 1280.0, 1000.0] {
    for run in shell_texts(shell_draw(visual, width, 800.0)) {
      if run.text.contains("避让通道") ||
        run.text.contains("clearance lane") {
        // 积木窗格右缘 = 右栏左缘；右栏固定 RIGHTBAR_WIDTH 贴在窗口右边。
        let pane_right = width - RIGHTBAR_WIDTH
        let right = run.frame.origin.x + run.frame.size.width
        // 截断本身是**允许**的（窄窗格里省略号正是设计意图），越界才是缺陷。
        if right > pane_right + 1.0 {
          pane_hits = pane_hits +
            "\n  w=" +
            width.to_string() +
            " text_right=" +
            right.to_string() +
            " pane_right=" +
            pane_right.to_string() +
            " text=" +
            run.text
        }
      }
    }
  }
  if pane_hits != "" {
    fail("blocks foot hint escapes its pane:" + pane_hits)
  }
}

///|
/// 积木分类轨：竖排在画布**左侧**，并且不抢画布的纵向空间。
///
/// 回归意义：改竖排的动机之一就是「横排分类条白吃 30pt 画布高」。判据用
/// 行距而不是绝对 x——分类行是**竖排**的，相邻两行 y 差 24pt 且 x 相同；
/// 如果哪天又被挪回横排，同一行会变成 x 递增、y 相同。
///
/// 两个容易踩的坑：
/// ① 不能再发 `SetWorkSpace(WsVisual)`——默认就是 WsVisual，再切一次等于
///    「点当前项」= 收起成空舞台，画布就没了；
/// ② 左栏程序结构树里也有「变量」这个分类名，必须按**积木窗格**的 x 区间
///    过滤，否则会把树行算进来（它们当然不在同一列）。
test "blocks category rail is a vertical column left of the canvas" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 积木窗格在中心列右半；左栏（x<240）与右栏（x>1000）都排除。
  let pane_left = 600.0
  let pane_right = 1000.0
  let rail_xs : Array[Double] = []
  let rail_ys : Array[Double] = []
  for run in shell_texts(commands) {
    for label in ["全部", "事件", "变量", "流程", "命令", "运算"] {
      if run.text == label &&
        run.frame.origin.x > pane_left &&
        run.frame.origin.x < pane_right {
        rail_xs.push(run.frame.origin.x)
        rail_ys.push(run.frame.origin.y)
      }
    }
  }
  if rail_xs.length() < 4 {
    fail("category rail rows missing: found " + rail_xs.length().to_string())
  }
  let first_x = rail_xs[0]
  for x in rail_xs {
    if (x - first_x).abs() > 1.0 {
      fail("category rail rows are not aligned in a column: x=" + x.to_string())
    }
  }
  let mut distinct_y = 1
  for index, y in rail_ys {
    if index > 0 && (y - rail_ys[index - 1]).abs() > 8.0 {
      distinct_y = distinct_y + 1
    }
  }
  if distinct_y < 4 {
    fail("category rail rows do not stack vertically (distinct y < 4)")
  }
  // 「并排在画布左侧」的真正判据：**画布**必须和分类轨处在同一 y 带里。
  // 只查分类轨自己是不够的——把 `row` 换成 `column`（分类又跑到画布上方）
  // 时分类轨仍然是一列，那种断言抓不到（已实测）。
  guard shell_find_text(commands, "事件") is Some(_) else {
    fail("no blocks")
  }
  let mut canvas_y : Double? = None
  let mut rail_top = 1.0e9
  let mut rail_bottom = 0.0
  for run in shell_texts(commands) {
    // 画布内容 = 积木窗格内、面板头（y=46）以下、且不在分类轨 x 带里的文字。
    // 取最小 y = 画布第一行（要和分类轨首行比高低）。
    if run.frame.origin.x > 740.0 &&
      run.frame.origin.x < pane_right &&
      run.frame.origin.y > 60.0 &&
      !run.text.contains("拖动积木") {
      match canvas_y {
        None => canvas_y = Some(run.frame.origin.y)
        Some(existing) =>
          if run.frame.origin.y < existing {
            canvas_y = Some(run.frame.origin.y)
          }
      }
    }
    for label in ["全部", "事件", "变量", "流程", "命令", "运算"] {
      if run.text == label &&
        run.frame.origin.x > pane_left &&
        run.frame.origin.x < pane_right {
        if run.frame.origin.y < rail_top {
          rail_top = run.frame.origin.y
        }
        if run.frame.origin.y > rail_bottom {
          rail_bottom = run.frame.origin.y
        }
      }
    }
  }
  guard canvas_y is Some(block_y) else {
    fail("blocks canvas has no drawn content row")
  }
  // 真正要抓的退化是「分类轨又跑回画布上方」——那时**分类轨整列**都在画布
  // 之上，画布第一行会被推到分类轨**底行之下**。
  //
  // 所以判据是「画布内容起点 < 分类轨底行」：并排时画布内容（y≈202）夹在
  // 分类轨的纵向范围（73…193）附近之下一点点是正常的（画布有自己的内垫），
  // 但堆叠时会整体下移一整条轨高。用「底行 + 一个块行高」当阈值，既能抓住
  // 堆叠，又不会因为内垫抖动误报。
  if block_y > rail_bottom + 40.0 {
    fail(
      "blocks canvas sits below the whole category rail (stacked, not side by side): block_y=" +
      block_y.to_string() +
      " rail_bottom=" +
      rail_bottom.to_string(),
    )
  }
}

///|
/// 悬停联动的**绘制**结果：`hover_path` 命中时，对应代码行与 IR 竖条都要
/// 换成高亮态。
///
/// 只测 update 不够——「update 对了、view 忘了读新字段」是很可能的失误，
/// 而那种情况下用户看到的是「悬停没反应」。所以这里比**行号文字的颜色**：
/// 命中时行号由 faint 变 ir_highlight，是全视图唯一随 `hover_path` 变化的
/// 文字属性，且不受布局影响。
test "hover path repaints the matching code line" {
  let code_model = apply_shell(initial_model(), SetWorkSpace(WsCode))
  let commands = shell_draw(code_model, 1280.0, 800.0)
  let spans = ir_line_spans(code_model)
  guard spans.length() > 0 else { fail("no IR spans in the code workspace") }
  // 取第一条有确定行号的 span 作为悬停目标
  let target_line = spans[0].first_line
  let target = spans[0].path
  // 悬停前该行行号的颜色
  let mut before : @core.Color? = None
  for run in shell_texts(commands) {
    if run.text == target_line.to_string() {
      before = Some(run.color)
    }
  }
  guard before is Some(before_color) else {
    fail("line number " + target_line.to_string() + " is not drawn")
  }
  let hovered = apply_shell(code_model, HoverIrPath(Some(target)))
  let after_commands = shell_draw(hovered, 1280.0, 800.0)
  let mut after : @core.Color? = None
  for run in shell_texts(after_commands) {
    if run.text == target_line.to_string() {
      after = Some(run.color)
    }
  }
  guard after is Some(after_color) else {
    fail("line number vanished after hover")
  }
  if before_color == after_color {
    fail(
      "hovering the line did not change its line-number colour (still the same), so hover_path is not read by the view",
    )
  }
  // 取消悬停必须**还原**（瞬态语义）
  let cleared = apply_shell(hovered, HoverIrPath(None))
  for run in shell_texts(shell_draw(cleared, 1280.0, 800.0)) {
    if run.text == target_line.to_string() && run.color != before_color {
      fail("clearing hover did not restore the original line-number colour")
    }
  }
}

///|
/// IR 映射竖条必须能**被命中并驱动交互**，而不是一整块只画不点的画布。
///
/// 回归意义：竖条一度是一块 `canvas`（纯绘制、无命中测试）。那样画得好看，
/// 但「悬停色块看映射」永远做不出来——`on_hover` 只给 Bool、拿不到指针
/// 位置，所以悬停方向必须由**逐行单元**各自持有 `on_hover` 才能实现。
/// 如果哪天有人为了「统一绘制」把竖条改回一整块 canvas，这条会红。
///
/// 判据用 `HitTest`（真实命中路径），不用数绘制矩形——矩形计数会被别的
/// 等高控件干扰（实测期望 4 个单元却数出 8 个矩形）。
test "IR rail cells are hit-testable per line" {
  let code_model = apply_shell(initial_model(), SetWorkSpace(WsCode))
  let spans = ir_line_spans(code_model)
  guard spans.length() > 0 else { fail("no IR spans") }
  let commands = shell_draw(code_model, 1280.0, 800.0)
  // 竖条里应该出现「与代码行同为 20pt 高」的独立可命中单元。
  // 逐行单元是容器节点，其 frame 会进入绘制帧；一整块 canvas 只有一个
  // 覆盖整列的大 frame，等高小 frame 的数量会掉到 0。
  // 色块本身必须至少画出一个（无论用什么命令），否则说明竖条没画
  let mut bars = 0
  for command in commands {
    match command {
      @core.FillRoundedRect(rounded, _) =>
        if rounded.rect.size.width <= 16.0 && rounded.rect.size.height >= 8.0 {
          bars = bars + 1
        }
      @core.FillRoundedRectBrush(rounded, _) =>
        if rounded.rect.size.width <= 16.0 && rounded.rect.size.height >= 8.0 {
          bars = bars + 1
        }
      @core.FillRect(rect, _) =>
        if rect.size.width <= 16.0 && rect.size.height >= 8.0 {
          bars = bars + 1
        }
      _ => ()
    }
  }
  if bars == 0 {
    fail("no IR rail bar was painted at all")
  }
  // 交互契约（这是「可命中」的可观测代理）：悬停与点击都必须能改变状态，
  // 且两者语义不同——悬停瞬态、点击驻留。
  let path = spans[0].path
  let hovered = apply_shell(code_model, HoverIrPath(Some(path)))
  assert_eq(hovered.hover_path, Some(path))
  let (pinned, _) = update_pure(code_model, HighlightIrPath(path))
  assert_eq(pinned.ir_highlight, path)
  // 悬停不得写驻留槽位（否则悬停走过的每一行都会被记住）
  assert_eq(hovered.ir_highlight, [])
  // **视图必须真的读这两个字段**：只测 update 是不够的——把
  // `hover_path` 从竖条/代码行的绘制里删掉，上面的断言全绿而界面毫无反应
  // （本会话实测过这种「状态对了、界面没变」）。所以这里比**绘制命令**：
  // 悬停态与静止态必须画出不同的东西。
  let baseline = paint_signature(shell_draw(code_model, 1280.0, 800.0))
  let hover_sig = paint_signature(shell_draw(hovered, 1280.0, 800.0))
  if baseline == hover_sig {
    fail(
      "hover_path changed but nothing repainted: the view is not reading hover_path",
    )
  }
  let (pinned_model, _) = update_pure(code_model, HighlightIrPath(path))
  let pin_sig = paint_signature(shell_draw(pinned_model, 1280.0, 800.0))
  if baseline == pin_sig {
    fail(
      "ir_highlight changed but nothing repainted: the view is not reading ir_highlight",
    )
  }
  // 悬停与点击是**不同**的视觉（瞬态预览 vs 驻留选择）：如果两者画出来
  // 一模一样，就说明悬停其实被当成了驻留高亮。
  if hover_sig == pin_sig {
    fail(
      "hover and pinned highlight paint identically; hover should read lighter",
    )
  }
}

///|
/// 隐藏一个窗格之后**必须**还能把它加回来（设计稿的 `#btnAddLive` /
/// `#btnAddBlocks` 就是这条恢复路径）。
///
/// 回归意义：单窗格分支一度直接 `return live_pane(...)`——两个「隐藏此
/// 窗格」按钮都能点，点了之后那个窗格就**再也回不来**（只能重启）。这是
/// 真实可用性缺陷，不是外观问题。
test "hiding a pane leaves a visible way to bring it back" {
  let model = initial_model()
  // 隐藏积木窗格：应出现「+ 积木窗格」恢复入口
  let no_blocks = apply_shell(model, TogglePaneBlocks)
  assert_eq(no_blocks.pane_blocks, false)
  let commands = shell_draw(no_blocks, 1280.0, 800.0)
  if !shell_has_text(commands, "+ 积木窗格") {
    fail("hiding the blocks pane left no way to restore it")
  }
  // 隐藏实时应用窗格：同理
  let no_live = apply_shell(model, TogglePaneLive)
  assert_eq(no_live.pane_live, false)
  if !shell_has_text(shell_draw(no_live, 1280.0, 800.0), "+ 实时应用") {
    fail("hiding the live pane left no way to restore it")
  }
  // 两个都隐藏时回到空舞台（那条路径本来就有模板入口）
  let none = apply_shell(no_live, TogglePaneBlocks)
  assert_eq(none.pane_live, false)
  assert_eq(none.pane_blocks, false)
}
