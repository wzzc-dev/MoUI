///|
fn option_double_revision(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}

///|
fn color_revision(color : Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn brush_revision(value : Brush) -> String {
  match value {
    Brush::Solid(color) => "solid:\{color_revision(color)}"
    Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{color_revision(spec.start_color)},\{color_revision(spec.end_color)}"
    Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{color_revision(spec.center_color)},\{color_revision(spec.edge_color)}"
  }
}

///|
fn role_label(role : SemanticsRole) -> String {
  match role {
    None => "none"
    Group => "group"
    Text => "text"
    Link => "link"
    Heading => "heading"
    Navigation => "navigation"
    Main => "main"
    Button => "button"
    TextField => "text-field"
    Checkbox => "checkbox"
    Grid => "grid"
    ScrollView => "scroll-view"
    Switch => "switch"
    Radio => "radio"
    Slider => "slider"
    Progress => "progress"
    Tab => "tab"
    List => "list"
    ListItem => "list-item"
    Dialog => "dialog"
    Tooltip => "tooltip"
    Menu => "menu"
    ButtonGroup => "button-group"
    Form => "form"
    FormField => "form-field"
    Tree => "tree"
    TreeItem => "tree-item"
    WebView => "web-view"
  }
}

///|
fn action_label(action : SemanticsAction) -> String {
  match action {
    Activate => "activate"
    Focus => "focus"
    SetText => "set-text"
    Submit => "submit"
    Scroll => "scroll"
    Select => "select"
    Dismiss => "dismiss"
    Expand => "expand"
    Collapse => "collapse"
  }
}

///|
fn main_axis_alignment_label(alignment : MainAxisAlignment) -> String {
  match alignment {
    MainStart => "start"
    MainCenter => "center"
    MainEnd => "end"
    SpaceAround => "space-around"
    SpaceBetween => "space-between"
    SpaceEvenly => "space-evenly"
  }
}

///|
fn cross_axis_alignment_label(alignment : CrossAxisAlignment) -> String {
  match alignment {
    CrossStart => "start"
    CrossCenter => "center"
    CrossEnd => "end"
    CrossStretch => "stretch"
  }
}
