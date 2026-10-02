///|
pub(all) enum ButtonVariant {
  Primary
  Tonal
  Outline
  Ghost
  Subtle
  SubtleBrand
} derive(Eq, Debug, ToJson)

///|
pub extend ButtonVariant with Debug::{to_repr}

///|
pub extend ButtonVariant with Eq::{not_equal, equal}

///|
pub extend ButtonVariant with ToJson::{to_json}

///|
pub(all) enum TextFieldVariant {
  Filled
  Outline
  Plain
} derive(Eq, Debug, ToJson)

///|
pub extend TextFieldVariant with Debug::{to_repr}

///|
pub extend TextFieldVariant with Eq::{not_equal, equal}

///|
pub extend TextFieldVariant with Show::{to_string, output}

///|
pub extend TextFieldVariant with ToJson::{to_json}

///|
pub(all) enum ContainerVariant {
  Base
  Raised
  Overlay
} derive(Eq, Debug, ToJson)

///|
pub extend ContainerVariant with Debug::{to_repr}

///|
pub extend ContainerVariant with Eq::{not_equal, equal}

///|
pub extend ContainerVariant with Show::{to_string, output}

///|
pub extend ContainerVariant with ToJson::{to_json}

///|
pub(all) enum TextRole {
  Body
  Title
  Caption
  Control
  Mono
  Display
  Headline
  Subtitle
  Label
  Overline
} derive(Eq, Debug, ToJson)

///|
pub extend TextRole with Debug::{to_repr}

///|
pub extend TextRole with Eq::{not_equal, equal}

///|
pub extend TextRole with Show::{to_string, output}

///|
pub extend TextRole with ToJson::{to_json}

///|
pub(all) enum MainAlign {
  Start
  Center
  End
  Between
  Around
  Evenly
} derive(Eq, Debug, ToJson)

///|
pub extend MainAlign with Debug::{to_repr}

///|
pub extend MainAlign with Eq::{not_equal, equal}

///|
pub extend MainAlign with Show::{to_string, output}

///|
pub extend MainAlign with ToJson::{to_json}

///|
pub(all) enum CrossAlign {
  Start
  Center
  End
  Stretch
} derive(Eq, Debug, ToJson)

///|
pub extend CrossAlign with Debug::{to_repr}

///|
pub extend CrossAlign with Eq::{not_equal, equal}

///|
pub extend CrossAlign with Show::{to_string, output}

///|
pub extend CrossAlign with ToJson::{to_json}

///|
pub(all) enum ChipVariant {
  Filled
  Outline
  Soft
} derive(Eq, Debug, ToJson)

///|
pub extend ChipVariant with Debug::{to_repr}

///|
pub extend ChipVariant with Eq::{not_equal, equal}

///|
pub extend ChipVariant with Show::{to_string, output}

///|
pub extend ChipVariant with ToJson::{to_json}

///|
pub(all) enum SegmentedControlSize {
  Compact
  Regular
} derive(Eq, Debug, ToJson)

///|
pub extend SegmentedControlSize with Debug::{to_repr}

///|
pub extend SegmentedControlSize with Eq::{not_equal, equal}

///|
pub extend SegmentedControlSize with Show::{to_string, output}

///|
pub extend SegmentedControlSize with ToJson::{to_json}

///|
pub(all) enum FeedbackTone {
  Neutral
  Success
  Warning
  Danger
  Info
} derive(Eq, Debug, ToJson)

///|
pub extend FeedbackTone with Debug::{to_repr}

///|
pub extend FeedbackTone with Eq::{not_equal, equal}

///|
pub extend FeedbackTone with Show::{to_string, output}

///|
pub extend FeedbackTone with ToJson::{to_json}

///|
pub(all) enum BadgeTone {
  Neutral
  Accent
  Success
  Warning
  Danger
} derive(Eq, Debug, ToJson)

///|
pub extend BadgeTone with Debug::{to_repr}

///|
pub extend BadgeTone with Eq::{not_equal, equal}

///|
pub extend BadgeTone with Show::{to_string, output}

///|
pub extend BadgeTone with ToJson::{to_json}

///|
pub(all) enum SheetPresentationMode {
  Modal
  BottomSheet
} derive(Eq, Debug, ToJson)

///|
pub extend SheetPresentationMode with Debug::{to_repr}

