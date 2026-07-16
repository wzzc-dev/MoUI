///|
fn wrapped_text(
  value : String,
  role~ : @views.TextRole,
  theme~ : @moui.Theme,
  width~ : Double,
  height~ : Double,
  align~ : @text.TextAlign,
) -> @moui.View[ComponentGalleryMsg] {
  let line_height = wrapped_text_line_height(role)
  let max_lines = gallery_max_int(1, (height / line_height).to_int())
  let lines = wrap_text_lines(value, role, width, max_lines)
  @views.column(
    lines.map(line => {
      @views.text(line, role~, theme~, width~, height=line_height, align~)
    }),
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  ).frame(width~, height~)
}

///|
fn wrap_text_lines(
  value : String,
  role : @views.TextRole,
  width : Double,
  max_lines : Int,
) -> Array[String] {
  let max_chars = wrapped_text_max_chars(role, width)
  let lines : Array[String] = []
  let mut current = ""
  for word_view in value.split(" ") {
    let word = word_view.to_owned()
    if word != "" {
      if current == "" {
        current = word
      } else if wrapped_text_length(current) + 1 + wrapped_text_length(word) <=
        max_chars {
        current = current + " " + word
      } else {
        lines.push(current)
        current = word
      }
    }
  }
  if current != "" {
    lines.push(current)
  }
  if lines.length() == 0 {
    lines.push("")
  }
  let line_limit = gallery_max_int(1, max_lines)
  if lines.length() <= line_limit {
    lines
  } else {
    let visible : Array[String] = []
    for index in 0..<line_limit {
      visible.push(lines[index])
    }
    let last = visible.length() - 1
    visible[last] = wrapped_text_ellipsize(visible[last], max_chars)
    visible
  }
}

///|
fn wrapped_text_ellipsize(value : String, max_chars : Int) -> String {
  let chars = value.to_array()
  if chars.length() <= max_chars {
    value
  } else if max_chars <= 3 {
    String::from_array(chars[:gallery_max_int(0, max_chars)])
  } else {
    String::from_array(chars[:max_chars - 3]) + "..."
  }
}

///|
fn wrapped_text_length(value : String) -> Int {
  value.to_array().length()
}

///|
fn wrapped_text_max_chars(role : @views.TextRole, width : Double) -> Int {
  gallery_max_int(8, (width / wrapped_text_average_char_width(role)).to_int())
}

///|
fn wrapped_text_average_char_width(role : @views.TextRole) -> Double {
  match role {
    @views.TextRole::Caption | @views.TextRole::Overline => 7.0
    @views.TextRole::Mono => 8.4
    @views.TextRole::Title => 9.2
    @views.TextRole::Headline => 9.4
    @views.TextRole::Subtitle => 8.4
    @views.TextRole::Control | @views.TextRole::Label => 7.4
    @views.TextRole::Display => 12.0
    @views.TextRole::Body => 7.8
  }
}

///|
fn wrapped_text_line_height(role : @views.TextRole) -> Double {
  match role {
    @views.TextRole::Caption | @views.TextRole::Overline => 18.0
    @views.TextRole::Control | @views.TextRole::Label => 20.0
    @views.TextRole::Mono => 20.0
    @views.TextRole::Body => 22.0
    @views.TextRole::Subtitle => 26.0
    @views.TextRole::Title | @views.TextRole::Headline => 28.0
    @views.TextRole::Display => 36.0
  }
}

///|
fn gallery_grid_columns(
  width : Double,
  min_column_width : Double,
  column_spacing : Double,
) -> Int {
  let min_column_width = gallery_max_double(1.0, min_column_width)
  let mut columns = 1
  let mut candidate = 2
  let mut needed = candidate.to_double() * min_column_width +
    (candidate - 1).to_double() * column_spacing
  while needed <= width {
    columns = candidate
    candidate = candidate + 1
    needed = candidate.to_double() * min_column_width +
      (candidate - 1).to_double() * column_spacing
  }
  columns
}

///|
fn gallery_grid_column_width(
  width : Double,
  columns : Int,
  column_spacing : Double,
) -> Double {
  let columns = gallery_max_int(1, columns)
  gallery_max_double(
    1.0,
    (width - (columns - 1).to_double() * column_spacing) / columns.to_double(),
  )
}

///|
fn gallery_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn gallery_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
