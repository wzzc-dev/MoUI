///|
/// 图标路径的几何不变量：所有顶点都落在 24×24 视图框内（icon() 按
/// 视图框缩放，越界顶点会被裁掉——新图标必须过这道边界检查）。
test "all icon path verbs stay inside the 24x24 viewBox" {
  let names = [
    @style.Check,
    @style.Close,
    @style.ChevronDown,
    @style.ChevronRight,
    @style.ChevronLeft,
    @style.Plus,
    @style.Minus,
    @style.Search,
    @style.ArrowRight,
    @style.Settings,
    @style.Gear,
    @style.Trash,
    @style.Info,
    @style.FileNew,
    @style.FolderOpen,
    @style.Save,
    @style.Clipboard,
    @style.Bold,
    @style.Italic,
    @style.CodeInline,
    @style.Link,
    @style.Heading,
    @style.ListBullet,
    @style.ListOrdered,
    @style.ListTask,
    @style.Quote,
    @style.Table,
    @style.Eye,
    @style.Focus,
    @style.Columns,
    @style.Sidebar,
    @style.Pin,
    @style.Chat,
    @style.PanelBottom,
  ]
  for name in names {
    for verb in icon_path(name) {
      match verb {
        MoveTo(point) | LineTo(point) => {
          assert_true(point.x >= 0.0 && point.x <= 24.0)
          assert_true(point.y >= 0.0 && point.y <= 24.0)
        }
        QuadTo(control, point) => {
          assert_true(control.x >= 0.0 && control.x <= 24.0)
          assert_true(control.y >= 0.0 && control.y <= 24.0)
          assert_true(point.x >= 0.0 && point.x <= 24.0)
          assert_true(point.y >= 0.0 && point.y <= 24.0)
        }
        CubicTo(first, second, point) => {
          assert_true(first.x >= 0.0 && first.x <= 24.0)
          assert_true(first.y >= 0.0 && first.y <= 24.0)
          assert_true(second.x >= 0.0 && second.x <= 24.0)
          assert_true(second.y >= 0.0 && second.y <= 24.0)
          assert_true(point.x >= 0.0 && point.x <= 24.0)
          assert_true(point.y >= 0.0 && point.y <= 24.0)
        }
        Close => ()
      }
    }
  }
}

///|
test "pin icon has a closed head and a needle" {
  let verbs = icon_path(@style.Pin)
  // 头部闭合 + 针脚两段：MoveTo 2 次（头 + 针）、Close 1 次
  let mut moves = 0
  let mut closes = 0
  for verb in verbs {
    match verb {
      MoveTo(_) => moves = moves + 1
      Close => closes = closes + 1
      _ => ()
    }
  }
  assert_eq(moves, 2)
  assert_eq(closes, 1)
}
