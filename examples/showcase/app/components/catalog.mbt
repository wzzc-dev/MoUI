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
    { id: "getting-started", name: "Getting Started" },
    { id: "controls", name: "Controls" },
    { id: "feedback", name: "Feedback" },
    { id: "display", name: "Display" },
    { id: "layout", name: "Layout" },
    { id: "runtime", name: "Runtime" },
  ]
}

///|
fn component_gallery_items() -> Array[ComponentGalleryItemInfo] {
  [
    {
      id: ComponentGalleryItemId::Welcome,
      group: "getting-started",
      name: "Welcome",
      description: "Catalog overview with a live bouncing-ball canvas driven by the animated_canvas paint clock.",
      badge: "intro",
      tone: @views.BadgeTone::Accent,
    },
    {
      id: ComponentGalleryItemId::Button,
      group: "controls",
      name: "Button",
      description: "Action variants and a small counter state loop.",
      badge: "control",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::TextField,
      group: "controls",
      name: "Text Field",
      description: "Single-line text input with outline styling.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::TextArea,
      group: "controls",
      name: "Text Area",
      description: "Multi-line text input for notes and longer values.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::ClearableTextField,
      group: "controls",
      name: "Clearable Text Field",
      description: "A text field paired with an explicit clear action.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::PasswordField,
      group: "controls",
      name: "Password Field",
      description: "Masked input with a reveal toggle.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::NumberField,
      group: "controls",
      name: "Number Field",
      description: "Numeric text entry with optional step controls.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Stepper,
      group: "controls",
      name: "Stepper",
      description: "Increment and decrement actions around a compact label.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Checkbox,
      group: "controls",
      name: "Checkbox",
      description: "Boolean state toggles and label layout.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Toggle,
      group: "controls",
      name: "Toggle",
      description: "Switch-style boolean control for settings.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Radio,
      group: "controls",
      name: "Radio",
      description: "Single option rendered with a circular choice mark.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::RadioGroup,
      group: "controls",
      name: "Radio Group",
      description: "A vertical set of mutually exclusive options.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::CheckboxGroup,
      group: "controls",
      name: "Checkbox Group",
      description: "A compact group for multiple boolean selections.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::SegmentedControl,
      group: "controls",
      name: "Segmented Control",
      description: "Mutually exclusive options rendered as a compact control.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Picker,
      group: "controls",
      name: "Picker",
      description: "A menu-style selector with stable app state.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Slider,
      group: "controls",
      name: "Slider",
      description: "Continuous numeric input with live feedback.",
      badge: "input",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Chips,
      group: "controls",
      name: "Chips",
      description: "Compact selection, filter, and metadata chips.",
      badge: "choice",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryItemId::Badge,
      group: "feedback",
      name: "Badge",
      description: "Small metadata chips and semantic status badges.",
      badge: "status",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::Progress,
      group: "feedback",
      name: "Progress",
      description: "Task status with progress and optional actions.",
      badge: "status",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::Banner,
      group: "feedback",
      name: "Banner",
      description: "A prominent inline message with an optional action.",
      badge: "guidance",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::Callout,
      group: "feedback",
      name: "Callout",
      description: "Contextual guidance next to related content.",
      badge: "guidance",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::StatePanel,
      group: "feedback",
      name: "State Panel",
      description: "Empty, loading, and error states for workflows.",
      badge: "state",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::InlineError,
      group: "feedback",
      name: "Inline Error",
      description: "Compact validation or workflow error row.",
      badge: "state",
      tone: @views.BadgeTone::Danger,
    },
    {
      id: ComponentGalleryItemId::Toast,
      group: "feedback",
      name: "Toast",
      description: "Transient notification surfaces.",
      badge: "notice",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::Snackbar,
      group: "feedback",
      name: "Snackbar",
      description: "Short message with an optional action.",
      badge: "notice",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::StatCard,
      group: "display",
      name: "Stat Card",
      description: "Compact metric cards for dashboards and summaries.",
      badge: "metric",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryItemId::Avatar,
      group: "display",
      name: "Avatar",
      description: "Initials and groups for people or agents.",
      badge: "identity",
      tone: @views.BadgeTone::Accent,
    },
    {
      id: ComponentGalleryItemId::Divider,
      group: "layout",
      name: "Divider",
      description: "A subtle separator for content sections.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::Toolbar,
      group: "layout",
      name: "Toolbar",
      description: "Horizontal action strips for command surfaces.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::StatusBar,
      group: "layout",
      name: "Status Bar",
      description: "Compact state and metadata at the edge of a surface.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::Surface,
      group: "layout",
      name: "Surface",
      description: "Raised and base containers used as component demo blocks.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::RowColumn,
      group: "layout",
      name: "Row & Column",
      description: "Basic horizontal and vertical composition primitives.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::ResponsiveGrid,
      group: "layout",
      name: "Responsive Grid",
      description: "Adaptive grid columns for desktop, mobile, and Web.",
      badge: "adaptive",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::ScrollView,
      group: "layout",
      name: "Scroll View",
      description: "A clipped viewport over larger content.",
      badge: "layout",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryItemId::PlatformRoutes,
      group: "runtime",
      name: "Platform Routes",
      description: "macOS, Linux, Windows, Android, iOS, HarmonyOS, and Web launch routes.",
      badge: "seven hosts",
      tone: @views.BadgeTone::Accent,
    },
    {
      id: ComponentGalleryItemId::MobileServiceProbe,
      group: "runtime",
      name: "Mobile Service Probe",
      description: "Matching-host probe for IME, clipboard, accessibility, async image, and resize evidence.",
      badge: "mobile host",
      tone: @views.BadgeTone::Accent,
    },
    {
      id: ComponentGalleryItemId::AccessibilityProbe,
      group: "runtime",
      name: "Accessibility Probe",
      description: "Stable cross-platform semantics, native tree, action, focus, and live-region evidence fixture.",
      badge: "a11y probe",
      tone: @views.BadgeTone::Accent,
    },
  ]
}

