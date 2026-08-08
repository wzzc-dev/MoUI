///|
/// Render HTML through crater and translate to MoUI draw commands.
fn render(html : String) -> Array[@core.DrawCommand] {
  let size = @values.Size::new(400.0, 300.0)
  let tree = @crater.render_html_to_paint_tree(html, size)
  paint_node_to_commands(tree)
}

///|
/// body 根节点自身的背景也会被翻译
test "background rect" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;background:#ff0000\"></div>",
  )
  let fills = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRect(rect, color) => Some((rect, color))
      _ => None
    }
  })
  inspect(fills.length(), content="1")
  let (rect, color) = fills[0]
  // body 默认 margin 8px,坐标现在正确累加为绝对位置
  inspect(rect.origin.x, content="8")
  inspect(rect.origin.y, content="8")
  inspect(rect.size.width, content="100")
  inspect(rect.size.height, content="50")
  inspect(color.r, content="1")
  inspect(color.a, content="1")
}

///|
/// 嵌套节点坐标累加为绝对坐标(body margin 8 + padding 10 = 18)
test "nested coordinates accumulate" {
  let cmds = render(
    "<div style=\"width:200px;height:200px;background:#0000ff;padding:10px\"><div style=\"width:50px;height:50px;background:#ff0000\"></div></div>",
  )
  let fills = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRect(rect, _) => Some(rect)
      _ => None
    }
  })
  inspect(fills.length(), content="2")
  inspect(fills[0].origin.x, content="8")
  inspect(fills[1].origin.x, content="18")
  inspect(fills[1].origin.y, content="18")
}

///|
/// 非均匀边框嵌套时也使用绝对坐标(父 offset 累加)
test "uneven borders use accumulated offset" {
  let cmds = render(
    "<div style=\"width:200px;height:200px;background:#0000ff;padding:10px\"><div style=\"width:50px;height:50px;border-bottom:3px solid #ff0000\"></div></div>",
  )
  let fills = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRect(rect, color) => Some((rect, color))
      _ => None
    }
  })
  // 父背景 + 子下边框
  inspect(fills.length(), content="2")
  let (bottom, color) = fills[1]
  inspect(color.r, content="1")
  inspect(bottom.origin.y, content="68") // 8 + 10 + (50+3 border-box) - 3
  inspect(bottom.size.height, content="3")
}

///|
/// opacity 作用域包裹背景与阴影(组 opacity 语义)
test "opacity wraps background" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;background:#ff0000;opacity:0.5\"></div>",
  )
  let mut push_index = -1
  let mut bg_index = -1
  for i in 0..<cmds.length() {
    match cmds[i] {
      @core.DrawCommand::PushOpacity(0.5) => push_index = i
      @core.DrawCommand::FillRect(
        { origin: { x: 8.0, y: 8.0 }, size: { width: 100.0, height: 50.0 } },
        { r: 1.0, g: 0.0, b: 0.0, a: 1.0 }
      ) => bg_index = i
      _ => ()
    }
  }
  inspect(push_index >= 0, content="true")
  inspect(bg_index >= 0, content="true")
  inspect(bg_index > push_index, content="true")
}

///|
/// border-radius -> FillRoundedRect
test "rounded background" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;background:#00ff00;border-radius:8px\"></div>",
  )
  let roundeds = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRoundedRect(rounded, _) => Some(rounded)
      _ => None
    }
  })
  inspect(roundeds.length(), content="1")
  inspect(roundeds[0].radius, content="8")
  inspect(roundeds[0].rect.size.width, content="100")
}

///|
/// 文本节点 -> DrawText(颜色、字体、几何来自 paint tree)
test "text draws" {
  let cmds = render(
    "<div style=\"width:100px;height:20px;color:#123456;font-size:16px\">hi</div>",
  )
  let texts = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::DrawText(run) => Some(run)
      _ => None
    }
  })
  inspect(texts.length(), content="1")
  inspect(texts[0].text, content="hi")
  inspect(texts[0].font.size, content="16")
  inspect(texts[0].color.r, content="0.07058823529411765")
}

