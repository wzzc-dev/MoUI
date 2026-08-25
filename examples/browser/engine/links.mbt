///|
pub struct LinkRegion {
  x : Double
  y : Double
  width : Double
  height : Double
  href : String
}

///|
pub struct RenderResult {
  commands : Array[@core.DrawCommand]
  links : Array[LinkRegion]
}

///|
/// Render HTML and extract pixel-space link regions.
///
/// Before rendering, every `<a ...>` start tag is rewritten with a unique
/// synthetic `id="__crater_lnk_N"` appended at the end of the tag (so a
/// pre-existing `id` attribute loses per crater's last-wins tokenizer), and
/// its `href` is captured in the same quote-aware scan. The paint tree then
/// carries the synthetic id on each anchor node, so frames and hrefs pair by
/// id — invisible links (`display:none` nodes have zero size; `visibility`
/// hidden nodes fail `should_render`) never shift subsequent pairings.
/// Script bodies and HTML comments are skipped so their contents cannot be
/// mistaken for anchors.
pub fn render_html_document(
  html : String,
  width : Double,
  height : Double,
) -> RenderResult {
  // crater 默认用 0.5em/字符的 monospace 近似度量文本宽度,proportional
  // 字体(尤其大写/标点)实际更宽,会导致文字溢出布局宽度(被渲染器
  // clip 截断或与同行后续内容重叠)。用浏览器校准比例 0.6 让布局宽度
  // 更接近实际(换行偏早、行尾留白,但不截断不重叠)。全局设置一次。
  @layout_inline.set_builtin_text_advance_ratio(0.6)
  let (injected, hrefs) = inject_anchor_ids(html)
  let tree = @crater.render_html_to_paint_tree(
    injected,
    @values.Size::new(width, height),
  )
  let commands = @translate.paint_node_to_commands(tree)
  let links = collect_anchor_links(tree, hrefs)
  { commands, links }
}

///|
/// Scan `<a ...>` start tags: capture `href` and rewrite the tag to append
/// `id="__crater_lnk_N"` in document order. Returns the rewritten HTML and
/// the href list (None for anchors without a parseable href) indexed by the
/// synthetic id suffix.
fn inject_anchor_ids(html : String) -> (String, Array[String?]) {
  let hrefs : Array[String?] = []
  let buf = StringBuilder()
  let len = html.length()
  let mut i = 0
  let mut n = 0
  while i < len {
    // Skip HTML comments.
    if i + 3 < len &&
      html[i] == '<' &&
      html[i + 1] == '!' &&
      html[i + 2] == '-' &&
      html[i + 3] == '-' {
      let mut j = i + 4
      while j + 2 < len &&
            !(html[j] == '-' && html[j + 1] == '-' && html[j + 2] == '>') {
        j = j + 1
      }
      let end = if j + 2 < len { j + 3 } else { len }
      buf.write_string(html.unsafe_substring(start=i, end~))
      i = end
      continue
    }
    // Skip <script>...</script> bodies.
    if is_script_start(html, i) {
      let mut j = i
      while j + 8 < len {
        let c = html[j]
        let c2 = html[j + 1]
        if (c == '<' || c == '/') &&
          (c2 == 's' || c2 == 'S') &&
          (html[j + 2] == 'c' || html[j + 2] == 'C') &&
          (html[j + 3] == 'r' || html[j + 3] == 'R') &&
          (html[j + 4] == 'i' || html[j + 4] == 'I') &&
          (html[j + 5] == 'p' || html[j + 5] == 'P') &&
          (html[j + 6] == 't' || html[j + 6] == 'T') {
          let after = html[j + 7]
          if c == '/' &&
            (after == ' ' || after == '\t' || after == '\n' || after == '>') {
            break
          }
        }
        j = j + 1
      }
      let mut end = j
      while end < len && html[end] != '>' {
        end = end + 1
      }
      end = if end < len { end + 1 } else { len }
      buf.write_string(html.unsafe_substring(start=i, end~))
      i = end
      continue
    }
    if html[i] == '<' &&
      i + 1 < len &&
      (html[i + 1] == 'a' || html[i + 1] == 'A') {
      let j = i + 2
      let next = if j < len { html[j] } else { ' ' }
      let is_tag = next == ' ' ||
        next == '\t' ||
        next == '\n' ||
        next == '\r' ||
        next == '>' ||
        next == '/'
      if is_tag {
        // Quote-aware scan to the tag end; capture href in the same pass.
        let mut k = j
        let mut href : String? = None
        let mut quote : UInt16 = 0
        while k < len {
          let c = html[k]
          if quote != 0 {
            if c == quote {
              quote = 0
            }
          } else if c == '"' || c == '\'' {
            quote = c
          } else if c == '>' {
            break
          } else if k + 4 < len &&
            (c == 'h' || c == 'H') &&
            (html[k + 1] == 'r' || html[k + 1] == 'R') &&
            (html[k + 2] == 'e' || html[k + 2] == 'E') &&
            (html[k + 3] == 'f' || html[k + 3] == 'F') &&
            html[k + 4] == '=' {
            let q = k + 5
            if q < len && (html[q] == '"' || html[q] == '\'') {
              let qq = html[q]
              let mut e = q + 1
              while e < len && html[e] != qq {
                e = e + 1
              }
              href = Some(html.unsafe_substring(start=q + 1, end=e))
            }
          }
          k = k + 1
        }
        let end = if k < len { k + 1 } else { k }
        let inner_end = if end - 1 < j { j } else { end - 1 }
        // Rewrite: original tag (without its closing '>') + synthetic id + '>'.
        buf.write_string("<a")
        buf.write_string(html.unsafe_substring(start=j, end=inner_end))
        buf.write_string(" id=\"__crater_lnk_" + n.to_string() + "\">")
        hrefs.push(href)
        n = n + 1
        i = end
        continue
      }
    }
    buf.write_char(html[i].to_int().unsafe_to_char())
    i = i + 1
  }
  (buf.to_string(), hrefs)
}

