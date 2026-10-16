///|
/// damage → ANSI。整屏脏就清屏重建,否则只按行定位重绘,
/// 未变的行一个字节都不出。
pub fn sgr(attrs : @tui.CellAttrs) -> String {
  let codes : Array[String] = []
  if attrs.bold {
    codes.push("1")
  }
  if attrs.dim {
    codes.push("2")
  }
  if attrs.italic {
    codes.push("3")
  }
  if attrs.underline {
    codes.push("4")
  }
  if attrs.reverse {
    codes.push("7")
  }
  match attrs.fg {
    @tui.Default => ()
    @tui.Indexed(i) => codes.push("38;5;" + i.to_string())
    @tui.Rgb(r, g, b) =>
      codes.push(
        "38;2;" + r.to_string() + ";" + g.to_string() + ";" + b.to_string(),
      )
  }
  match attrs.bg {
    @tui.Default => ()
    @tui.Indexed(i) => codes.push("48;5;" + i.to_string())
    @tui.Rgb(r, g, b) =>
      codes.push(
        "48;2;" + r.to_string() + ";" + g.to_string() + ";" + b.to_string(),
      )
  }
  if codes.is_empty() {
    "\u{1b}[0m"
  } else {
    "\u{1b}[0;" + codes.join(";") + "m"
  }
}

///|
/// 一行 = 若干同属性文本段。宽字符右半格已经在 `runs()` 里跳过。
pub fn ansi_runs(runs : Array[(String, Int, @tui.CellAttrs)]) -> String {
  let mut out = ""
  for run in runs {
    out = out + sgr(run.2) + run.0
  }
  out + "\u{1b}[0m"
}

///|
/// 脏行 → 逐行重绘指令。整屏脏时先清屏,避免缩小窗口后的残影。
pub fn frame_update(screen : @tui.TermScreen, damage : @tui.Damage) -> String {
  let targets : Array[Int] = []
  let rows = screen.rows()
  if damage.full {
    for y in 0..<rows {
      targets.push(y)
    }
  } else {
    for y in damage.rows {
      if y >= 0 && y < rows {
        targets.push(y)
      }
    }
  }
  if targets.is_empty() {
    return ""
  }
  let out : Array[String] = []
  if damage.full {
    out.push("\u{1b}[2J\u{1b}[H")
  }
  for y in targets {
    let locate = "\u{1b}[" + (y + 1).to_string() + ";1H\u{1b}[2K"
    out.push(locate + ansi_runs(screen.line_at(y).runs()))
  }
  out.join("")
}
