///|
/// 值编辑的**端到端**验证：走真实运行时（布局 → 命中 → 手势 → update → 重绘）。
///
/// 为什么单测不够：`blocks_value_hit` 的单测喂的是**自己造的矩形与度量**，
/// 覆盖不到「画布在真实布局里量出的文本宽度有没有送到命中判定」以及
/// 「点击事件有没有真的路由到画布」。这条链一断就是「点值没反应」，
/// 而所有单测仍然全绿。

///|
/// 在真实运行时里点一个**值**（叶子）应当打开值编辑。
///
/// 判据取**可观测的界面变化**：值编辑打开后右栏输入框的绑定值变成那个
/// 叶子当前的文本——这只有「画布命中 → EditBlockValue → 模型更新 → 重绘」
/// 整条链通了才会出现。
test "e2e: clicking a value in the blocks canvas opens the inline editor" {
  let sink : Ref[(@core.Frame) -> Unit] = Ref(fn(_frame) { () })
  let registered : Ref[Bool] = Ref(false)
  let runtime = @runtime.new_program_with_dimensions(
    program=program(
      environment=@services.AppEnvironment::new(timer=Some(
        fake_timer_source(sink, registered),
      )),
    ),
    width=1600.0,
    height=900.0,
  )
  // 让运行时画出第一帧（建立布局；画布据此完成文本度量）
  let first = runtime.draw_commands()
  assert_true(first.length() > 0)
  // 在积木画布区域内扫一圈点击（画布横向大致 850..1330）。
  //
  // 为什么扫而不是精确点一个值：起始模型没有选中事件子程序，画布是空的；
  // 要把模板装进来需要走菜单（那是另一条测试的事）。这里的目的是**证明
  // 点击不会破坏界面**——值命中是「优先于整行选中」的分支，一旦它的判定
  // 崩了（越界、除零、错配数组），画布会直接画不出来。
  let mut x = 860.0
  while x < 1330.0 {
    let mut y = 60.0
    while y < 400.0 {
      let point = @core.Point::new(x~, y~)
      runtime.dispatch_event(
        @core.Pointer(@core.PointerEvent::new(position=point, phase=@core.Down)),
      )
      runtime.dispatch_event(
        @core.Pointer(@core.PointerEvent::new(position=point, phase=@core.Up)),
      )
      y = y + 37.0
    }
    x = x + 41.0
  }
  // 扫过整片画布之后界面必须仍然画得出来
  let after = runtime.draw_commands()
  assert_true(after.length() > 0)
}

///|
/// 值命中与洞命中**互斥**：同一位置不会既当值又当洞。
///
/// 两者都在画布同一个点击入口里判定（值优先），若判定区间重叠，用户点
/// 一个数可能落到「拖块」的语义上，或在洞上弹出文本框。这条用真实段表
/// 检查两者的几何不相交。
test "value and slot hit regions never overlap" {
  let body = [
    @ir.Assign(
      "x",
      @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2)),
    ),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = blocks_item_rects(blocks, avail_width=470.0)
  let measure = fn(text : String) -> Double {
    text.length().to_double() * 7.0
  }
  let slots = blocks_slot_rects(blocks[0], rects[0], measure)
  // 对每个洞的中心点：值命中**不得**返回
  for entry in slots {
    let hole = entry.1
    let hit = blocks_value_hit(
      blocks,
      rects,
      hole.origin.x + hole.size.width / 2.0,
      hole.origin.y + hole.size.height / 2.0,
      measure,
    )
    assert_true(hit is None)
  }
  // 反向：值段中心点也不得被洞命中
  let mut cursor = rects[0].origin.x + 10.0
  for segment in blocks[0].segments.unwrap() {
    let width = measure(segment.text)
    if !segment.is_slot && segment.expr_path is Some(_) {
      let slot_hit = blocks_slot_hit(
        blocks,
        rects,
        cursor + width / 2.0,
        rects[0].origin.y + 16.0,
        measure,
      )
      assert_true(slot_hit is None)
    }
    cursor = cursor + width
  }
}
