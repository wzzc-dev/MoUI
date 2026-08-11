///|
/// Translate a crater `PaintNode` tree into MoUI `DrawCommand`s.
///
/// The recursion mirrors crater's paint order: shadows -> background ->
/// (clip/opacity scopes) -> children (stacking order) -> text/image ->
/// borders -> polygon. Clip and opacity scopes are pushed before children
/// and popped after, matching MoUI's stack-based draw model.
pub fn paint_node_to_commands(
  root : @paint_model.PaintNode,
) -> Array[@core.DrawCommand] {
  let sorted_root = @paint_build.sort_tree_by_stacking_order(root)
  let out : Array[@core.DrawCommand] = []
  walk_node(sorted_root, 0.0, 0.0, out)
  out
}

///|
fn walk_node(
  node : @paint_model.PaintNode,
  offset_x : Double,
  offset_y : Double,
  out : Array[@core.DrawCommand],
) -> Unit {
  if !node.paint.should_render() {
    return
  }
  let rect = node_rect(node, offset_x, offset_y)
  let radius = max_radius(node)

  // 装饰顺序对齐 crater 光栅化器:shadows -> background -> borders,全部
  // 包裹在 clip/opacity 作用域内(与 crater 的 group-opacity 语义一致)。
  // Clip scope.
  let clips = node.clips_content()
  if clips {
    out.push(@core.DrawCommand::PushClip(rect))
  }

  // Opacity scope.
  let opacity = node.paint.opacity
  if opacity < 1.0 {
    out.push(@core.DrawCommand::PushOpacity(opacity))
  }

  // Box shadows (outer only; inset shadows are approximated by borders).
  for shadow in node.paint.box_shadows {
    if !shadow.inset {
      out.push(
        @core.DrawCommand::DrawShadow({
          rect: { rect, radius },
          color: to_moui_color(shadow.color),
          offset: { x: shadow.offset_x, y: shadow.offset_y },
          blur_radius: shadow.blur_radius,
          spread: shadow.spread_radius,
        }),
      )
    }
  }

  // Background.
  let bg = node.paint.background_color
  if !bg.is_transparent() {
    if radius > 0.0 {
      out.push(
        @core.DrawCommand::FillRoundedRect({ rect, radius }, to_moui_color(bg)),
      )
    } else {
      out.push(@core.DrawCommand::FillRect(rect, to_moui_color(bg)))
    }
  }

  // Borders (before children, matching crater paint order).
  draw_borders(node, offset_x, offset_y, out)

  // Children are already in stacking order after sort_tree_by_stacking_order.
  for child in node.children {
    walk_node(child, offset_x + node.x, offset_y + node.y, out)
  }

  // Own text.
  match node.text {
    Some(text) => {
      // crater 的行盒高度(line-height)可能小于字号(如 HN header 12px 盒
      // vs 13.33px 字),MoUI 渲染器按 frame 定位/裁剪文字会导致裁切;
      // 文字 frame 高度至少取字号,保证字形完整。
      // (宽度不加余量:crater 布局已用 0.6em 比例留足,余量会造成
      //  文字与同行后续内容重叠)
      let font = font_spec(node.paint)
      let text_height = if rect.size.height < font.size {
        font.size
      } else {
        rect.size.height
      }
      out.push(
        @core.DrawCommand::DrawText({
          text,
          frame: {
            origin: rect.origin,
            size: { width: rect.size.width, height: text_height },
          },
          font,
          color: to_moui_color(node.paint.color),
          align: @core.TextAlign::TextStart,
        }),
      )
    }
    None => ()
  }

  // Own image (`src` is a data URI carried through the paint tree).
  match node.src {
    Some(src) =>
      out.push(
        @core.DrawCommand::DrawImage({
          source: src,
          frame: rect,
          opacity: 1.0,
          fit: @core.ImageFit::Stretch,
        }),
      )
    None => ()
  }

  // Visual polygon (e.g. clip-path geometry); crater builds the points from
  // the node's own parent-relative layout offsets, so only the accumulated
  // ancestor offset belongs here.
  if node.visual_polygon.length() >= 3 {
    let verbs : Array[@core.PathVerb] = []
    let mut first = true
    for i in 0..<node.visual_polygon.length() {
      let (x, y) = node.visual_polygon[i]
      let px = x + offset_x
      let py = y + offset_y
      if first {
        verbs.push(@core.PathVerb::MoveTo({ x: px, y: py }))
        first = false
      } else {
        verbs.push(@core.PathVerb::LineTo({ x: px, y: py }))
      }
    }
    verbs.push(@core.PathVerb::Close)
    out.push(
      @core.DrawCommand::DrawPath({
        verbs,
        fill: Some(@core.Brush::Solid(to_moui_color(node.paint.color))),
        stroke: None,
        stroke_width: 0.0,
      }),
    )
  }

  if opacity < 1.0 {
    out.push(@core.DrawCommand::PopOpacity)
  }
  if clips {
    out.push(@core.DrawCommand::PopClip)
  }
}

