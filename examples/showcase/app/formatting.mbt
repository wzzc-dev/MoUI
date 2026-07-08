///|
fn showcase_format_rich_text(value : String) -> @moui_richtext.RichTextDocument {
  @moui_richtext.RichTextDocument::new(blocks=[
    @moui_richtext.RichTextBlock::new(runs=[
      @moui_richtext.RichTextRun::new(text=value),
    ]),
  ])
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
fn min_showcase_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn showcase_string_array_contains(
  values : Array[String],
  target : String,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn showcase_string_array_set(
  values : Array[String],
  target : String,
  selected : Bool,
) -> Array[String] {
  let next = values.filter(value => value != target)
  if selected {
    next.push(target)
  }
  next
}

///|
fn showcase_grid_columns(
  body_width : Double,
  compact : Bool,
  max_columns : Int,
) -> Int {
  if compact || max_columns <= 1 {
    1
  } else if max_columns >= 3 && body_width >= 920.0 {
    3
  } else if body_width >= 600.0 {
    min_showcase_int(max_columns, 2)
  } else {
    1
  }
}

///|
fn showcase_grid_card_width(
  body_width : Double,
  columns : Int,
  spacing : Double,
) -> Double {
  if columns <= 1 {
    body_width
  } else {
    (body_width - (columns - 1).to_double() * spacing) / columns.to_double()
  }
}

///|
fn showcase_metrics(
  viewport : @geometry.Size,
  theme : @moui.Theme,
) -> ShowcaseMetrics {
  let viewport = @geometry.Size::new(
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
fn ShowcaseModel::gallery_items(self : ShowcaseModel) -> Array[String] {
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
