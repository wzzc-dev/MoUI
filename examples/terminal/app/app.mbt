///|
/// 终端应用模型:屏幕缓冲区 + 解析器 + 回看滚动偏移 + 主题偏好。
pub(all) struct Model {
  screen : TermScreen
  parser : VtParser
  mut scroll_offset : Int
  mut theme_pref : ThemePreference
  mut selection : Selection?
  mut selection_dragging : Bool
}

///|
pub(all) enum Msg {
  Feed(Bytes)
  Resize(Int, Int)
  WriteInput(String)
  ScrollBy(Int)
  SetTheme(ThemePreference)
  SelectionBegin(Int, Int)
  SelectionMove(Int, Int)
  SelectionEnd
  Copy
}

///|
pub fn Model::new(cols : Int, rows : Int) -> Model {
  let screen = TermScreen::new(cols, rows)
  let parser = VtParser::new(screen)
  {
    screen,
    parser,
    scroll_offset: 0,
    theme_pref: ThemePreference::System,
    selection: None,
    selection_dragging: false,
  }
}

///|
pub fn Model::screen(self : Model) -> TermScreen {
  self.screen
}

///|
pub fn Model::scroll_offset(self : Model) -> Int {
  self.scroll_offset
}

///|
pub fn Model::theme_pref(self : Model) -> ThemePreference {
  self.theme_pref
}

///|
pub fn Model::selection(self : Model) -> Selection? {
  self.selection
}

///|
/// 把回看偏移限制在合法范围。
fn Model::clamp_scroll(self : Model) -> Unit {
  let max_offset = self.screen.total_lines() - self.screen.rows()
  if self.scroll_offset > max_offset {
    self.scroll_offset = max_offset
  }
  if self.scroll_offset < 0 {
    self.scroll_offset = 0
  }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Msg::Feed(bytes) => {
      model.parser.feed_bytes(bytes)
      // ESC c / ED 3 等会清空回看,偏移需重新收敛到合法范围
      model.clamp_scroll()
      model
    }
    Msg::Resize(cols, rows) => {
      model.screen.resize(cols, rows)
      model.clamp_scroll()
      model
    }
    Msg::WriteInput(_) => {
      // 输入时回到最新输出(滚动回底部)
      model.scroll_offset = 0
      model
    }
    Msg::ScrollBy(delta) => {
      model.scroll_offset = model.scroll_offset + delta
      model.clamp_scroll()
      model
    }
    Msg::SetTheme(pref) => {
      model.theme_pref = pref
      model
    }
    Msg::SelectionBegin(row, col) => {
      model.selection = Some(Selection::new(row, col, row, col))
      model.selection_dragging = true
      model
    }
    Msg::SelectionMove(row, col) => {
      if model.selection_dragging {
        match model.selection {
          Some(sel) =>
            model.selection = Some(
              Selection::new(sel.anchor_row, sel.anchor_col, row, col),
            )
          None => model.selection = Some(Selection::new(row, col, row, col))
        }
      }
      model
    }
    Msg::SelectionEnd => {
      model.selection_dragging = false
      model
    }
    Msg::Copy => model // 复制动作由宿主(平台)处理,app 只提供 selection_text
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let theme = theme_for_pref(model.theme_pref)
  terminal_view(
    model.screen,
    theme,
    scroll_offset=model.scroll_offset,
    selection=model.selection,
  )
}
