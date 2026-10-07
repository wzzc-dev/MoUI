///|
/// G3:markdown 面板渲染管线测试——迷你程序渲染一次 draw 命令,断言
/// 内容文本出现且 `#` 标记被格式渲染消费;内容增长 → 高度增长。

///|
/// 渲染辅助：以给定视图建迷你程序,draw 一次取命令流。
fn[Msg] draw_view(
  view : @moui.View[Msg],
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Int, Msg] = @moui.Program::new_with_environment(
    init=() => (0, @moui.Effect::none()),
    update=(current, _) => (current, @moui.Effect::none()),
    view=(_, _) => view,
  )
  @runtime.new_program_with_dimensions(program~, width~, height~).draw_commands()
}

///|
fn md_font() -> @text.FontSpec {
  @text.FontSpec::new(size=13.0)
}

///|
fn md_colors() -> (@graphics.Color, @graphics.Brush) {
  let foreground = @graphics.Color::rgba(r=0.88, g=0.88, b=0.9)
  (foreground, @graphics.Brush::solid(foreground))
}

///|
test "markdown 面板:标题文本渲染,标记被消费" {
  let (foreground, background) = md_colors()
  let view = markdown_file_view(
    content="# 安装指南\n\n先安装工具链。",
    on_input=_ => 0,
    width=600.0,
    height=400.0,
    font=md_font(),
    foreground~,
    placeholder_color=foreground,
    background~,
    cursor_color=foreground,
  )
  let commands = draw_view(view, 600.0, 400.0)
  let mut heading_found = false
  let mut marker_leaked = false
  for command in commands {
    match command {
      @core.DrawText(run) => {
        if run.text.contains("安装指南") {
          heading_found = true
        }
        if run.text.contains("# 安装指南") {
          marker_leaked = true
        }
      }
      _ => ()
    }
  }
  assert_true(heading_found, msg="标题文本应被渲染")
  assert_false(marker_leaked, msg="行内 `#` 标记应被格式渲染消费")
}

///|
test "markdown 内容高度随内容增长" {
  let short = markdown_content_height(
    content="一行",
    width=600.0,
    font=md_font(),
  )
  let long = markdown_content_height(
    content="一行\n\n两行\n\n三行\n\n四行\n\n五段更长的内容会继续向下延展渲染高度。",
    width=600.0,
    font=md_font(),
  )
  assert_true(
    long > short,
    msg="更多内容应量出更高渲染高度:\{short} vs \{long}",
  )
}
