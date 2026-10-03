///|
/// 插槽（reporter slot）的**命中测试**：点中某个洞时，回答「是哪条语句的
/// 哪个子表达式」。
///
/// # 为什么必须与绘制共用一份几何
///
/// 洞的位置 = 标签前缀宽度 + 前面所有段的宽度之和。若命中层自己再算一遍
/// （或换一把尺量文本），就会出现「画在一处、点在另一处」——而且因为两者
/// **一起**偏，只测其中一边的用例发现不了。所以这里复用 `push_slot_holes`
/// 的同一套输入（段表 + 注入的度量），只把「产出绘制指令」换成「产出可命中
/// 的矩形」。
///
/// # 为什么单独一个文件
///
/// `blocks_canvas.mbt` 已近千行（策略硬限 1200）；命中判定是新的一层
/// （从「行」下钻到「段」），独立成文件比塞进画布更清楚。
///
/// 返回 `None` 表示该点不在任何洞上（调用方按普通行命中处理）。
pub(all) struct SlotHit {
  /// 该洞所属语句在积木链里的下标（与 `blocks_hit_index` 同一坐标系）
  block_index : Int
  /// 该洞对应的表达式路径（`expr_path.mbt` 的寻址语法）
  expr_path : Array[Int]
  /// 洞的矩形（画布坐标，与绘制同一份）
  rect : @geometry.Rect
}

///|
/// 点在哪个插槽上。
///
/// `rect` 入参是**行矩形**（与 `blocks_item_rects` / `blocks_visual_rects`
/// 同一坐标系），`y_offset` 是编辑卡拆段时的链条坐标偏移（与绘制一致）。
/// 只在**未截断**的行上判定——截断后段与字形的对齐关系已断（省略号吃掉的
/// 宽度无从得知），照着原段宽判定会把点击认到错位置。
pub fn blocks_slot_hit(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
  x : Double,
  y : Double,
  measure : (String) -> Double,
  y_offset? : Double = 0.0,
  lead_texts? : Array[String] = [],
) -> SlotHit? {
  let mut index = 0
  for item in blocks {
    let rect = rects[index]
    let local_y = y + y_offset
    let lead_text = if index < lead_texts.length() {
      lead_texts[index]
    } else {
      ""
    }
    match slot_hit_in_row(
      item,
      rect,
      x,
      local_y,
      measure,
      blocks_row_lead_width(item, lead_text, measure),
    ) {
      Some(entry) => {
        let path = match entry.0.expr_path {
          Some(path) => path
          None => {
            index = index + 1
            continue
          }
        }
        return Some(SlotHit::{
          block_index: index,
          expr_path: path,
          rect: entry.1,
        })
      }
      None => ()
    }
    index = index + 1
  }
  None
}

///|
/// **所有洞的几何**：一份推演，绘制与命中都读它。
///
/// 这是本模块的核心纪律：洞的位置 = 标签前缀宽度 + 引导宽 + 前面所有段
/// 宽度之和。绘制层要它来画凹槽、命中层要它来判点击——**两处各算一份就
/// 会一起偏**，而且只测其中一边的用例发现不了（画对了点错了，或反之）。
/// 所以只留这一个函数产出 `(表达式路径, 矩形, 是否有内容)`，两边都消费它。
///
/// `lead` 是**引导宽**（标签起始 x 到第一段字形的距离 = 箭头前缀 + 本地化
/// 标签宽，见 `blocks_row_lead_width`）。缺省 0 = 标签从 `item.text` 直接
/// 开始（纯逻辑测试的口径）。
pub fn blocks_slot_rects(
  item : @blocks.BlockItem,
  rect : @geometry.Rect,
  measure : (String) -> Double,
  lead? : Double = 0.0,
) -> Array[(@blocks.TextSegment, @geometry.Rect)] {
  let result : Array[(@blocks.TextSegment, @geometry.Rect)] = []
  let segments = match item.segments {
    None => return result
    Some(segments) => segments
  }
  // 条件块（如果/否则如果/当）的标签前有一枚徽标，占 18pt 位。
  // 与绘制同源：这里改、绘制不改就会整体错位一个徽标。
  let badge = match item.kind {
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkWhile => true
    _ => false
  }
  let label_x = rect.origin.x + (if badge { 28.0 } else { 10.0 }) + lead
  let mut cursor = label_x
  for segment in segments {
    let width = measure(segment.text)
    if segment.is_slot {
      // 洞的最小宽度：空槽也要看得见（Scratch 的空槽是一个小胶囊）。
      result.push((
        segment,
        @geometry.Rect::new(
          x=cursor,
          y=rect.origin.y + 6.0,
          width=width.max(28.0),
          height=20.0,
        ),
      ))
    }
    cursor = cursor + width
  }
  result
}

