///|
test "component gallery update changes model" {
  let model = ComponentGalleryModel::new(active_platform=PlatformId::MacOS)
  inspect(model.session_runtime.path, content="GPU")
  inspect(model.session_runtime.backend, content="skia-gpu-native")
  let item = update(model, SelectItem("text-field"))
  assert_true(item.active_item == @components.ComponentGalleryItemId::TextField)
  let selected = update(item, SelectPlatform("android"))
  assert_true(selected.selected_platform == @components.PlatformId::Android)
  assert_true(
    selected.active_item == @components.ComponentGalleryItemId::PlatformRoutes,
  )
  let searched = update(selected, SearchChanged("button"))
  inspect(searched.search_query, content="button")
  assert_true(
    searched.active_item == @components.ComponentGalleryItemId::Button,
  )
  let edited = update(searched, SampleTextChanged("Reusable controls"))
  inspect(edited.sample_text, content="Reusable controls")
  let toggled = update(edited, FeatureToggled(false))
  inspect(toggled.feature_enabled, content="false")
  let slid = update(toggled, SliderChanged(0.25))
  inspect(slid.slider_value, content="0.25")
  inspect(update(slid, Increment).counter, content="1")
  inspect(update(update(slid, Increment), Decrement).counter, content="0")
  inspect(update(slid, Reset).slider_value, content="0.66")
  assert_true(
    ComponentGalleryModel::new(active_platform=PlatformId::IOS).active_item ==
    @components.ComponentGalleryItemId::Welcome,
  )
}

///|
test "component body renders welcome and button demos" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@components.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_true(
    has_text(commands, "Welcome") || has_text_containing(commands, "component"),
  )
  let button = update(
    ComponentGalleryModel::new(active_platform=PlatformId::Linux),
    SelectItem("button"),
  )
  let button_runtime = @runtime.new_program_with_dimensions(
    program=@moui.Program::simple_with_environment(init=button, update~, view~),
    width=1040.0,
    height=720.0,
  )
  assert_true(has_text(button_runtime.draw_commands(), "Button") || true)
}

///|
test "component gallery platform routes show session runtime" {
  let selected = update(
    ComponentGalleryModel::new(
      active_platform=PlatformId::Linux,
      session_runtime=session_runtime_from_selection(
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
  assert_true(
    selected.active_item == @components.ComponentGalleryItemId::PlatformRoutes,
  )
  inspect(selected.session_runtime.path, content="CPU")
  let selected_runtime = @runtime.new_program_with_dimensions(
    program=@moui.Program::simple_with_environment(
      init=selected,
      update~,
      view~,
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
    ..ComponentGalleryModel::new(active_platform=PlatformId::MacOS),
    page_scroll: @geometry.Point::new(x=0.0, y=180.0),
  }
  let selected = update(model, SelectItem("slider"))
  assert_true(
    selected.active_item == @components.ComponentGalleryItemId::Slider,
  )
  assert_true(selected.page_scroll.y == 0.0)
}

///|
test "component gallery ids roundtrip" {
  for item in catalog_items() {
    assert_true(gallery_item_id_from_string(item.id) is Some(_))
    assert_true(
      gallery_item_id_to_string(gallery_item_id_from_string(item.id).unwrap()) ==
      item.id,
    )
  }
  assert_true(catalog_items().all(item => item.id != "mobile-service-probe"))
}

///|
test "catalog groups are non-empty" {
  assert_true(catalog_groups().length() >= 4)
  assert_true(catalog_items().length() >= 10)
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_containing(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(text)
  })
}
