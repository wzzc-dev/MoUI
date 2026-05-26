///|
fn showcase_format_rich_text(value : String) -> @core.RichTextDocument {
  @core.RichTextDocument::new(blocks=[
    @core.RichTextBlock::new(runs=[@core.RichTextRun::new(text=value)]),
  ])
}

///|
fn showcase_format_markdown(value : String) -> @core.RichTextDocument {
  let blocks : Array[@core.RichTextBlock] = []
  for line in showcase_markdown_lines(value) {
    blocks.push(showcase_markdown_line(line))
  }
  if blocks.is_empty() {
    blocks.push(
      @core.RichTextBlock::new(runs=[@core.RichTextRun::new(text="")]),
    )
  }
  @core.RichTextDocument::new(blocks~)
}

///|
fn showcase_markdown_line(line : String) -> @core.RichTextBlock {
  let base = @core.FontSpec::new()
  if line.has_prefix("# ") {
    let font = { ..base, size: base.size * 1.32, weight: 700 }
    @core.RichTextBlock::new(
      runs=[@core.RichTextRun::new(text=line[2:].to_owned(), font=Some(font))],
      font=Some(font),
      line_height=Some(base.size * 1.8),
    )
  } else if line.has_prefix("- ") {
    @core.RichTextBlock::new(
      runs=showcase_markdown_inline_runs(line[2:].to_owned(), base),
      prefix="- ",
      line_height=Some(base.size * 1.55),
    )
  } else {
    @core.RichTextBlock::new(
      runs=showcase_markdown_inline_runs(line, base),
      line_height=Some(base.size * 1.55),
    )
  }
}

///|
fn showcase_markdown_inline_runs(
  line : String,
  base : @core.FontSpec,
) -> Array[@core.RichTextRun] {
  let runs : Array[@core.RichTextRun] = []
  let chars = line.to_array()
  let current : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if index + 1 < chars.length() &&
      chars[index] == '*' &&
      chars[index + 1] == '*' {
      showcase_flush_plain_run(runs, current)
      let start = index + 2
      let end = showcase_find_marker(chars, start, "**")
      if end >= 0 {
        runs.push(
          @core.RichTextRun::new(
            text=String::from_array(chars[start:end]),
            font=Some({ ..base, weight: 700 }),
          ),
        )
        index = end + 2
      } else {
        current.push(chars[index])
        index = index + 1
      }
    } else if chars[index] == '`' {
      showcase_flush_plain_run(runs, current)
      let start = index + 1
      let end = showcase_find_marker(chars, start, "`")
      if end >= 0 {
        runs.push(
          @core.RichTextRun::new(
            text=String::from_array(chars[start:end]),
            font=Some({
              ..base,
              families: @core.FontFamilyStack::named("SFMono-Regular")
              .with_fallback(@core.FontFamily::UiMonospace)
              .with_fallback(@core.FontFamily::Monospace),
            }),
            background=Some(
              @core.Brush::solid(@core.Color::black().multiply_alpha(0.08)),
            ),
          ),
        )
        index = end + 1
      } else {
        current.push(chars[index])
        index = index + 1
      }
    } else if chars[index] == '*' {
      showcase_flush_plain_run(runs, current)
      let start = index + 1
      let end = showcase_find_marker(chars, start, "*")
      if end >= 0 {
        runs.push(
          @core.RichTextRun::new(
            text=String::from_array(chars[start:end]),
            font=Some({ ..base, style: @core.FontStyle::Italic }),
          ),
        )
        index = end + 1
      } else {
        current.push(chars[index])
        index = index + 1
      }
    } else {
      current.push(chars[index])
      index = index + 1
    }
  }
  showcase_flush_plain_run(runs, current)
  if runs.is_empty() {
    runs.push(@core.RichTextRun::new(text=""))
  }
  runs
}