///|
pub fn gallery_item_id_to_string(id : ComponentGalleryItemId) -> String {
  match id {
    ComponentGalleryItemId::Welcome => "welcome"
    ComponentGalleryItemId::Button => "button"
    ComponentGalleryItemId::TextField => "text-field"
    ComponentGalleryItemId::TextArea => "text-area"
    ComponentGalleryItemId::ClearableTextField => "clearable-text-field"
    ComponentGalleryItemId::PasswordField => "password-field"
    ComponentGalleryItemId::NumberField => "number-field"
    ComponentGalleryItemId::Stepper => "stepper"
    ComponentGalleryItemId::Checkbox => "checkbox"
    ComponentGalleryItemId::Toggle => "toggle"
    ComponentGalleryItemId::Radio => "radio"
    ComponentGalleryItemId::RadioGroup => "radio-group"
    ComponentGalleryItemId::CheckboxGroup => "checkbox-group"
    ComponentGalleryItemId::SegmentedControl => "segmented-control"
    ComponentGalleryItemId::Picker => "picker"
    ComponentGalleryItemId::Slider => "slider"
    ComponentGalleryItemId::Chips => "chips"
    ComponentGalleryItemId::Badge => "badge"
    ComponentGalleryItemId::Progress => "progress"
    ComponentGalleryItemId::Banner => "banner"
    ComponentGalleryItemId::Callout => "callout"
    ComponentGalleryItemId::StatePanel => "state-panel"
    ComponentGalleryItemId::InlineError => "inline-error"
    ComponentGalleryItemId::Toast => "toast"
    ComponentGalleryItemId::Snackbar => "snackbar"
    ComponentGalleryItemId::StatCard => "stat-card"
    ComponentGalleryItemId::Avatar => "avatar"
    ComponentGalleryItemId::Divider => "divider"
    ComponentGalleryItemId::Toolbar => "toolbar"
    ComponentGalleryItemId::StatusBar => "status-bar"
    ComponentGalleryItemId::Surface => "surface"
    ComponentGalleryItemId::RowColumn => "row-column"
    ComponentGalleryItemId::ResponsiveGrid => "responsive-grid"
    ComponentGalleryItemId::ScrollView => "scroll-view"
    ComponentGalleryItemId::PlatformRoutes => "platform-routes"
    ComponentGalleryItemId::MobileServiceProbe => "mobile-service-probe"
    ComponentGalleryItemId::AccessibilityProbe => "accessibility-probe"
  }
}

///|
pub fn gallery_item_id_from_string(id : String) -> ComponentGalleryItemId? {
  match id {
    "welcome" => Some(ComponentGalleryItemId::Welcome)
    "button" => Some(ComponentGalleryItemId::Button)
    "text-field" => Some(ComponentGalleryItemId::TextField)
    "text-area" => Some(ComponentGalleryItemId::TextArea)
    "clearable-text-field" => Some(ComponentGalleryItemId::ClearableTextField)
    "password-field" => Some(ComponentGalleryItemId::PasswordField)
    "number-field" => Some(ComponentGalleryItemId::NumberField)
    "stepper" => Some(ComponentGalleryItemId::Stepper)
    "checkbox" => Some(ComponentGalleryItemId::Checkbox)
    "toggle" => Some(ComponentGalleryItemId::Toggle)
    "radio" => Some(ComponentGalleryItemId::Radio)
    "radio-group" => Some(ComponentGalleryItemId::RadioGroup)
    "checkbox-group" => Some(ComponentGalleryItemId::CheckboxGroup)
    "segmented-control" => Some(ComponentGalleryItemId::SegmentedControl)
    "picker" => Some(ComponentGalleryItemId::Picker)
    "slider" => Some(ComponentGalleryItemId::Slider)
    "chips" => Some(ComponentGalleryItemId::Chips)
    "badge" => Some(ComponentGalleryItemId::Badge)
    "progress" => Some(ComponentGalleryItemId::Progress)
    "banner" => Some(ComponentGalleryItemId::Banner)
    "callout" => Some(ComponentGalleryItemId::Callout)
    "state-panel" => Some(ComponentGalleryItemId::StatePanel)
    "inline-error" => Some(ComponentGalleryItemId::InlineError)
    "toast" => Some(ComponentGalleryItemId::Toast)
    "snackbar" => Some(ComponentGalleryItemId::Snackbar)
    "stat-card" => Some(ComponentGalleryItemId::StatCard)
    "avatar" => Some(ComponentGalleryItemId::Avatar)
    "divider" => Some(ComponentGalleryItemId::Divider)
    "toolbar" => Some(ComponentGalleryItemId::Toolbar)
    "status-bar" => Some(ComponentGalleryItemId::StatusBar)
    "surface" => Some(ComponentGalleryItemId::Surface)
    "row-column" => Some(ComponentGalleryItemId::RowColumn)
    "responsive-grid" => Some(ComponentGalleryItemId::ResponsiveGrid)
    "scroll-view" => Some(ComponentGalleryItemId::ScrollView)
    "platform-routes" => Some(ComponentGalleryItemId::PlatformRoutes)
    "mobile-service-probe" => Some(ComponentGalleryItemId::MobileServiceProbe)
    "accessibility-probe" => Some(ComponentGalleryItemId::AccessibilityProbe)
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
