///|
pub(all) enum PlatformId {
  MacOS
  Linux
  Windows
  Android
  IOS
  HarmonyOS
  Web
} derive(Eq, Debug, ToJson)

///|
/// Live or default session renderer facts for the active host. Entrypoints can
/// inject measured GPU/CPU selection; tests and desktop defaults fall back to
/// product mainline expectations for the platform.
pub(all) struct SessionRuntimeInfo {
  host : String
  path : String
  backend : String
  surface_route : String
  requested : String
  gpu_available : Bool
  gpu_promoted : Bool
  note : String
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
  MobileServiceProbe
  AccessibilityProbe
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ComponentGalleryModel {
  active_platform : PlatformId
  active_item : ComponentGalleryItemId
  selected_platform : PlatformId
  session_runtime : SessionRuntimeInfo
  page_scroll : @geometry.Point
  search_query : String
  sample_text : String
  sample_number : String
  password_revealed : Bool
  selected_mode : String
  selected_density : String
  feature_enabled : Bool
  slider_value : Double
  counter : Int
  probe_text : String
  probe_action_count : Int
  probe_submit_count : Int
  probe_dialog_open : Bool
  checkbox_group_selection : Array[String]
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
  ProbeTextChanged(String)
  ProbeFeatureToggled(Bool)
  ProbeSliderChanged(Double)
  ProbeAction
  ProbeSubmit
  ProbeDialogOpen
  ProbeDialogClose
  ToggleCheckboxGroupItem(String)
  PageScrolled(@geometry.Point)
} derive(Eq, Debug, ToJson)

///|
pub fn SessionRuntimeInfo::new(
  host~ : String,
  path~ : String,
  backend~ : String,
  surface_route~ : String,
  requested~ : String,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  note? : String = "",
) -> SessionRuntimeInfo {
  {
    host,
    path,
    backend,
    surface_route,
    requested,
    gpu_available,
    gpu_promoted,
    note,
  }
}

///|
pub fn SessionRuntimeInfo::for_platform(
  platform : PlatformId,
) -> SessionRuntimeInfo {
  match platform {
    PlatformId::MacOS =>
      SessionRuntimeInfo::new(
        host="macOS",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="metal-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Product auto prefers Skia GPU (Metal) when the host surface is available; CPU raster is recovery fallback.",
      )
    PlatformId::Linux =>
      SessionRuntimeInfo::new(
        host="Linux",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="vulkan-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Product auto prefers Skia GPU (Vulkan) when the host surface is available; CPU raster is recovery fallback.",
      )
    PlatformId::Windows =>
      SessionRuntimeInfo::new(
        host="Windows",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="direct3d-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Product auto prefers Skia GPU (Direct3D) when the host surface is available; CPU raster is recovery fallback.",
      )
    PlatformId::Android =>
      SessionRuntimeInfo::new(
        host="Android",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="vulkan-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Mobile product default is Skia GPU when the host surface is available; SkiaRaster is explicit/recovery.",
      )
    PlatformId::IOS =>
      SessionRuntimeInfo::new(
        host="iOS",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="metal-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Mobile product default is Skia GPU when the host surface is available; SkiaRaster is explicit/recovery.",
      )
    PlatformId::HarmonyOS =>
      SessionRuntimeInfo::new(
        host="HarmonyOS",
        path="GPU",
        backend="skia-gpu-native",
        surface_route="egl-gpu",
        requested="auto",
        gpu_available=true,
        gpu_promoted=true,
        note="Mobile product default is Skia GPU when the host surface is available; SkiaRaster is explicit/recovery.",
      )
    PlatformId::Web =>
      SessionRuntimeInfo::new(
        host="Web",
        path="GPU",
        backend="webgpu-wasm",
        surface_route="web-canvas",
        requested="webgpu",
        gpu_available=true,
        gpu_promoted=true,
        note="Web mainline uses browser WebGPU on a canvas surface.",
      )
  }
}

///|
pub fn ComponentGalleryModel::new(
  active_platform~ : PlatformId,
  session_runtime? : SessionRuntimeInfo,
  active_item? : ComponentGalleryItemId = ComponentGalleryItemId::Welcome,
) -> ComponentGalleryModel {
  {
    active_platform,
    active_item,
    selected_platform: active_platform,
    session_runtime: match session_runtime {
      Some(info) => info
      None => SessionRuntimeInfo::for_platform(active_platform)
    },
    page_scroll: @geometry.Point::new(x=0.0, y=0.0),
    search_query: "",
    sample_text: "Showcase Components",
    sample_number: "24",
    password_revealed: false,
    selected_mode: "canvas",
    selected_density: "regular",
    feature_enabled: true,
    slider_value: 0.66,
    counter: 0,
    probe_text: "mobile-service-probe",
    probe_action_count: 0,
    probe_submit_count: 0,
    probe_dialog_open: false,
    checkbox_group_selection: ["desktop", "mobile"],
  }
}

///|
/// Open a component catalog id without rebuilding the rest of the model.
pub fn ComponentGalleryModel::open(
  self : ComponentGalleryModel,
  id : String,
) -> ComponentGalleryModel {
  update(self, SelectItem(id))
}

///|
pub fn ComponentGalleryModel::route(self : ComponentGalleryModel) -> String {
  gallery_item_id_to_string(self.active_item)
}

///|
pub fn subscriptions(
  _model : ComponentGalleryModel,
) -> @moui.Subscription[ComponentGalleryMsg] {
  @moui.Subscription::none()
}

///|
pub fn update(
  model : ComponentGalleryModel,
  message : ComponentGalleryMsg,
) -> ComponentGalleryModel {
  match message {
    SelectItem(id) => {
      let next = gallery_item_id_from_string(id).unwrap_or(model.active_item)
      {
        ..model,
        active_item: next,
        page_scroll: if next != model.active_item {
          @geometry.Point::new(x=0.0, y=0.0)
        } else {
          model.page_scroll
        },
      }
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
      {
        ..model,
        search_query: query,
        active_item: next,
        page_scroll: if next != model.active_item {
          @geometry.Point::new(x=0.0, y=0.0)
        } else {
          model.page_scroll
        },
      }
    }
    SelectPlatform(id) =>
      {
        ..model,
        selected_platform: platform_id_from_string(id).unwrap_or(
          model.selected_platform,
        ),
        active_item: ComponentGalleryItemId::PlatformRoutes,
        page_scroll: @geometry.Point::new(x=0.0, y=0.0),
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
    ProbeTextChanged(value) => { ..model, probe_text: value }
    ProbeFeatureToggled(value) =>
      {
        ..model,
        feature_enabled: value,
        probe_action_count: model.probe_action_count + 1,
      }
    ProbeSliderChanged(value) =>
      {
        ..model,
        slider_value: value,
        probe_action_count: model.probe_action_count + 1,
      }
    ProbeAction => { ..model, probe_action_count: model.probe_action_count + 1 }
    ProbeSubmit => { ..model, probe_submit_count: model.probe_submit_count + 1 }
    ProbeDialogOpen =>
      {
        ..model,
        probe_dialog_open: true,
        probe_action_count: model.probe_action_count + 1,
      }
    ProbeDialogClose => { ..model, probe_dialog_open: false }
    ToggleCheckboxGroupItem(id) => {
      let next : Array[String] = []
      for item in model.checkbox_group_selection {
        if item != id {
          next.push(item)
        }
      }
      if !model.checkbox_group_selection.contains(id) {
        next.push(id)
      }
      { ..model, checkbox_group_selection: next }
    }
    PageScrolled(offset) => { ..model, page_scroll: offset }
    Reset =>
      {
        ..model,
        sample_text: "Showcase Components",
        sample_number: "24",
        password_revealed: false,
        selected_mode: "canvas",
        selected_density: "regular",
        feature_enabled: true,
        slider_value: 0.66,
        counter: 0,
        probe_text: "mobile-service-probe",
        probe_action_count: 0,
        probe_submit_count: 0,
        probe_dialog_open: false,
        checkbox_group_selection: ["desktop", "mobile"],
      }
  }
}
