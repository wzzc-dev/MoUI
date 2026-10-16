///|
/// 角色投影策略。语义树里没有「这个容器有没有边框」这种视觉事实,
/// 所以画不画框必须由投影器决定,而不是由控件决定。类分五档:
/// - `Region` 区域容器:画边框盒,自己不写字(命名区域的框就是它的表达)
/// - `Item` 结构条目(List/Tree 的一行):自己不写字,内容归子节点,
///   焦点/选中由整行高亮带表达
/// - `Label` 自带文本的条目(Tab/Option/Cell/Link):写字,不画框
/// - `Content` 叶子内容:把自己的文本写进量化盒
/// - `Placeholder` 不可投影控件:固定占位文本并写诊断,不允许静默消失
///
/// 放弃的方案:每个容器都画「带标题的盒」。实测证明它把
/// `Selectable list`、`Entry 0, row 0` 这类聚合名字画在条目同一行上,
/// 被更深一层的文本打断成 `e list`、`EnEntry 0row 0` 这种残字 ——
/// 半截标题比没有标题更难读。
pub(all) enum RoleKind {
  Region
  Item
  Label
  Content
  Placeholder
} derive(Eq, Debug)

///|
pub extend RoleKind with Debug::{to_repr}

///|
pub extend RoleKind with Eq::{not_equal, equal}

///|
/// 绘制优先级:边框 1 < 标题 2 < 叶子内容 3。同优先级先到先得。
/// `Item` 不写字,拿边框档,免得它的占位符挤掉真正的叶子。
pub fn role_priority(kind : RoleKind) -> Int {
  match kind {
    Region | Item => 1
    Label => 2
    Content | Placeholder => 3
  }
}

///|
pub fn role_tag(role : @core.SemanticsRole) -> String {
  match role {
    @core.Text => "Text"
    @core.Link => "Link"
    @core.Heading => "Heading"
    @core.Navigation => "Navigation"
    @core.Main => "Main"
    @core.Button => "Button"
    @core.Checkbox => "Checkbox"
    @core.TextField => "TextField"
    @core.List => "List"
    @core.ListItem => "ListItem"
    @core.Grid => "Grid"
    @core.ScrollView => "ScrollView"
    @core.Switch => "Switch"
    @core.Radio => "Radio"
    @core.Slider => "Slider"
    @core.Progress => "Progress"
    @core.Tab => "Tab"
    @core.Dialog => "Dialog"
    @core.Tooltip => "Tooltip"
    @core.Menu => "Menu"
    @core.ButtonGroup => "ButtonGroup"
    @core.Form => "Form"
    @core.FormField => "FormField"
    @core.Tree => "Tree"
    @core.TreeItem => "TreeItem"
    @core.Group => "Group"
    @core.WebView => "WebView"
    @core.Image => "Image"
    @core.Alert => "Alert"
    @core.Status => "Status"
    @core.ComboBox => "ComboBox"
    @core.Option => "Option"
    @core.Table => "Table"
    @core.Row => "Row"
    @core.Cell => "Cell"
    @core.Separator => "Separator"
    @core.None => "None"
  }
}

///|
/// 全匹配 `SemanticsRole`,新增角色会让这里编译失败,而不是静默降级。
pub fn role_kind(role : @core.SemanticsRole) -> RoleKind {
  match role {
    @core.Group
    | @core.List
    | @core.Grid
    | @core.Main
    | @core.Navigation
    | @core.Form
    | @core.FormField
    | @core.Table
    | @core.Menu
    | @core.Tree
    | @core.ScrollView
    | @core.Dialog
    | @core.ButtonGroup => Region
    @core.Row | @core.ListItem | @core.TreeItem | @core.Separator => Item
    @core.Tab | @core.Option | @core.Cell | @core.Link | @core.Tooltip => Label
    @core.Image | @core.WebView => Placeholder
    @core.Text
    | @core.Status
    | @core.Alert
    | @core.Heading
    | @core.Button
    | @core.Checkbox
    | @core.Switch
    | @core.Radio
    | @core.TextField
    | @core.ComboBox
    | @core.Slider
    | @core.Progress
    | @core.None => Content
  }
}

///|
fn fg(color : @tui.TermColor) -> @tui.CellAttrs {
  @tui.attrs_with(@tui.CellAttrs::default(), fg=Some(color))
}

///|
/// 语义状态 + 角色 → SGR 属性。焦点与选中必须有可见差异,
/// 否则键盘导航在终端里无法辨认。
pub fn attrs_for(role : String, state : @core.SemanticsState) -> @tui.CellAttrs {
  let interactive = [
    "TextField", "ComboBox", "Slider", "Progress", "Checkbox", "Switch", "Radio",
  ]
  let base = if state.focused {
    @tui.attrs_with(fg(@tui.Indexed(3)), bold=Some(true), underline=Some(true))
  } else if role == "Button" {
    @tui.attrs_with(fg(@tui.Indexed(4)), bold=Some(true))
  } else if role == "Heading" {
    @tui.attrs_with(fg(@tui.TermColor::Default), bold=Some(true))
  } else if role == "Text" || role == "Status" || role == "Alert" {
    fg(@tui.Indexed(2))
  } else if interactive.contains(role) {
    fg(@tui.Indexed(5))
  } else {
    fg(@tui.Indexed(6))
  }
  let selected = if state.selected {
    @tui.attrs_with(base, reverse=Some(true))
  } else {
    base
  }
  if state.pressed && !selected.bold {
    @tui.attrs_with(selected, bold=Some(true))
  } else {
    selected
  }
}
