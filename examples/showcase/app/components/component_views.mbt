///|
fn component_body(
  model : ComponentGalleryModel,
  item : ComponentGalleryItemId,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  match item {
    Welcome => welcome_demo(model, theme, width, compact)
    Button => button_demo(model, theme, width, compact)
    TextField => text_field_demo(model, theme, width)
    TextArea => text_area_demo(model, theme, width)
    ClearableTextField => clearable_text_field_demo(model, theme, width)
    PasswordField => password_field_demo(model, theme, width)
    NumberField => number_field_demo(model, theme, width)
    Stepper => stepper_demo(model, theme, width, compact)
    Checkbox => checkbox_demo(model, theme, width)
    Toggle => toggle_demo(model, theme, width)
    Radio => radio_demo(model, theme, width)
    RadioGroup => radio_group_demo(model, theme, width)
    CheckboxGroup => checkbox_group_demo(model, theme, width)
    SegmentedControl => segmented_control_demo(model, theme, width)
    Picker => picker_demo(model, theme, width)
    Slider => slider_demo(model, theme, width)
    Chips => chips_demo(model, theme, width, compact)
    Badge => badge_demo(model, theme, width, compact)
    Progress => progress_demo(model, theme, width)
    Banner => banner_demo(model, theme, width)
    Callout => callout_demo(model, theme, width, compact)
    StatePanel => state_panel_demo(model, theme, width, compact)
    InlineError => inline_error_demo(model, theme, width)
    Toast => toast_demo(model, theme, width, compact)
    Snackbar => snackbar_demo(model, theme, width)
    StatCard => stat_card_demo(model, theme, width, compact)
    Avatar => avatar_demo(model, theme, width, compact)
    Divider => divider_demo(model, theme, width)
    Toolbar => toolbar_demo(model, theme, width)
    StatusBar => status_bar_demo(model, theme, width)
    Surface => surface_demo(model, theme, width, compact)
    RowColumn => row_column_demo(model, theme, width, compact)
    ResponsiveGrid => responsive_grid_demo(model, theme, width, compact)
    ScrollView => scroll_view_demo(model, theme, width)
    PlatformRoutes => platform_routes_demo(model, theme, width, compact)
    MobileServiceProbe =>
      @views.callout(
        "Moved to Platform",
        "Mobile Service Probe is the Platform workspace default (platform/mobile-service-probe).",
        tone=Info,
        width~,
        theme~,
      )
    AccessibilityProbe => accessibility_probe(model, theme, width)
  }
}
