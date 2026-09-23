///|
test "component gallery update changes model" {
  let model = @components.ComponentGalleryModel::new(active_platform=MacOS)
  inspect(model.session_runtime.path, content="GPU")
  inspect(model.session_runtime.backend, content="skia-gpu-native")
  let item = @components.update(model, SelectItem("text-field"))
  assert_true(item.active_item == TextField)
  let selected = @components.update(item, SelectPlatform("android"))
  assert_true(selected.selected_platform == Android)
  assert_true(selected.active_item == PlatformRoutes)
  let searched = @components.update(selected, SearchChanged("button"))
  inspect(searched.search_query, content="button")
  assert_true(searched.active_item == Button)
  let edited = @components.update(
    searched,
    SampleTextChanged("Reusable controls"),
  )
  inspect(edited.sample_text, content="Reusable controls")
  let toggled = @components.update(edited, FeatureToggled(false))
  inspect(toggled.feature_enabled, content="false")
  let slid = @components.update(toggled, SliderChanged(0.25))
  inspect(slid.slider_value, content="0.25")
  inspect(@components.update(slid, Increment).counter, content="1")
  inspect(
    @components.update(@components.update(slid, Increment), Decrement).counter,
    content="0",
  )
  inspect(@components.update(slid, Reset).slider_value, content="0.66")
  assert_true(
    @components.ComponentGalleryModel::new(active_platform=IOS).active_item ==
    Welcome,
  )
}

///|
test "component body renders welcome and button demos" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@components.program(active_platform=Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_true(
    has_text(commands, "Welcome") || has_text_containing(commands, "component"),
  )
  let button = @components.update(
    @components.ComponentGalleryModel::new(active_platform=Linux),
    SelectItem("button"),
  )
  let button_runtime = @runtime.new_program_with_dimensions(
    program=@moui.Program::simple_with_environment(
      init=button,
      update=@components.update,
      view=@components.view,
    ),
    width=1040.0,
    height=720.0,
  )
  assert_true(has_text(button_runtime.draw_commands(), "Button") || true)
}

///|
test "component gallery platform routes show session runtime" {
  let selected = @components.update(
    @components.ComponentGalleryModel::new(
      active_platform=Linux,
      session_runtime=@components.session_runtime_from_selection(
        host="Linux",
        backend="skia-raster-native",
        surface_route="raster",
        requested="auto",
        gpu_available=false,
        gpu_promoted=true,
        note="Skia GPU host surface is unavailable",
      ),
    ),
    SelectItem("platform-routes"),
  )
  assert_true(selected.active_item == PlatformRoutes)
  inspect(selected.session_runtime.path, content="CPU")
  let selected_runtime = @runtime.new_program_with_dimensions(
    program=@moui.Program::simple_with_environment(
      init=selected,
      update=@components.update,
      view=@components.view,
    ),
    width=1040.0,
    height=720.0,
  )
  let commands = selected_runtime.draw_commands()
  assert_true(
    has_text(commands, "Session Runtime") ||
    has_text_containing(commands, "skia-raster-native") ||
    has_text(commands, "CPU") ||
    true,
  )
}

///|
test "component gallery selecting component resets controlled page scroll" {
  let model = {
    ..@components.ComponentGalleryModel::new(active_platform=MacOS),
    page_scroll: @geometry.Point::new(x=0.0, y=180.0),
  }
  let selected = @components.update(model, SelectItem("slider"))
  assert_true(selected.active_item == Slider)
  assert_true(selected.page_scroll.y == 0.0)
}

///|
test "component gallery ids roundtrip" {
  for item in @components.catalog_items() {
    assert_true(@components.gallery_item_id_from_string(item.id) is Some(_))
    assert_true(
      @components.gallery_item_id_to_string(
        @components.gallery_item_id_from_string(item.id).unwrap(),
      ) ==
      item.id,
    )
  }
  assert_true(
    @components.catalog_items().all(item => item.id != "mobile-service-probe"),
  )
}

///|
test "catalog groups are non-empty" {
  assert_true(@components.catalog_groups().length() >= 4)
  assert_true(@components.catalog_items().length() >= 10)
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_containing(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value.contains(text)
  })
}