///|
fn node_rect(
  node : @paint_model.PaintNode,
  offset_x : Double,
  offset_y : Double,
) -> @core.Rect {
  {
    origin: { x: node.x + offset_x, y: node.y + offset_y },
    size: { width: node.width, height: node.height },
  }
}

///|
fn max_radius(node : @paint_model.PaintNode) -> Double {
  let p = node.paint
  let mut m = 0.0
  for
    r in [
      p.border_top_left_radius,
      p.border_top_right_radius,
      p.border_bottom_right_radius,
      p.border_bottom_left_radius,
    ] {
    if r > m {
      m = r
    }
  }
  m
}

///|
/// crater color (0-255 ints + alpha) -> MoUI color (0-1 doubles)
pub fn to_moui_color(c : @values.Color) -> @core.Color {
  {
    r: c.r.to_double() / 255.0,
    g: c.g.to_double() / 255.0,
    b: c.b.to_double() / 255.0,
    a: c.a,
  }
}

///|
fn font_spec(p : @paint_model.PaintProperties) -> @core.FontSpec {
  {
    families: { families: [to_font_family(p.font_family)] },
    size: p.font_size,
    weight: if p.is_bold {
      700
    } else {
      p.font_weight.to_int()
    },
    style: @core.FontStyle::Normal,
    variations: [],
  }
}

///|
fn to_font_family(name : String) -> @core.FontFamily {
  match name {
    "monospace" | "ui-monospace" => @core.FontFamily::Monospace
    "serif" => @core.FontFamily::Serif
    "sans-serif" | "system-ui" | "ui-sans-serif" => @core.FontFamily::SystemUi
    _ => @core.FontFamily::Name(name)
  }
}

///|
fn draw_borders(
  node : @paint_model.PaintNode,
  offset_x : Double,
  offset_y : Double,
  out : Array[@core.DrawCommand],
) -> Unit {
  let p = node.paint
  let t = p.border_top_width
  let r = p.border_right_width
  let b = p.border_bottom_width
  let l = p.border_left_width
  if t <= 0.0 && r <= 0.0 && b <= 0.0 && l <= 0.0 {
    return
  }
  if t == r &&
    r == b &&
    b == l &&
    p.border_top_color == p.border_bottom_color &&
    p.border_top_color == p.border_left_color &&
    p.border_top_color == p.border_right_color {
    out.push(
      @core.DrawCommand::StrokeRect(
        node_rect(node, offset_x, offset_y),
        to_moui_color(p.border_top_color),
        t,
      ),
    )
    return
  }
  // Uneven borders: draw each side as a filled rect, derived from the
  // absolute (offset-accumulated) rect so nested nodes land correctly.
  let rect = node_rect(node, offset_x, offset_y)
  let x = rect.origin.x
  let y = rect.origin.y
  let w = rect.size.width
  let h = rect.size.height
  if t > 0.0 {
    out.push(
      @core.DrawCommand::FillRect(
        { origin: { x, y }, size: { width: w, height: t } },
        to_moui_color(p.border_top_color),
      ),
    )
  }
  if b > 0.0 {
    out.push(
      @core.DrawCommand::FillRect(
        { origin: { x, y: y + h - b }, size: { width: w, height: b } },
        to_moui_color(p.border_bottom_color),
      ),
    )
  }
  if l > 0.0 {
    out.push(
      @core.DrawCommand::FillRect(
        { origin: { x, y }, size: { width: l, height: h } },
        to_moui_color(p.border_left_color),
      ),
    )
  }
  if r > 0.0 {
    out.push(
      @core.DrawCommand::FillRect(
        { origin: { x: x + w - r, y }, size: { width: r, height: h } },
        to_moui_color(p.border_right_color),
      ),
    )
  }
}
