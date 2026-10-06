///|
/// Markdown 子集解析测试（M4）：子集内逐构造断言 + 子集外诚实降级用例。

///|
/// 助手：块序列里的行内文本拼接（断言降级行时用）。
fn inline_text(pieces : Array[MarkdownInline]) -> String {
  let buf = StringBuilder()
  for piece in pieces {
    match piece {
      MiText(text) => buf.write_string(text)
      MiCode(text) => buf.write_string(text)
      MiBold(text) => buf.write_string(text)
      MiItalic(text) => buf.write_string(text)
    }
  }
  buf.to_string()
}

///|
test "markdown headings levels 1-3" {
  let blocks = parse_markdown("# 标题一\n## 标题二\n### 标题三")
  assert_eq(blocks.length(), 3)
  match blocks[0] {
    MbHeading(level, text) => {
      assert_eq(level, 1)
      assert_eq(text, "标题一")
    }
    _ => abort("expected heading 1")
  }
  match blocks[1] {
    MbHeading(level, text) => {
      assert_eq(level, 2)
      assert_eq(text, "标题二")
    }
    _ => abort("expected heading 2")
  }
  match blocks[2] {
    MbHeading(level, _) => assert_eq(level, 3)
    _ => abort("expected heading 3")
  }
}

///|
test "markdown fenced code block with language and unterminated fence" {
  let blocks = parse_markdown("```moonbit\nfn main() {}\nlet x = 1\n```")
  assert_eq(blocks.length(), 1)
  match blocks[0] {
    MbCodeBlock(lang, code) => {
      assert_eq(lang, "moonbit")
      assert_eq(code, "fn main() {}\nlet x = 1")
    }
    _ => abort("expected code block")
  }
  // 未闭合围栏：吃到结尾仍按代码块（围栏意图明确，不吞内容）
  let open = parse_markdown("```\n未闭合\n代码")
  match open[0] {
    MbCodeBlock(lang, code) => {
      assert_eq(lang, "")
      assert_eq(code, "未闭合\n代码")
    }
    _ => abort("expected unterminated code block")
  }
}

///|
test "markdown lists bullet and ordered" {
  let blocks = parse_markdown("- 第一项\n- 第二项\n1. 一步\n2. 二步")
  assert_eq(blocks.length(), 2)
  match blocks[0] {
    MbBulletList(items) => {
      assert_eq(items.length(), 2)
      assert_eq(inline_text(items[0]), "第一项")
    }
    _ => abort("expected bullet list")
  }
  match blocks[1] {
    MbOrderedList(items) => {
      assert_eq(items.length(), 2)
      assert_eq(inline_text(items[1]), "二步")
    }
    _ => abort("expected ordered list")
  }
}

///|
test "markdown rule and paragraph merging" {
  let blocks = parse_markdown("第一段\n续行也在同一段\n\n---\n尾段")
  assert_eq(blocks.length(), 3)
  match blocks[0] {
    MbParagraph(pieces) =>
      assert_eq(inline_text(pieces), "第一段\n续行也在同一段")
    _ => abort("expected merged paragraph")
  }
  match blocks[1] {
    MbRule => ()
    _ => abort("expected rule")
  }
}

///|
test "markdown inline styles code bold italic" {
  let blocks = parse_markdown("说 **重点** 和 *语气* 还有 `rt.set_text(x)`")
  assert_eq(blocks.length(), 1)
  match blocks[0] {
    MbParagraph(pieces) => {
      // 顺序敏感：文本/粗体/文本/斜体/文本/代码/文本
      assert_eq(pieces.length(), 6)
      match pieces[1] {
        MiBold(text) => assert_eq(text, "重点")
        _ => abort("expected bold")
      }
      match pieces[3] {
        MiItalic(text) => assert_eq(text, "语气")
        _ => abort("expected italic")
      }
      match pieces[5] {
        MiCode(text) => assert_eq(text, "rt.set_text(x)")
        _ => abort("expected code")
      }
    }
    _ => abort("expected paragraph")
  }
  // 粗体优先于斜体：** 不被切成两个斜体
  let bold_only = parse_markdown("**全粗体**")
  match bold_only[0] {
    MbParagraph(pieces) =>
      match pieces[0] {
        MiBold(text) => assert_eq(text, "全粗体")
        _ => abort("expected bold")
      }
    _ => abort("expected paragraph")
  }
  // 未闭合标记保持字面（诚实降级）
  let unterminated = parse_markdown("没闭合的 ** 标记和 ` 反引号")
  match unterminated[0] {
    MbParagraph(pieces) => assert_eq(inline_text(pieces), "没闭合的 ** 标记和 ` 反引号")
    _ => abort("expected paragraph")
  }
}

///|
test "markdown unsupported syntax degrades to plain paragraphs" {
  // 表格 → 原样文本段落（不吞不猜）
  let table = parse_markdown("| 列一 | 列二 |\n|---|---|\n| a | b |")
  // 连续未支持行合并为一段（软换行分隔），全部原样保留
  assert_eq(table.length(), 1)
  match table[0] {
    MbParagraph(pieces) =>
      assert_eq(
        inline_text(pieces),
        "| 列一 | 列二 |\n|---|---|\n| a | b |",
      )
    _ => abort("expected paragraph")
  }
  // 引用块 → 原样文本段落
  let quote = parse_markdown("> 引用内容")
  match quote[0] {
    MbParagraph(pieces) => assert_eq(inline_text(pieces), "> 引用内容")
    _ => abort("expected paragraph")
  }
  // 链接 → 纯文本（无导航 v1，标记原样保留）
  let link = parse_markdown("见 [文档](https://example.com) 说明")
  match link[0] {
    MbParagraph(pieces) =>
      assert_eq(inline_text(pieces), "见 [文档](https://example.com) 说明")
    _ => abort("expected paragraph")
  }
  // 四级标题 → 降级为普通段落（子集只到三级）
  let h4 = parse_markdown("#### 四级标题")
  match h4[0] {
    MbParagraph(pieces) => assert_eq(inline_text(pieces), "#### 四级标题")
    _ => abort("expected paragraph")
  }
  // 列表项里的链接：行内降级同样原样保留
  let task = parse_markdown("- [ ] 待办")
  match task[0] {
    MbBulletList(items) => assert_eq(inline_text(items[0]), "[ ] 待办")
    _ => abort("expected bullet list")
  }
}

///|
test "markdown empty input yields no blocks" {
  assert_eq(parse_markdown("").length(), 0)
  assert_eq(parse_markdown("\n\n\n").length(), 0)
}

///|
test "markdown streaming suffix stays parseable" {
  // 流式场景：半截回复每追加分片后重解析，已产出块保持稳定（前缀性质）
  let head = parse_markdown("# 标题\n第一段")
  let more = parse_markdown("# 标题\n第一段\n- 项目")
  match (head[0], more[0]) {
    (MbHeading(_, head_text), MbHeading(_, more_text)) =>
      assert_eq(head_text, more_text)
    _ => abort("prefix heading must be identical")
  }
  match (head[1], more[1]) {
    (MbParagraph(head_pieces), MbParagraph(_)) =>
      assert_eq(inline_text(head_pieces), "第一段")
    _ => abort("prefix paragraph must be identical")
  }
  assert_eq(more.length(), 3)
}
