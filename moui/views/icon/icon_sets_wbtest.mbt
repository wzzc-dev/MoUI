///|
test "lucide subset is complete and every path parses" {
  let names = lucide_icon_names()
  assert_true(names.length() >= 100)
  assert_true(lucide_has("search"))
  assert_true(lucide_has("house"))
  assert_false(lucide_has("definitely-not-a-lucide-icon"))
  let seen : Map[String, Unit] = Map([])
  for name in names {
    assert_false(seen.contains(name))
    seen.set(name, ())
    match lucide_icon_path_data(name) {
      Some(path) => {
        let parsed = svg_icon_parse(
          "<svg viewBox=\"0 0 24 24\"><path d=\"" + path + "\"/></svg>",
        )
        assert_true(parsed.0.length() > 0)
      }
      None => abort("missing path data for " + name)
    }
  }
}

///|
test "lucide icon draws and unknown names paint nothing" {
  let view : @core.View[Unit] = lucide_icon("search", size=24.0)
  let layout = view.layout(svg_icon_test_layout_context())
  assert_eq(layout.size.width, 24.0)
  assert_eq(layout.size.height, 24.0)
  let plan = view.paint(
    svg_icon_test_paint_context(
      @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0),
    ),
  )
  match plan.commands[0] {
    @core.DrawPath(spec) => assert_true(spec.verbs.length() > 0)
    _ => abort("expected DrawPath")
  }
  let unknown : @core.View[Unit] = lucide_icon("definitely-not-a-lucide-icon")
  let unknown_plan = unknown.paint(
    svg_icon_test_paint_context(
      @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
    ),
  )
  match unknown_plan.commands[0] {
    @core.DrawPath(spec) => assert_eq(spec.verbs.length(), 0)
    _ => abort("expected DrawPath")
  }
}

///|
test "sf symbol adapter targets exist in the vendored set" {
  let mappings = sf_symbol_lucide_mappings()
  assert_true(mappings.length() >= 100)
  for pair in mappings {
    let sf_name = pair.0
    let lucide_name = pair.1
    assert_true(lucide_has(lucide_name))
    assert_eq(sf_symbol_lucide_name(sf_name), Some(lucide_name))
  }
  assert_eq(sf_symbol_lucide_name("magnifyingglass"), Some("search"))
  assert_eq(sf_symbol_lucide_name("house.fill"), Some("house"))
  assert_eq(sf_symbol_lucide_name("no.such.symbol"), None)
}

///|
test "sf symbol icon renders through the lucide adapter" {
  let view : @core.View[Unit] = sf_symbol_icon("magnifyingglass", size=18.0)
  let layout = view.layout(svg_icon_test_layout_context())
  assert_eq(layout.size.width, 18.0)
  let plan = view.paint(
    svg_icon_test_paint_context(
      @core.Rect::new(x=0.0, y=0.0, width=18.0, height=18.0),
    ),
  )
  match plan.commands[0] {
    @core.DrawPath(spec) => assert_true(spec.verbs.length() > 0)
    _ => abort("expected DrawPath")
  }
}
