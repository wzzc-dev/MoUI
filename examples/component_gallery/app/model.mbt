///|
pub(all) enum PlatformId {
  MacOS
  Linux
  Windows
  Android
  IOS
  Web
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ComponentGalleryStoryId {
  Welcome
  Buttons
  Inputs
  Feedback
  Layout
  Platforms
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ComponentGalleryModel {
  active_platform : PlatformId
  active_story : ComponentGalleryStoryId
  selected_platform : PlatformId
  page_scroll : @state.ScrollState
  search_query : String
  sample_text : String
  selected_mode : String
  selected_density : String
  feature_enabled : Bool
  slider_value : Double
  counter : Int
}

///|
pub(all) enum ComponentGalleryMsg {
  SelectStory(String)
  SearchChanged(String)
  SelectPlatform(String)
  SelectMode(String)
  SelectDensity(String)
  SampleTextChanged(String)
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
    active_story: ComponentGalleryStoryId::Welcome,
    selected_platform: active_platform,
    page_scroll: @state.ScrollState::new(),
    search_query: "",
    sample_text: "Component Gallery",
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
    SelectStory(id) => {
      let next = story_id_from_string(id).unwrap_or(model.active_story)
      if next != model.active_story {
        model.page_scroll.scroll_to(x=0.0, y=0.0)
      }
      { ..model, active_story: next }
    }
    SearchChanged(query) => {
      let next = if story_matches_query(story_info(model.active_story), query) {
        model.active_story
      } else {
        first_story_matching(query).unwrap_or(model.active_story)
      }
      { ..model, search_query: query, active_story: next }
    }
    SelectPlatform(id) =>
      {
        ..model,
        selected_platform: platform_id_from_string(id).unwrap_or(
          model.selected_platform,
        ),
        active_story: ComponentGalleryStoryId::Platforms,
      }
    SelectMode(id) => { ..model, selected_mode: id }
    SelectDensity(id) => { ..model, selected_density: id }
    SampleTextChanged(value) => { ..model, sample_text: value }
    FeatureToggled(value) => { ..model, feature_enabled: value }
    SliderChanged(value) => { ..model, slider_value: value }
    Increment => { ..model, counter: model.counter + 1 }
    Decrement => { ..model, counter: model.counter - 1 }
    Reset =>
      {
        ..model,
        sample_text: "Component Gallery",
        selected_mode: "canvas",
        selected_density: "regular",
        feature_enabled: true,
        slider_value: 0.66,
        counter: 0,
      }
  }
}
