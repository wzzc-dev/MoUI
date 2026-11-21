///|
/// Regression: the Patterns overview used to lay its intro paragraph and
/// callout message out as single lines. Both grew past the detail pane and
/// stretched the surrounding column, so every right-aligned Open button sat
/// beyond the window edge (and a horizontal scrollbar appeared).
test "patterns overview keeps right-aligned controls inside the window" {
  for width in [1100.0, 900.0] {
    let runtime = @runtime.new_program_with_dimensions(
      program=@app.ShowcaseModel::new(route="patterns/welcome").program(),
      width~,
      height=680.0,
    )
    ignore(runtime.draw_frame())
    let semantics = runtime.inspector_snapshot().semantics()
    let mut max_right = 0.0
    for entry in semantics.nodes() {
      let frame = entry.frame()
      let right = frame.origin.x + frame.size.width
      if right > max_right {
        max_right = right
      }
    }
    assert_true(
      max_right <= width + 1.0,
      msg="a semantics frame reached \{max_right} at window width \{width}",
    )
  }
}