///|
/// 等宽边框 -> StrokeRect
test "uniform border strokes" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;border:2px solid #000000\"></div>",
  )
  let strokes = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::StrokeRect(rect, color, width) =>
        Some((rect, color, width))
      _ => None
    }
  })
  inspect(strokes.length(), content="1")
  let (rect, color, width) = strokes[0]
  inspect(rect.size.width, content="104")
  inspect(color.r, content="0")
  inspect(width, content="2")
}

///|
/// box-shadow -> DrawShadow
test "box shadow maps" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;box-shadow:3px 4px 5px #000000\"></div>",
  )
  let shadows = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::DrawShadow(shadow) => Some(shadow)
      _ => None
    }
  })
  inspect(shadows.length(), content="1")
  inspect(shadows[0].offset.x, content="3")
  inspect(shadows[0].offset.y, content="4")
  inspect(shadows[0].blur_radius, content="5")
}

///|
/// opacity -> PushOpacity/PopOpacity 包围子内容
test "opacity scopes" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;background:#ff0000;opacity:0.5\"></div>",
  )
  let pushes = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::PushOpacity(v) => Some(v)
      _ => None
    }
  })
  let pops = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::PopOpacity => Some(true)
      _ => None
    }
  })
  inspect(pushes.length(), content="1")
  inspect(pushes[0], content="0.5")
  inspect(pops.length(), content="1")
}

///|
/// overflow hidden -> PushClip/PopClip
test "clip scopes" {
  let cmds = render(
    "<div style=\"width:100px;height:50px;overflow:hidden\"><div style=\"width:200px;height:200px;background:#ff0000\"></div></div>",
  )
  let clips = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::PushClip(rect) => Some(rect)
      _ => None
    }
  })
  let pops = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::PopClip => Some(true)
      _ => None
    }
  })
  inspect(clips.length(), content="1")
  inspect(clips[0].size.width, content="100")
  inspect(pops.length(), content="1")
}

///|
/// 子节点出现在父节点背景之后,clip 作用域包裹子节点
test "children nested inside scopes" {
  let cmds = render(
    "<div style=\"width:100px;height:100px;background:#0000ff\"><div style=\"width:40px;height:40px;background:#ff0000\"></div></div>",
  )
  // 按序:父 FillRect、子 FillRect
  let fills = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRect(_rect, color) => Some(color)
      _ => None
    }
  })
  inspect(fills.length(), content="2")
  inspect(fills[0].b, content="1")
  inspect(fills[1].r, content="1")
}

///|
/// data URI 图片 -> DrawImage
test "data uri image maps" {
  let cmds = render(
    "<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==\" width=\"10\" height=\"10\">",
  )
  let images = cmds.filter_map(fn(c) {
    match c {
      @core.DrawCommand::DrawImage(image) => Some(image)
      _ => None
    }
  })
  inspect(images.length(), content="1")
  inspect(images[0].frame.size.width, content="10")
  inspect(images[0].source.has_prefix("data:image/png"), content="true")
}

///|
/// 文字 frame 高度不低于字号:crater 行盒(line-height)小于字号时,
/// MoUI 按 frame 裁剪会切掉字形,翻译器必须抬高 frame 高度。
test "text frame height is at least font size" {
  let html = "<div style='font-size:20px;line-height:16px;height:16px'>Big</div>"
  let commands = render(html)
  let mut checked = false
  for c in commands {
    match c {
      @core.DrawCommand::DrawText(run) => {
        debug_inspect(run.text, content="\"Big\"")
        debug_inspect(run.frame.size.height >= run.font.size, content="true")
        debug_inspect(run.font.size, content="20")
        checked = true
      }
      _ => ()
    }
  }
  debug_inspect(checked, content="true")
}
