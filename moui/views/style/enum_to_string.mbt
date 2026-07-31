// === Enum to_string() methods ===
// Stable string contracts for all public enums, mirroring Flutter enum.name
// and Swift String-backed enums. Naming convention: snake_case.
//
// These types are defined in this package, so `Show` can be implemented
// directly here. The root `moui/views` package re-exports the types and
// gets `to_string` through the `Show` trait automatically.

///|
pub impl Show for TextFieldVariant with fn to_string(self) -> String {
  match self {
    Filled => "filled"
    Outline => "outline"
    Plain => "plain"
  }
}

///|
pub impl Show for ContainerVariant with fn to_string(self) -> String {
  match self {
    Base => "base"
    Raised => "raised"
    Overlay => "overlay"
  }
}

///|
pub impl Show for TextRole with fn to_string(self) -> String {
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
pub impl Show for MainAlign with fn to_string(self) -> String {
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
pub impl Show for CrossAlign with fn to_string(self) -> String {
  match self {
    Start => "start"
    Center => "center"
    End => "end"
    Stretch => "stretch"
  }
}

///|
pub impl Show for ChipVariant with fn to_string(self) -> String {
  match self {
    Filled => "filled"
    Outline => "outline"
    Soft => "soft"
  }
}

///|
pub impl Show for SegmentedControlSize with fn to_string(self) -> String {
  match self {
    Compact => "compact"
    Regular => "regular"
  }
}

///|
pub impl Show for FeedbackTone with fn to_string(self) -> String {
  match self {
    Neutral => "neutral"
    Success => "success"
    Warning => "warning"
    Danger => "danger"
    Info => "info"
  }
}

///|
pub impl Show for BadgeTone with fn to_string(self) -> String {
  match self {
    Neutral => "neutral"
    Accent => "accent"
    Success => "success"
    Warning => "warning"
    Danger => "danger"
  }
}

///|
pub impl Show for SheetPresentationMode with fn to_string(self) -> String {
  match self {
    Modal => "modal"
    BottomSheet => "bottom_sheet"
  }
}

///|
pub impl Show for DatePickerMode with fn to_string(self) -> String {
  match self {
    Date => "date"
    DateAndTime => "date_and_time"
    Time => "time"
  }
}
