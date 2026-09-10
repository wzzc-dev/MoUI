///|
/// The installed resolver must turn an SVG text run into vector outlines with
/// sane glyph geometry. Skips when no default platform font is available,
/// leaving the renderer's bitmap fallback in place.
test "svg text resolver produces vector outlines for badge text" {
  @render_common.clear_svg_text_path_resolver()
  let font_bytes : Bytes? = Some(
    @fs.read_file_to_bytes("/System/Library/Fonts/Supplemental/Arial.ttf"),
  ) catch {
    _ => None
  }
  match font_bytes {
    Some(bytes) if bytes.length() > 0 => {
      assert_true(install_svg_text_path_resolver())
      let run : @render_common.SvgTextRun = {
        text: "build",
        font_size: 11.0,
        x: 0.0,
        baseline_y: 0.0,
        anchor: Start,
        text_length: 41.0,
      }
      match sun_svg_resolve_text_run(run) {
        Some(outline) => {
          assert_true(outline.polygons.length() > 0)
          // "build" at 11px Arial spans roughly 20-28px.
          assert_true(outline.width > 10.0 && outline.width < 60.0)
          let mut min_y = 0.0
          let mut max_y = 0.0
          for polygon in outline.polygons {
            for point in polygon {
              if point.1 < min_y {
                min_y = point.1
              }
              if point.1 > max_y {
                max_y = point.1
              }
            }
          }
          // Ascenders rise above the baseline; nothing descends far below it.
          assert_true(min_y < -1.0)
          assert_true(max_y < 1.0)
        }
        None => fail("expected glyph outlines for 'build'")
      }
      @render_common.clear_svg_text_path_resolver()
    }
    _ => println("skip: platform font unavailable for svg text resolver")
  }
}
