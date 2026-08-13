///|
fn component_body(
  model : ComponentGalleryModel,
  item : ComponentGalleryItemId,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  match item {
    ComponentGalleryItemId::Welcome =>
      welcome_demo(model, theme, width, compact)
    ComponentGalleryItemId::Button => button_demo(model, theme, width, compact)
    ComponentGalleryItemId::TextField => text_field_demo(model, theme, width)
    ComponentGalleryItemId::TextArea => text_area_demo(model, theme, width)
    ComponentGalleryItemId::ClearableTextField =>
      clearable_text_field_demo(model, theme, width)
    ComponentGalleryItemId::PasswordField =>
      password_field_demo(model, theme, width)
    ComponentGalleryItemId::NumberField =>
      number_field_demo(model, theme, width)
    ComponentGalleryItemId::Stepper =>
      stepper_demo(model, theme, width, compact)
    ComponentGalleryItemId::Checkbox => checkbox_demo(model, theme, width)
    ComponentGalleryItemId::Toggle => toggle_demo(model, theme, width)
    ComponentGalleryItemId::Radio => radio_demo(model, theme, width)
    ComponentGalleryItemId::RadioGroup => radio_group_demo(model, theme, width)
    ComponentGalleryItemId::CheckboxGroup =>
      checkbox_group_demo(model, theme, width)
    ComponentGalleryItemId::SegmentedControl =>
      segmented_control_demo(model, theme, width)
    ComponentGalleryItemId::Picker => picker_demo(model, theme, width)
    ComponentGalleryItemId::Slider => slider_demo(model, theme, width)
    ComponentGalleryItemId::Chips => chips_demo(model, theme, width, compact)
    ComponentGalleryItemId::Badge => badge_demo(model, theme, width, compact)
    ComponentGalleryItemId::Progress => progress_demo(model, theme, width)
    ComponentGalleryItemId::Banner => banner_demo(model, theme, width)
    ComponentGalleryItemId::Callout =>
      callout_demo(model, theme, width, compact)
    ComponentGalleryItemId::StatePanel =>
      state_panel_demo(model, theme, width, compact)
    ComponentGalleryItemId::InlineError =>
      inline_error_demo(model, theme, width)
    ComponentGalleryItemId::Toast => toast_demo(model, theme, width, compact)
    ComponentGalleryItemId::Snackbar => snackbar_demo(model, theme, width)
    ComponentGalleryItemId::StatCard =>
      stat_card_demo(model, theme, width, compact)
    ComponentGalleryItemId::Avatar => avatar_demo(model, theme, width, compact)
    ComponentGalleryItemId::Divider => divider_demo(model, theme, width)
    ComponentGalleryItemId::Toolbar => toolbar_demo(model, theme, width)
    ComponentGalleryItemId::StatusBar => status_bar_demo(model, theme, width)
    ComponentGalleryItemId::Surface =>
      surface_demo(model, theme, width, compact)
    ComponentGalleryItemId::RowColumn =>
      row_column_demo(model, theme, width, compact)
    ComponentGalleryItemId::ResponsiveGrid =>
      responsive_grid_demo(model, theme, width, compact)
    ComponentGalleryItemId::ScrollView => scroll_view_demo(model, theme, width)
    ComponentGalleryItemId::PlatformRoutes =>
      platform_routes_demo(model, theme, width, compact)
    ComponentGalleryItemId::MobileServiceProbe =>
      @views.callout(
        "Moved to Platform",
        "Mobile Service Probe is the Platform workspace default (platform/mobile-service-probe).",
        tone=@views.FeedbackTone::Info,
        width~,
        theme~,
      )
    ComponentGalleryItemId::AccessibilityProbe =>
      accessibility_probe(model, theme, width)
  }
}
