// === Enum to_string() methods ===
// Stable string contracts for all public enums, mirroring Flutter enum.name
// and Swift String-backed enums. Naming convention: snake_case.

///|
pub fn ButtonVariant::to_string(self : ButtonVariant) -> String {
  match self {
    Primary => "primary"
    Tonal => "tonal"
    Outline => "outline"
    Ghost => "ghost"
    Subtle => "subtle"
    SubtleBrand => "subtle_brand"
  }
}

///|
pub fn TextFieldVariant::to_string(self : TextFieldVariant) -> String {
  match self {
    Filled => "filled"
    Outline => "outline"
    Plain => "plain"
  }
}

///|
pub fn ContainerVariant::to_string(self : ContainerVariant) -> String {
  match self {
    Base => "base"
    Raised => "raised"
    Overlay => "overlay"
  }
}

///|
pub fn TextRole::to_string(self : TextRole) -> String {
  match self {
    Body => "body"
    Title => "title"
    Caption => "caption"
    Control => "control"
    Mono => "mono"
    Display => "display"
    Headline => "headline"
    Subtitle => "subtitle"
    Label => "label"
    Overline => "overline"
  }
}

///|
pub fn MainAlign::to_string(self : MainAlign) -> String {
  match self {
    Start => "start"
    Center => "center"
    End => "end"
    Between => "between"
    Around => "around"
    Evenly => "evenly"
  }
}

///|
pub fn CrossAlign::to_string(self : CrossAlign) -> String {
  match self {
    Start => "start"
    Center => "center"
    End => "end"
    Stretch => "stretch"
  }
}

///|
pub fn ChipVariant::to_string(self : ChipVariant) -> String {
  match self {
    Filled => "filled"
    Outline => "outline"
    Soft => "soft"
  }
}

///|
pub fn SegmentedControlSize::to_string(self : SegmentedControlSize) -> String {
  match self {
    Compact => "compact"
    Regular => "regular"
  }
}

///|
pub fn FeedbackTone::to_string(self : FeedbackTone) -> String {
  match self {
    Neutral => "neutral"
    Success => "success"
    Warning => "warning"
    Danger => "danger"
    Info => "info"
  }
}

///|
pub fn BadgeTone::to_string(self : BadgeTone) -> String {
  match self {
    Neutral => "neutral"
    Accent => "accent"
    Success => "success"
    Warning => "warning"
    Danger => "danger"
  }
}

///|
pub fn SheetPresentationMode::to_string(self : SheetPresentationMode) -> String {
  match self {
    Modal => "modal"
    BottomSheet => "bottom_sheet"
  }
}

///|
pub fn IconName::to_string(self : IconName) -> String {
  match self {
    Check => "check"
    Close => "close"
    ChevronDown => "chevron_down"
    ChevronRight => "chevron_right"
    ChevronLeft => "chevron_left"
    Plus => "plus"
    Minus => "minus"
    Search => "search"
    ArrowRight => "arrow_right"
    Settings => "settings"
    Trash => "trash"
    Info => "info"
    FileNew => "file_new"
    FolderOpen => "folder_open"
    Save => "save"
    Clipboard => "clipboard"
    Bold => "bold"
    Italic => "italic"
    CodeInline => "code_inline"
    Link => "link"
    Heading => "heading"
    ListBullet => "list_bullet"
    ListOrdered => "list_ordered"
    ListTask => "list_task"
    Quote => "quote"
    Table => "table"
    Eye => "eye"
    Focus => "focus"
    Columns => "columns"
    Sidebar => "sidebar"
  }
}

///|
pub fn DatePickerMode::to_string(self : DatePickerMode) -> String {
  match self {
    Date => "date"
    DateAndTime => "date_and_time"
    Time => "time"
  }
}

///|
pub fn PresenceStatus::to_string(self : PresenceStatus) -> String {
  self.label()
}

///|
pub fn PopoverPlacement::to_string(self : PopoverPlacement) -> String {
  match self {
    BottomStart => "bottom_start"
    BottomEnd => "bottom_end"
    TopStart => "top_start"
    TopEnd => "top_end"
  }
}

///|
pub fn FileImportAvailability::to_string(
  self : FileImportAvailability,
) -> String {
  match self {
    Available => "available"
    Unavailable(_) => "unavailable"
    Pending => "pending"
  }
}

///|
pub fn FormFieldStatus::to_string(self : FormFieldStatus) -> String {
  match self {
    Normal => "normal"
    Required => "required"
    Validating => "validating"
    Invalid => "invalid"
    Disabled => "disabled"
    ReadOnly => "read_only"
  }
}

///|
pub fn FormFieldLayout::to_string(self : FormFieldLayout) -> String {
  match self {
    Vertical => "vertical"
    Horizontal => "horizontal"
  }
}

///|
pub fn FormValidationDisplay::to_string(self : FormValidationDisplay) -> String {
  match self {
    Always => "always"
    OnInvalid => "on_invalid"
    Hidden => "hidden"
  }
}