///|
pub extend SheetPresentationMode with Eq::{not_equal, equal}

///|
pub extend SheetPresentationMode with Show::{to_string, output}

///|
pub extend SheetPresentationMode with ToJson::{to_json}

///|
pub(all) enum IconName {
  Check
  Close
  ChevronDown
  ChevronRight
  ChevronLeft
  Plus
  Minus
  Search
  ArrowRight
  Settings
  Gear
  Trash
  Info
  FileNew
  FolderOpen
  Save
  Clipboard
  Bold
  Italic
  CodeInline
  Link
  Heading
  ListBullet
  ListOrdered
  ListTask
  Quote
  Table
  Eye
  Focus
  Columns
  Sidebar
} derive(Eq, Debug, ToJson)

///|
pub extend IconName with Debug::{to_repr}

///|
pub extend IconName with Eq::{not_equal, equal}

///|
pub extend IconName with ToJson::{to_json}

///|
pub(all) enum DatePickerMode {
  Date
  DateAndTime
  Time
} derive(Eq, Debug, ToJson)

///|
pub extend DatePickerMode with Debug::{to_repr}

///|
pub extend DatePickerMode with Eq::{not_equal, equal}

///|
pub extend DatePickerMode with Show::{to_string, output}

///|
pub extend DatePickerMode with ToJson::{to_json}

///|
pub fn ButtonVariant::style(
  self : ButtonVariant,
  components : ControlThemeSet,
) -> ButtonStyle {
  let bt = components.button
  let v = self.to_token()
  {
    normal: bt.resolve(v, Normal),
    hovered: bt.resolve(v, Hovered),
    pressed: bt.resolve(v, Pressed),
    disabled: bt.resolve(v, Disabled),
  }
}

///|
pub fn ButtonVariant::to_token(self : ButtonVariant) -> ButtonVariantToken {
  match self {
    Primary => Primary
    Tonal => Tonal
    Outline => Outline
    Ghost => Ghost
    Subtle => Subtle
    SubtleBrand => SubtleBrand
  }
}

///|
pub fn TextFieldVariant::style(
  self : TextFieldVariant,
  theme : @core.Theme,
) -> TextFieldStyle {
  match self {
    Filled => TextFieldStyle::filled(theme~)
    Outline => TextFieldStyle::outline(theme~)
    Plain => {
      let base = TextFieldStyle::filled(theme~)
      let clear = @core.Brush::solid(
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      )
      let normal = {
        ..base.normal,
        background: clear,
        border: None,
        radius: 0.0,
      }
      { ..base, normal, focused: normal, }
    }
  }
}

///|
pub fn ContainerVariant::style(
  self : ContainerVariant,
  theme : @core.Theme,
) -> SurfaceStyle {
  match self {
    Base => SurfaceStyle::default(theme~)
    Raised => SurfaceStyle::raised(theme~)
    Overlay =>
      {
        ..SurfaceStyle::default(theme~),
        brush: theme.surface_brush(Overlay),
        level: Overlay,
      }
  }
}

///|
pub fn TextRole::font(self : TextRole, theme : @core.Theme) -> @core.FontSpec {
  match self {
    Body => theme.typography.body
    Title => theme.typography.title
    Caption => theme.typography.caption
    Control => theme.typography.control
    Mono =>
      { ..theme.typography.body, families: @core.FontFamilyStack::monospace(), }
    Display => theme.typography.display
    Headline => theme.typography.headline
    Subtitle => theme.typography.subtitle
    Label => theme.typography.label
    Overline => theme.typography.overline
  }
}

///|
pub fn TextRole::color(self : TextRole, theme : @core.Theme) -> @core.Color {
  match self {
    Caption | Overline => theme.palette.muted
    Body | Title | Control | Mono | Display | Headline | Subtitle | Label =>
      theme.palette.foreground
  }
}

///|
pub fn MainAlign::core(self : MainAlign) -> @core.MainAxisAlignment {
  match self {
    Start => MainStart
    Center => MainCenter
    End => MainEnd
    Between => SpaceBetween
    Around => SpaceAround
    Evenly => SpaceEvenly
  }
}

///|
pub fn CrossAlign::core(self : CrossAlign) -> @core.CrossAxisAlignment {
  match self {
    Start => CrossStart
    Center => CrossCenter
    End => CrossEnd
    Stretch => CrossStretch
  }
}
