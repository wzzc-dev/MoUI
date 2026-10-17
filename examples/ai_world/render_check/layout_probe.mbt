///|
/// Layout variants for the short-window problem, probed without the browser.

///|
using @views {button, column, expanded, flexible, row, scroll_view, text}

///|
fn mini_stage() -> @moui.View[Unit] {
  column(
    [
      text("标题", role=Body, width=520.0, height=26.0, align=TextStart),
      text(
        "说明说明说明",
        role=Caption,
        width=520.0,
        height=34.0,
        align=TextStart,
      ),
      flexible(
        scroll_view(
          column(
            [text("对话行", role=Body, width=520.0, height=22.0)],
            spacing=4.0,
          ),
          width=520.0,
        ),
        weight=1.0,
      ),
      column(
        [
          text(
            "（输入框）",
            role=Body,
            width=520.0,
            height=56.0,
            align=TextStart,
          ),
          text(
            "[发送] [换角色]",
            role=Body,
            width=520.0,
            height=28.0,
            align=TextStart,
          ),
        ],
        spacing=6.0,
      ),
    ],
    spacing=8.0,
  )
}

///|
fn composer_bottom(commands : Array[@core.DrawCommand]) -> Double {
  let mut bottom = 0.0
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if run.text == "（输入框）" {
          bottom = run.frame.origin.y + run.frame.size.height
        }
      _ => ()
    }
  }
  bottom
}

///|
fn map_clip_height(commands : Array[@core.DrawCommand]) -> Double {
  let mut height = 0.0
  for command in commands {
    match command {
      @core.PushClip(rect) =>
        if rect.origin.x > 400.0 && rect.size.width >= 400.0 {
          height = rect.size.height
        }
      _ => ()
    }
  }
  height
}

///|
test "variant B: center+card with inner expanded row keeps composer visible" {
  // B: root column (no center), card wrapped around an expanded row.
  let view = column(
    [
      text("header", role=Body, width=1380.0, height=34.0, align=TextStart),
      expanded(
        row(
          [
            column(
              [
                text(
                  "左栏",
                  role=Body,
                  width=310.0,
                  height=460.0,
                  align=TextStart,
                ),
              ],
              spacing=8.0,
            ),
            mini_stage(),
            column(
              [
                text(
                  "右栏",
                  role=Body,
                  width=330.0,
                  height=330.0,
                  align=TextStart,
                ),
              ],
              spacing=8.0,
            ),
          ],
          spacing=20.0,
        ),
        weight=1.0,
      ),
    ],
    spacing=14.0,
  )
  let short = @runtime.new_view(
    root=view,
    size=@core.Size::new(width=1400.0, height=780.0),
  )
  let bottom = composer_bottom(short.draw_commands())
  inspect(bottom <= 780.0 && bottom > 0.0, content="true")
  let tall = @runtime.new_view(
    root=view,
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let bottom2 = composer_bottom(tall.draw_commands())
  inspect(bottom2 <= 1080.0 && bottom2 > 0.0, content="true")
  ignore(map_clip_height(tall.draw_commands()))
}
