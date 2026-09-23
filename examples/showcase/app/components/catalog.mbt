///|
priv struct GalleryGroup {
  id : String
  name : String
}

///|
priv struct ComponentGalleryItemInfo {
  id : ComponentGalleryItemId
  group : String
  name : String
  description : String
  badge : String
  tone : @views.BadgeTone
}

///|
fn component_gallery_groups() -> Array[GalleryGroup] {
  [
    { id: "getting-started", name: "Getting Started", },
    { id: "controls", name: "Controls", },
    { id: "feedback", name: "Feedback", },
    { id: "display", name: "Display", },
    { id: "layout", name: "Layout", },
    { id: "runtime", name: "Runtime", },
  ]
}

///|
fn component_gallery_items() -> Array[ComponentGalleryItemInfo] {
  [
    {
      id: Welcome,
      group: "getting-started",
      name: "Welcome",
      description: "Catalog overview with a live bouncing-ball canvas driven by the animated_canvas paint clock.",
      badge: "intro",
      tone: Accent,
    },
    {
      id: Button,
      group: "controls",
      name: "Button",
      description: "Action variants and a small counter state loop.",
      badge: "control",
      tone: Success,
    },
    {
      id: TextField,
      group: "controls",
      name: "Text Field",
      description: "Single-line text input with outline styling.",
      badge: "input",
      tone: Success,
    },
    {
      id: TextArea,
      group: "controls",
      name: "Text Area",
      description: "Multi-line text input for notes and longer values.",
      badge: "input",
      tone: Success,
    },
    {
      id: ClearableTextField,
      group: "controls",
      name: "Clearable Text Field",
      description: "A text field paired with an explicit clear action.",
      badge: "input",
      tone: Success,
    },
    {
      id: PasswordField,
      group: "controls",
      name: "Password Field",
      description: "Masked input with a reveal toggle.",
      badge: "input",
      tone: Success,
    },
    {
      id: NumberField,
      group: "controls",
      name: "Number Field",
      description: "Numeric text entry with optional step controls.",
      badge: "input",
      tone: Success,
    },
    {
      id: Stepper,
      group: "controls",
      name: "Stepper",
      description: "Increment and decrement actions around a compact label.",
      badge: "input",
      tone: Success,
    },
    {
      id: Checkbox,
      group: "controls",
      name: "Checkbox",
      description: "Boolean state toggles and label layout.",
      badge: "input",
      tone: Success,
    },
    {
      id: Toggle,
      group: "controls",
      name: "Toggle",
      description: "Switch-style boolean control for settings.",
      badge: "input",
      tone: Success,
    },
    {
      id: Radio,
      group: "controls",
      name: "Radio",
      description: "Single option rendered with a circular choice mark.",
      badge: "choice",
      tone: Success,
    },
    {
      id: RadioGroup,
      group: "controls",
      name: "Radio Group",
      description: "A vertical set of mutually exclusive options.",
      badge: "choice",
      tone: Success,
    },
    {
      id: CheckboxGroup,
      group: "controls",
      name: "Checkbox Group",
      description: "A compact group for multiple boolean selections.",
      badge: "choice",
      tone: Success,
    },
    {
      id: SegmentedControl,
      group: "controls",
      name: "Segmented Control",
      description: "Mutually exclusive options rendered as a compact control.",
      badge: "choice",
      tone: Success,
    },
    {
      id: Picker,
      group: "controls",
      name: "Picker",
      description: "A menu-style selector with stable app state.",
      badge: "choice",
      tone: Success,
    },
    {
      id: Slider,
      group: "controls",
      name: "Slider",
      description: "Continuous numeric input with live feedback.",
      badge: "input",
      tone: Success,
    },
    {
      id: Chips,
      group: "controls",
      name: "Chips",
      description: "Compact selection, filter, and metadata chips.",
      badge: "choice",
      tone: Success,
    },
    {
      id: Badge,
      group: "feedback",
      name: "Badge",
      description: "Small metadata chips and semantic status badges.",
      badge: "status",
      tone: Warning,
    },
    {
      id: Progress,
      group: "feedback",
      name: "Progress",
      description: "Task status with progress and optional actions.",
      badge: "status",
      tone: Warning,
    },
    {
      id: Banner,
      group: "feedback",
      name: "Banner",
      description: "A prominent inline message with an optional action.",
      badge: "guidance",
      tone: Warning,
    },
    {
      id: Callout,
      group: "feedback",
      name: "Callout",
      description: "Contextual guidance next to related content.",
      badge: "guidance",
      tone: Warning,
    },
    {
      id: StatePanel,
      group: "feedback",
      name: "State Panel",
      description: "Empty, loading, and error states for workflows.",
      badge: "state",
      tone: Warning,
    },
    {
      id: InlineError,
      group: "feedback",
      name: "Inline Error",
      description: "Compact validation or workflow error row.",
      badge: "state",
      tone: Danger,
    },
    {
      id: Toast,
      group: "feedback",
      name: "Toast",
      description: "Transient notification surfaces.",
      badge: "notice",
      tone: Warning,
    },
    {
      id: Snackbar,
      group: "feedback",
      name: "Snackbar",
      description: "Short message with an optional action.",
      badge: "notice",
      tone: Warning,
    },
    {
      id: StatCard,
      group: "display",
      name: "Stat Card",
      description: "Compact metric cards for dashboards and summaries.",
      badge: "metric",
      tone: Warning,
    },
    {
      id: Avatar,
      group: "display",
      name: "Avatar",
      description: "Initials and groups for people or agents.",
      badge: "identity",
      tone: Accent,
    },
    {
      id: Divider,
      group: "layout",
      name: "Divider",
      description: "A subtle separator for content sections.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: Toolbar,
      group: "layout",
      name: "Toolbar",
      description: "Horizontal action strips for command surfaces.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: StatusBar,
      group: "layout",
      name: "Status Bar",
      description: "Compact state and metadata at the edge of a surface.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: Surface,
      group: "layout",
      name: "Surface",
      description: "Raised and base containers used as component demo blocks.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: RowColumn,
      group: "layout",
      name: "Row & Column",
      description: "Basic horizontal and vertical composition primitives.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: ResponsiveGrid,
      group: "layout",
      name: "Responsive Grid",
      description: "Adaptive grid columns for desktop, mobile, and Web.",
      badge: "adaptive",
      tone: Neutral,
    },
    {
      id: ScrollView,
      group: "layout",
      name: "Scroll View",
      description: "A clipped viewport over larger content.",
      badge: "layout",
      tone: Neutral,
    },
    {
      id: PlatformRoutes,
      group: "runtime",
      name: "Platform Routes",
      description: "macOS, Linux, Windows, Android, iOS, HarmonyOS, and Web launch routes.",
      badge: "seven hosts",
      tone: Accent,
    },
    {
      id: MobileServiceProbe,
      group: "runtime",
      name: "Mobile Service Probe",
      description: "Matching-host probe for IME, clipboard, accessibility, async image, and resize evidence.",
      badge: "mobile host",
      tone: Accent,
    },
    {
      id: AccessibilityProbe,
      group: "runtime",
      name: "Accessibility Probe",
      description: "Stable cross-platform semantics, native tree, action, focus, and live-region evidence fixture.",
      badge: "a11y probe",
      tone: Accent,
    },
  ]
}

