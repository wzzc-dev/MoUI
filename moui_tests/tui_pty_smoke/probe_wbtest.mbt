// 临时探针(不提交):选中带会不会在选中移开之后留在屏上。

///|
fn band_rows(session : Session, label : String) -> Unit {
  let screen = session.screen()
  let mut out = ""
  for row in 0..<screen.rows {
    let cols : Array[Int32] = []
    for col in 0..<screen.cols {
      if screen.at(row, col).style.reverse {
        cols.push(col)
      }
    }
    if !cols.is_empty() {
      out = out +
        "\n  row \{row}: \{cols.length()} 格反白 首=\{cols[0]} 尾=\{cols[cols.length() - 1]}"
    }
  }
  println("=== band \{label} ===\{out}")
}

///|
fn col_of(screen : Screen, row : Int32, ch : Char) -> Int32 {
  let mut col = 0
  while col < screen.cols {
    if screen.at(row, col).ch == ch {
      return col
    }
    col = col + 1
  }
  -1
}

///|
async fn tap(session : Session, row : Int32, col : Int32) -> Unit {
  session.send(
    "\u{1b}[<0;\{col + 1};\{row + 1}M\u{1b}[<0;\{col + 1};\{row + 1}m",
  )
  // 探针只为观察带流,点击后等重绘首字节再确认,避免读到半帧。
  session.await_reply()
}

///|
async test "probe stale band after moving selection" {
  match layers_binary() {
    None => println("probe: no layers binary")
    Some(path) => {
      let session = Session::open(path, cols=100, rows=30)
      session.await_frame(s => s.has("sel=Background"))
      let start = session.screen()
      let bg_row = match start.find_row("[x] Background") {
        Some(r) => r
        None => -1
      }
      let gr_row = match start.find_row("[x] Grid") {
        Some(r) => r
        None => -1
      }
      println("probe rows: background=\{bg_row} grid=\{gr_row}")
      band_rows(session, "startup")
      tap(session, bg_row, col_of(start, bg_row, '[') + 1)
      band_rows(session, "after tapping Background")
      println("line \{bg_row}: \{session.screen().line_text(bg_row)}")
      println("line \{bg_row + 1}: \{session.screen().line_text(bg_row + 1)}")
      let now = session.screen()
      let row2 = match now.find_row("[x] Grid") {
        Some(r) => r
        None => gr_row
      }
      tap(session, row2, col_of(now, row2, '[') + 1)
      band_rows(session, "after tapping Grid")
      println("line \{bg_row}: \{session.screen().line_text(bg_row)}")
      println("line \{bg_row + 1}: \{session.screen().line_text(bg_row + 1)}")
      println("status: \{session.screen().line_text(26)}")
      session.finish()
    }
  }
}
