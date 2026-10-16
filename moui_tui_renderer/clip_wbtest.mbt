// 量化与框内范围的白盒证据:这两条规则决定「哪一格属于哪个节点」,
// 而它们要的红是终端上一行的错位 —— 用公开 API 断言得靠数 ANSI 字节,
// 那证明不了格子的归属。

///|
fn rect(x : Double, y : Double, width : Double, height : Double) -> @core.Rect {
  @core.Rect::new(x~, y~, width~, height~)
}

///|
/// 高亮带只铺「中心确实落在矩形里」的那些格。
///
/// 残格兜底是给零高分隔线留的,带不能跟着它走:实测 100x30 的树末行只剩 4px
/// 可见高时,那一格画不出这条行的任何一个字,却整格反白 —— 用户看到的就是压在
/// 底边框上的一个色块。同一个窄区间走 `quantize_axis` 仍然占一格,
/// 所以分隔线不会因此消失。
test "a band needs a cell centre, a stroke does not" {
  let cell = CellBox::default()
  // y∈[12,16):第 0 格中心 8 在上方,第 1 格中心 24 在下方,一格都不属于它。
  assert_eq(quantize_box(rect(0.0, 12.0, 80.0, 4.0), cell, 10, 3), None)
  assert_eq(quantize_axis(12.0, 4.0, cell.height, 3), (0, 0))
  // 整格高度的行:中心 24 在里面,只有第 1 格。
  assert_eq(
    quantize_box(rect(0.0, 16.0, 80.0, 16.0), cell, 10, 3),
    Some((1, 0, 1, 9)),
  )
  // 跨两格但只盖住第二格中心的矮帧:横向同理,宽 3px 连一个中心都碰不到。
  assert_eq(quantize_box(rect(0.0, 16.0, 3.0, 16.0), cell, 10, 3), None)
  assert_eq(
    quantize_box(rect(0.0, 8.0, 8.0, 8.0), cell, 10, 3),
    Some((0, 0, 0, 0)),
  )
}

///|
/// 内容范围是一圈边框的内侧,而框小到没有内侧时退回整栏。
///
/// 终端的「线」吃一整格,布局的边框只有几 px,所以两者必然抢同一圈格子:
/// 内容不往里收一格,列表行就写在框线上。收到内侧之后仍然要留着能画行的格子 ——
/// 实测 43x11 的一栏量化出来只有相邻两行,按规则收完就没有内边了,
/// 那时把整栏交给内容,窗口再矮也先让行出现,不能只剩一个空框。
test "inside_ring insets by one cell but never empties a pane" {
  let cell = CellBox::default()
  // 80x48 在 8x16 的格子上是 10x3 的一圈框:内侧就是第 1 行的 8 格。
  assert_eq(
    inside_ring(rect(0.0, 0.0, 80.0, 48.0), cell, 20, 6),
    rect(8.0, 16.0, 64.0, 16.0),
  )
  // 24x32 只有 3x2 格:上下左右各收一格之后什么都不剩。
  assert_eq(
    inside_ring(rect(0.0, 0.0, 24.0, 32.0), cell, 3, 2),
    rect(0.0, 0.0, 24.0, 32.0),
  )
}