///|
pub fn gallery_item_id_to_string(id : ComponentGalleryItemId) -> String {
  match id {
    Welcome => "welcome"
    Button => "button"
    TextField => "text-field"
    TextArea => "text-area"
    ClearableTextField => "clearable-text-field"
    PasswordField => "password-field"
    NumberField => "number-field"
    Stepper => "stepper"
    Checkbox => "checkbox"
    Toggle => "toggle"
    Radio => "radio"
    RadioGroup => "radio-group"
    CheckboxGroup => "checkbox-group"
    SegmentedControl => "segmented-control"
    Picker => "picker"
    Slider => "slider"
    Chips => "chips"
    Badge => "badge"
    Progress => "progress"
    Banner => "banner"
    Callout => "callout"
    StatePanel => "state-panel"
    InlineError => "inline-error"
    Toast => "toast"
    Snackbar => "snackbar"
    StatCard => "stat-card"
    Avatar => "avatar"
    Divider => "divider"
    Toolbar => "toolbar"
    StatusBar => "status-bar"
    Surface => "surface"
    RowColumn => "row-column"
    ResponsiveGrid => "responsive-grid"
    ScrollView => "scroll-view"
    PlatformRoutes => "platform-routes"
    MobileServiceProbe => "mobile-service-probe"
    AccessibilityProbe => "accessibility-probe"
  }
}

///|
pub fn gallery_item_id_from_string(id : String) -> ComponentGalleryItemId? {
  match id {
    "welcome" => Some(Welcome)
    "button" => Some(Button)
    "text-field" => Some(TextField)
    "text-area" => Some(TextArea)
    "clearable-text-field" => Some(ClearableTextField)
    "password-field" => Some(PasswordField)
    "number-field" => Some(NumberField)
    "stepper" => Some(Stepper)
    "checkbox" => Some(Checkbox)
    "toggle" => Some(Toggle)
    "radio" => Some(Radio)
    "radio-group" => Some(RadioGroup)
    "checkbox-group" => Some(CheckboxGroup)
    "segmented-control" => Some(SegmentedControl)
    "picker" => Some(Picker)
    "slider" => Some(Slider)
    "chips" => Some(Chips)
    "badge" => Some(Badge)
    "progress" => Some(Progress)
    "banner" => Some(Banner)
    "callout" => Some(Callout)
    "state-panel" => Some(StatePanel)
    "inline-error" => Some(InlineError)
    "toast" => Some(Toast)
    "snackbar" => Some(Snackbar)
    "stat-card" => Some(StatCard)
    "avatar" => Some(Avatar)
    "divider" => Some(Divider)
    "toolbar" => Some(Toolbar)
    "status-bar" => Some(StatusBar)
    "surface" => Some(Surface)
    "row-column" => Some(RowColumn)
    "responsive-grid" => Some(ResponsiveGrid)
    "scroll-view" => Some(ScrollView)
    "platform-routes" => Some(PlatformRoutes)
    "mobile-service-probe" => Some(MobileServiceProbe)
    "accessibility-probe" => Some(AccessibilityProbe)
    _ => None
  }
}

///|
fn gallery_item_info(id : ComponentGalleryItemId) -> ComponentGalleryItemInfo {
  for item in component_gallery_items() {
    if item.id == id {
      return item
    }
  }
  component_gallery_items()[0]
}

///|
fn gallery_item_matches_query(
  item : ComponentGalleryItemInfo,
  query : String,
) -> Bool {
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    true
  } else {
    item.name.to_lower().contains(needle) ||
    item.group.to_lower().contains(needle) ||
    item.description.to_lower().contains(needle) ||
    item.badge.to_lower().contains(needle)
  }
}

///|
fn first_gallery_item_matching(query : String) -> ComponentGalleryItemId? {
  for item in component_gallery_items() {
    if gallery_item_matches_query(item, query) {
      return Some(item.id)
    }
  }
  None
}
