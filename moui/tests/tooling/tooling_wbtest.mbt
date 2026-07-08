///|
test "quickcheck keeps text layout caret positions monotonic" {
  @quickcheck.quick_check_fn(
    fn(seed : Int) {
      let char_count = bounded_abs(seed, 32)
      let max_width = (bounded_abs(seed / 32, 64) + 1).to_double()
      let chars : Array[Char] = []
      for _ in 0..<char_count {
        chars.push('M')
      }
      let text = String::from_array(chars)
      let layout = @core.TextSystem::fallback().measure_text(
        @core.TextLayoutInput::new(
          text~,
          font=@core.FontSpec::new(size=14.0),
          max_width~,
        ),
      )
      layout.caret_positions.length() == char_count + 1 &&
      layout.size.width <= max_width &&
      caret_positions_monotonic(layout.caret_positions)
    },
    max_success=64,
  )
}

///|
test "pixelmatch reports stable image equality and one pixel delta" {
  let expected = @pixelmatch.Image::new(2, 2)
  let actual = @pixelmatch.Image::new(2, 2)
  let red = @pixelmatch.Color::rgb(255, 0, 0)
  let blue = @pixelmatch.Color::rgb(0, 0, 255)
  expected.set_pixel(0, 0, red)
  actual.set_pixel(0, 0, red)
  let options = @pixelmatch.Options::default()
  inspect(@pixelmatch.pixelmatch(expected, actual, None, options), content="0")
  actual.set_pixel(1, 1, blue)
  inspect(@pixelmatch.pixelmatch(expected, actual, None, options), content="1")
}

///|
test "quickcheck exercises svg rect lowering dimensions" {
  @quickcheck.quick_check_fn(
    fn(seed : Int) {
      let width = (bounded_abs(seed, 50) + 1).to_double()
      let height = (bounded_abs(seed / 50, 50) + 1).to_double()
      let svg = "<svg><rect x=\"0\" y=\"0\" width=\"" +
        width.to_string() +
        "\" height=\"" +
        height.to_string() +
        "\" fill=\"red\"/></svg>"
      let result = @render.import_svg(svg)
      result.diagnostics().length() == 0 &&
      result.commands().length() == 1 &&
      svg_rect_command_matches(result.commands()[0], width, height)
    },
    max_success=64,
  )
}

///|
fn bounded_abs(value : Int, bound : Int) -> Int {
  let remainder = value % bound
  if remainder < 0 {
    -remainder
  } else {
    remainder
  }
}

///|
fn caret_positions_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn svg_rect_command_matches(
  command : @core.DrawCommand,
  width : Double,
  height : Double,
) -> Bool {
  match command {
    @core.DrawCommand::FillRect(rect, color) =>
      rect.size.width == width &&
      rect.size.height == height &&
      color == @core.Color::rgba(r=1.0, g=0.0, b=0.0)
    _ => false
  }
}
