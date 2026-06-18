///|
using @views {
  badge,
  button,
  column,
  custom_layout,
  empty,
  row,
  scroll_view,
  spacer,
  surface,
  text,
  text_field,
}

///|
priv struct WorkbenchLayout {
  viewport : @moui.Size
  sidebar_width : Double
  sidebar_inner_width : Double
  main_width : Double
  main_padding : Double
  workspace_body_height : Double
  inspector_visible : Bool
  inspector_width : Double
  inspector_gap : Double
  inspector_body_width : Double
  content_width : Double
  scrollbar_width : Double
  panel_width : Double
  panel_body_width : Double
  row_badge_width : Double
  row_text_width : Double
  command_text_width : Double
  top_identity_width : Double
  composer_width : Double
  composer_input_width : Double
  composer_height : Double
  status_bar_height : Double
}

///|
priv struct WorkbenchNextAction {
  title : String
  detail : String
  primary_label : String
  primary_message : WorkbenchMsg
  secondary_label : String
  secondary_message : WorkbenchMsg?
  tone : @views.BadgeTone
}

///|
