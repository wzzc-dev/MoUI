///|
test "积木榫卯外轮廓含凹槽与凸头关键段" {
  let rect = node_rect({
    id: 1,
    kind: "Sequence",
    title: "A",
    x: 60.0,
    y: 60.0,
    config: [],
  })
  let verbs = block_outline_verbs(rect, 0.0)
  // MoveTo + 6 LineTo + 4 圆角 QuadTo + 凹槽 2 cubic + 凸头 2 cubic + Close
  let mut moves = 0
  let mut lines = 0
  let mut quads = 0
  let mut cubics = 0
  let mut closes = 0
  for verb in verbs {
    match verb {
      MoveTo(_) => moves += 1
      LineTo(_) => lines += 1
      QuadTo(_, _) => quads += 1
      CubicTo(_, _, _) => cubics += 1
      Close => closes += 1
    }
  }
  inspect(moves, content="1")
  inspect(lines, content="6")
  inspect(quads, content="4")
  inspect(cubics, content="4")
  inspect(closes, content="1")
  // 凹槽最低点挖进主体（y0 + 凹槽半径），凸头最低点凸出主体（y1 + 凸头半径）
  let y0 = rect.origin.y
  let y1 = rect.origin.y + rect.size.height
  let cx = rect.origin.x + rect.size.width / 2.0
  let mut notch_apex = 0.0
  let mut tab_apex = 0.0
  for verb in verbs {
    match verb {
      CubicTo(_, _, end) =>
        if end.x == cx && end.y > y0 && end.y < y1 {
          notch_apex = end.y
        } else if end.x == cx && end.y >= y1 {
          tab_apex = end.y
        }
      _ => ()
    }
  }
  inspect(notch_apex, content="70")
  inspect(tab_apex, content="142")
}

///|
test "外扩轮廓收窄凹槽、放大凸头" {
  let rect = node_rect({
    id: 1,
    kind: "Sequence",
    title: "A",
    x: 0.0,
    y: 0.0,
    config: [],
  })
  // 聚光灯外扩 6px：凹槽半径 10-6=4 仍为正，凸头半径 10+6=16
  let verbs = block_outline_verbs(rect, 6.0)
  let pts : Array[(Double, Double)] = []
  for verb in verbs {
    match verb {
      MoveTo(p) => pts.push((p.x, p.y))
      LineTo(p) => pts.push((p.x, p.y))
      CubicTo(a, b, c) => {
        pts.push((a.x, a.y))
        pts.push((b.x, b.y))
        pts.push((c.x, c.y))
      }
      _ => ()
    }
  }
  let mut min_x = 1.0e9
  let mut max_y = -1.0e9
  for point in pts {
    let (px, py) = point
    if px < min_x {
      min_x = px
    }
    if py > max_y {
      max_y = py
    }
  }
  // 外扩 6px：左缘 -6；底缘下移至 78，凸头半径 16 → 最低点 94
  inspect(min_x, content="-6")
  inspect(max_y, content="94")
}
