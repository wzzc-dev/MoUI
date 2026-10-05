///|
/// 哨兵协议解析测试:fixture 取自真实 harness 输出形态
/// (工具链日志噪声 + 哨兵 + 单行 JSON 信封)。

///|
/// counter 形真实载荷:命令含 FillRoundedRectBrush / DrawText / DrawPath /
/// PushClip / PopClip / 一个未知 op(验证诚实报告)。
fn preview_payload() -> String {
  (
    #|warning: some toolchain log line
    #|compiling module examples/counter
    #|__STUDIO_PREVIEW_V1__
    #|{"version":"1","width":640.0,"height":480.0,"commands":[["FillRoundedRectBrush",{"rect":{"origin":{"x":3,"y":40},"size":{"width":28,"height":28}},"radius":4},["Solid",{"r":0.169,"g":0.176,"b":0.188,"a":1}]],["DrawText",{"text":"MoUI Studio","frame":{"origin":{"x":44,"y":10},"size":{"width":96.638,"height":20}},"font":{"families":{"families":["SystemUi"]},"size":13,"weight":400,"style":"Normal","variations":[]},"color":{"r":0.875,"g":0.882,"b":0.898,"a":1},"align":"TextStart"}],["DrawPath",{"verbs":[["MoveTo",{"x":1,"y":2}],["LineTo",{"x":3,"y":4}]],"stroke":["Solid",{"r":0.5,"g":0.5,"b":0.5,"a":1}],"stroke_width":1.6}],["PushClip",{"origin":{"x":0,"y":0},"size":{"width":10,"height":10}}],["PopClip"],["MysteryOp",1]],"semantics":[{"role":"Main","label":"","frame":{"origin":{"x":0,"y":0},"size":{"width":640,"height":480}}},{"role":"Text","label":"MoUI Studio","frame":{"origin":{"x":44,"y":10},"size":{"width":96.638,"height":20}}}]}
  )
}

///|
test "哨兵协议:噪声分流 + 命令重建 + 未知 op 报告" {
  match parse_preview_frame(preview_payload()) {
    Ok(frame) => {
      assert_eq(frame.version, 1)
      assert_eq(frame.width, 640.0)
      assert_eq(frame.height, 480.0)
      // 6 条命令全部重建;未知 op 记入 unknown_ops 且不混进命令
      assert_eq(frame.commands.length(), 5)
      assert_eq(frame.unknown_ops, ["MysteryOp"])
    }
    Err(msg) => fail("真实载荷应可解析:\{msg}")
  }
}

///|
test "哨兵协议:重建的命令类型正确(毛刺不混类)" {
  match parse_preview_frame(preview_payload()) {
    Ok(frame) => {
      // [0] FillRoundedRectBrush → 画笔为 Solid
      let mut brush_ok = false
      let mut text_ok = false
      for command in frame.commands {
        match command {
          @core.FillRoundedRectBrush(_, @core.Solid(_)) => brush_ok = true
          @core.DrawText(run) => if run.text == "MoUI Studio" { text_ok = true }
          _ => ()
        }
      }
      assert_true(brush_ok, msg="应重建出 FillRoundedRectBrush")
      assert_true(text_ok, msg="应重建出 DrawText 且文本保留")
    }
    Err(msg) => fail("真实载荷应可解析:\{msg}")
  }
}

///|
test "哨兵协议:无哨兵报结构化错误" {
  match parse_preview_frame("just toolchain logs\nnothing else") {
    Err(msg) => assert_true(msg.contains("哨兵"), msg~)
    Ok(_) => fail("无哨兵应失败")
  }
}

///|
test "哨兵协议:版本不匹配报错" {
  let payload =
    #|__STUDIO_PREVIEW_V1__
    #|{"version":"99","width":640.0,"height":480.0,"commands":[],"semantics":[]}
  match parse_preview_frame(payload) {
    Err(msg) => assert_true(msg.contains("版本"), msg~)
    Ok(_) => fail("版本不匹配应失败")
  }
}
