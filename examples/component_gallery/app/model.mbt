///|
pub(all) enum PlatformId {
  MacOS
  Linux
  Windows
  Android
  IOS
  HarmonyOs
  Web
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ComponentGalleryItemId {
  Welcome
  Button
  TextField
  TextArea
  ClearableTextField
  PasswordField
  NumberField
  Stepper
  Checkbox
  Toggle
  Radio
  RadioGroup
  CheckboxGroup
  SegmentedControl
  Picker
  Slider
  Chips
  Badge
  Progress
  Banner
  Callout
  StatePanel
  InlineError
  Toast
  Snackbar
  StatCard
  Avatar
  Divider
  Toolbar
  StatusBar
  Surface
  RowColumn
  ResponsiveGrid
  ScrollView
  PlatformRoutes
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ComponentGalleryModel {
  active_platform : PlatformId
  active_item : ComponentGalleryItemId
  selected_platform : PlatformId
  page_scroll : @state.ScrollState
  sidebar_scroll : @state.ScrollState
  content_scroll : @state.ScrollState
  search_query : String
  sample_text : String
  sample_number : String
  password_revealed : Bool
  selected_mode : String
  selected_density : String
  feature_enabled : Bool
  slider_value : Double
  counter : Int
}

///|
pub(all) enum ComponentGalleryMsg {
  SelectItem(String)
  SearchChanged(String)
  SelectPlatform(String)
  SelectMode(String)
  SelectDensity(String)
  SampleTextChanged(String)
  SampleNumberChanged(String)
  TogglePasswordReveal
  FeatureToggled(Bool)
  SliderChanged(Double)
  Increment
  Decrement
  Reset
} derive(Eq, Debug, ToJson)

///|
pub fn ComponentGalleryModel::new(
  active_platform~ : PlatformId,
) -> ComponentGalleryModel {
  {
    active_platform,
    active_item: ComponentGalleryItemId::Welcome,
    selected_platform: active_platform,
    page_scroll: @state.ScrollState::new(),
    sidebar_scroll: @state.ScrollState::new(),
    content_scroll: @state.ScrollState::new(),
    search_query: "",
    sample_text: "Component Gallery",
    sample_number: "24",
    password_revealed: false,
    selected_mode: "canvas",
    selected_density: "regular",
    feature_enabled: true,
    slider_value: 0.66,
    counter: 0,
  }
}

///|
pub fn update(
  model : ComponentGalleryModel,
  message : ComponentGalleryMsg,
) -> ComponentGalleryModel {
  match message {
    SelectItem(id) => {
      let next = gallery_item_id_from_string(id).unwrap_or(model.active_item)
      if next != model.active_item {
        model.page_scroll.scroll_to(x=0.0, y=0.0)
        model.content_scroll.scroll_to(x=0.0, y=0.0)
      }
      { ..model, active_item: next }
    }
    SearchChanged(query) => {
      let next = if gallery_item_matches_query(
          gallery_item_info(model.active_item),
          query,
        ) {
        model.active_item
      } else {
        first_gallery_item_matching(query).unwrap_or(model.active_item)
      }
      if next != model.active_item {
        model.page_scroll.scroll_to(x=0.0, y=0.0)
        model.content_scroll.scroll_to(x=0.0, y=0.0)
      }
      { ..model, search_query: query, active_item: next }
    }
    SelectPlatform(id) => {
      model.page_scroll.scroll_to(x=0.0, y=0.0)
      model.content_scroll.scroll_to(x=0.0, y=0.0)
      {
        ..model,
        selected_platform: platform_id_from_string(id).unwrap_or(
          model.selected_platform,
        ),
        active_item: ComponentGalleryItemId::PlatformRoutes,
      }
    }
    SelectMode(id) => { ..model, selected_mode: id }
    SelectDensity(id) => { ..model, selected_density: id }
    SampleTextChanged(value) => { ..model, sample_text: value }
    SampleNumberChanged(value) => { ..model, sample_number: value }
    TogglePasswordReveal =>
      { ..model, password_revealed: !model.password_revealed }
    FeatureToggled(value) => { ..model, feature_enabled: value }
    SliderChanged(value) => { ..model, slider_value: value }
    Increment => { ..model, counter: model.counter + 1 }
    Decrement => { ..model, counter: model.counter - 1 }
    Reset =>
      {
        ..model,
        sample_text: "Component Gallery",
        sample_number: "24",
        password_revealed: false,
        selected_mode: "canvas",
        selected_density: "regular",
        feature_enabled: true,
        slider_value: 0.66,
        counter: 0,
      }
  }
}