///|
fn showcase_flush_plain_run(
  runs : Array[@core.RichTextRun],
  current : Array[Char],
) -> Unit {
  if !current.is_empty() {
    runs.push(@core.RichTextRun::new(text=String::from_array(current)))
    current.clear()
  }
}

///|
fn showcase_find_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Int {
  let marker_chars = marker.to_array()
  let marker_len = marker_chars.length()
  let mut index = start
  while index + marker_len <= chars.length() {
    let mut matched = true
    for offset in 0..<marker_len {
      if chars[index + offset] != marker_chars[offset] {
        matched = false
      }
    }
    if matched {
      return index
    }
    index = index + 1
  }
  -1
}

///|
fn showcase_markdown_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  for ch in value {
    if ch == '\n' {
      if !current.is_empty() {
        lines.push(String::from_array(current))
      }
      current.clear()
    } else {
      current.push(ch)
    }
  }
  if !current.is_empty() {
    lines.push(String::from_array(current))
  }
  lines
}

///|
fn string_contains(value : String, needle : String) -> Bool {
  if needle == "" {
    true
  } else {
    value.contains(needle)
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn min_showcase_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_showcase_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn max_showcase_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn showcase_metrics(
  viewport : @core.Size,
  theme : @core.Theme,
) -> ShowcaseMetrics {
  let viewport = @core.Size::new(
    width=max_showcase_double(1.0, viewport.width),
    height=max_showcase_double(1.0, viewport.height),
  )
  let outer_padding = theme.spacing_scale.md * 2.0
  let shell_width = max_showcase_double(560.0, viewport.width - outer_padding)
  let sidebar_width = if shell_width < 760.0 { 220.0 } else { 244.0 }
  let detail_width = max_showcase_double(
    420.0,
    shell_width - sidebar_width - theme.spacing_scale.lg,
  )
  let panel_height = max_showcase_double(280.0, viewport.height - 108.0)
  let panel_padding = theme.spacing_scale.md * 2.0
  let body_width = max_showcase_double(220.0, detail_width - panel_padding)
  let body_height = max_showcase_double(120.0, panel_height - 96.0)
  let action_width = clamp_double(shell_width - 288.0, 240.0, 420.0)
  {
    viewport,
    shell_width,
    sidebar_width,
    detail_width,
    panel_width: detail_width,
    panel_height,
    body_width,
    body_height,
    action_width,
    compact: body_width < 620.0,
  }
}

///|
fn ShowcaseApp::gallery_items(self : ShowcaseApp) -> Array[String] {
  ignore(self)
  [
    "State holders", "Modifier order", "Lazy list rows", "Keyboard shortcut", "Dialog host",
    "Accessible controls", "Grid cell", "Intrinsic size",
  ]
}

///|
fn showcase_image_source() -> String {
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAYAAAA6yNxSAAACK0lEQVR42u3Uu6okVRQG4HqIfoXqulBdt66iLt1nZo6nuyr1GTQwMDAQDAwMFEcZFS94YVScEbVRn0gUERER8QVEhPJDOKIwHkcxnOAL1l4L1h/svYPw0Z+WNRExCSkZG3IKSipqtjS0dPQMjOzYc8Y1rnODcy44cGRiJggf+3FZExGTkJKxIaegpKJmS0NLR8/AyI49Z1zjOjc454IDRyZmgvDxH5Y1ETEJKRkbcgpKKmq2NLR09AyM7Nhzxs+//PqHc/UFB45MzAThE98vayJiElIyNuQUlFTUbGlo6egZGNmx58/LL104P3BkYiYIn/xuWRMRk5CSsSGnoKSiZktDS0fPwMiOPWf85R9QX3DgyMRMsPr8tDz08CP/yurd07K6zTu8zVu8yRu8zmu8yiu8zEt/v+P3AKvP+PSfg6zeN/fe6T8FWN3ixdPVAVYnPuFjPuJD7nKHD07/S4DVC9zkeZ47PQjwIMDyG/KhyFi81CXIAAAAAElFTkSuQmCC"
}