///|
/// 点在一个**值**（叶子段）上：返回它的语句与表达式路径。
///
/// 与洞分开：洞是「可以塞一块积木」的凹槽，值是「可以就地改」的内容
/// （字面量/变量）。点击的语义因此不同——洞是拖放目标，值是编辑目标——
/// 所以判定也分开，不合成一个「段命中」。
pub fn blocks_value_hit(
  blocks : Array[@blocks.BlockItem],
  rects : Array[@geometry.Rect],
  x : Double,
  y : Double,
  measure : (String) -> Double,
  y_offset? : Double = 0.0,
  lead_texts? : Array[String] = [],
) -> SlotHit? {
  let mut index = 0
  for item in blocks {
    let rect = rects[index]
    let local_y = y + y_offset
    let lead_text = if index < lead_texts.length() {
      lead_texts[index]
    } else {
      ""
    }
    match value_hit_in_row(
      item,
      rect,
      x,
      local_y,
      measure,
      blocks_row_lead_width(item, lead_text, measure),
    ) {
      Some(entry) => {
        let path = match entry.0.expr_path {
          Some(path) => path
          None => {
            index = index + 1
            continue
          }
        }
        return Some(SlotHit::{
          block_index: index,
          expr_path: path,
          rect: entry.1,
        })
      }
      None => ()
    }
    index = index + 1
  }
  None
}

///|
/// 行内找**值段**（`is_slot == false` 且有表达式路径的段）。
fn value_hit_in_row(
  item : @blocks.BlockItem,
  rect : @geometry.Rect,
  x : Double,
  y : Double,
  measure : (String) -> Double,
  lead : Double,
) -> (@blocks.TextSegment, @geometry.Rect)? {
  // 值段与洞段共用同一套几何推演（`blocks_slot_rects` 只产出洞），
  // 所以这里按同样的规则走一遍前缀宽度，但保留**所有**段落。
  let segments = match item.segments {
    None => return None
    Some(segments) => segments
  }
  let badge = match item.kind {
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkWhile => true
    _ => false
  }
  let label_x = rect.origin.x + (if badge { 28.0 } else { 10.0 }) + lead
  let mut cursor = label_x
  for segment in segments {
    let width = measure(segment.text)
    let hit_width = if segment.is_slot { width.max(28.0) } else { width }
    if !segment.is_slot && segment.expr_path is Some(_) {
      if x >= cursor && x <= cursor + hit_width && y >= rect.origin.y + 6.0 &&
        y <= rect.origin.y + 26.0 {
        return Some((
          segment,
          @geometry.Rect::new(
            x=cursor,
            y=rect.origin.y + 6.0,
            width=hit_width,
            height=20.0,
          ),
        ))
      }
    }
    cursor = cursor + width
  }
  None
}

///|
/// 点在哪个插槽上——薄薄一层，判定完全依赖 `blocks_slot_rects`。
fn slot_hit_in_row(
  item : @blocks.BlockItem,
  rect : @geometry.Rect,
  x : Double,
  y : Double,
  measure : (String) -> Double,
  lead : Double,
) -> (@blocks.TextSegment, @geometry.Rect)? {
  for entry in blocks_slot_rects(item, rect, measure, lead~) {
    let hole = entry.1
    if x >= hole.origin.x && x <= hole.origin.x + hole.size.width &&
      y >= hole.origin.y && y <= hole.origin.y + hole.size.height {
      return Some(entry)
    }
  }
  None
}