///|
/// True when `i` points at a `<script` start tag (followed by whitespace, '>' or '/').
fn is_script_start(html : String, i : Int) -> Bool {
  if i + 7 >= html.length() || html[i] != '<' {
    return false
  }
  if (html[i + 1] != 's' && html[i + 1] != 'S') ||
    (html[i + 2] != 'c' && html[i + 2] != 'C') ||
    (html[i + 3] != 'r' && html[i + 3] != 'R') ||
    (html[i + 4] != 'i' && html[i + 4] != 'I') ||
    (html[i + 5] != 'p' && html[i + 5] != 'P') ||
    (html[i + 6] != 't' && html[i + 6] != 'T') {
    return false
  }
  let after = html[i + 7]
  after == ' ' ||
  after == '\t' ||
  after == '\n' ||
  after == '\r' ||
  after == '>'
}

///|
/// Collect anchor frames from the paint tree (absolute viewport coordinates,
/// visible non-empty nodes only) and pair them with hrefs via the synthetic
/// id suffix. Anchors without a parseable href yield no region.
fn collect_anchor_links(
  root : @paint_model.PaintNode,
  hrefs : Array[String?],
) -> Array[LinkRegion] {
  let out : Array[LinkRegion] = []
  fn visit(node : @paint_model.PaintNode, ox : Double, oy : Double) -> Unit {
    if !node.paint.should_render() {
      return
    }
    if node.tag == "a" && node.width > 0.0 && node.height > 0.0 {
      match anchor_index(node.id) {
        Some(index) if index < hrefs.length() =>
          match hrefs[index] {
            Some(href) =>
              out.push({
                x: node.x + ox,
                y: node.y + oy,
                width: node.width,
                height: node.height,
                href,
              })
            None => ()
          }
        _ => ()
      }
    }
    for child in node.children {
      visit(child, ox + node.x, oy + node.y)
    }
  }
  visit(root, 0.0, 0.0)
  out
}

///|
/// Parse the synthetic anchor id suffix, e.g. "a#__crater_lnk_3" -> 3.
fn anchor_index(id : String) -> Int? {
  let marker = "__crater_lnk_"
  match id.find(marker) {
    None => None
    Some(i) => {
      let suffix = id.unsafe_substring(
        start=i + marker.length(),
        end=id.length(),
      )
      let parsed = Some(@string.parse_int(suffix)) catch { _ => None }
      parsed
    }
  }
}
