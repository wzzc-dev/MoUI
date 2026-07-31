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
pub(all) enum TextFieldVariant {
  Filled
  Outline
  Plain
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ContainerVariant {
  Base
  Raised
  Overlay
} derive(Eq, Debug, ToJson)

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
pub(all) enum MainAlign {
  Start
  Center
  End
  Between
  Around
  Evenly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CrossAlign {
  Start
  Center
  End
  Stretch
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ChipVariant {
  Filled
  Outline
  Soft
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SegmentedControlSize {
  Compact
  Regular
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FeedbackTone {
  Neutral
  Success
  Warning
  Danger
  Info
} derive(Eq, Debug, ToJson)

///|
pub(all) enum BadgeTone {
  Neutral
  Accent
  Success
  Warning
  Danger
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SheetPresentationMode {
  Modal
  BottomSheet
} derive(Eq, Debug, ToJson)

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
pub(all) enum DatePickerMode {
  Date
  DateAndTime
  Time
} derive(Eq, Debug, ToJson)

///|
pub fn ButtonVariant::style(
  self : ButtonVariant,
  components : ControlThemeSet,
) -> ButtonStyle {
  let bt = components.button
  let v = self.to_token()
  {
    normal: bt.resolve(v, @core.InteractionState::Normal),
    hovered: bt.resolve(v, @core.InteractionState::Hovered),
    pressed: bt.resolve(v, @core.InteractionState::Pressed),
    disabled: bt.resolve(v, @core.InteractionState::Disabled),
  }
}

///|
pub fn ButtonVariant::to_token(self : ButtonVariant) -> ButtonVariantToken {
  match self {
    Primary => ButtonVariantToken::Primary
    Tonal => ButtonVariantToken::Tonal
    Outline => ButtonVariantToken::Outline
    Ghost => ButtonVariantToken::Ghost
    Subtle => ButtonVariantToken::Subtle
    SubtleBrand => ButtonVariantToken::SubtleBrand
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
      { ..base, normal, focused: normal }
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
        brush: theme.surface_brush(@core.SurfaceLevel::Overlay),
        level: @core.SurfaceLevel::Overlay,
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
      { ..theme.typography.body, families: @core.FontFamilyStack::monospace() }
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
    Start => @core.MainAxisAlignment::MainStart
    Center => @core.MainAxisAlignment::MainCenter
    End => @core.MainAxisAlignment::MainEnd
    Between => @core.MainAxisAlignment::SpaceBetween
    Around => @core.MainAxisAlignment::SpaceAround
    Evenly => @core.MainAxisAlignment::SpaceEvenly
  }
}

///|
pub fn CrossAlign::core(self : CrossAlign) -> @core.CrossAxisAlignment {
  match self {
    Start => @core.CrossAxisAlignment::CrossStart
    Center => @core.CrossAxisAlignment::CrossCenter
    End => @core.CrossAxisAlignment::CrossEnd
    Stretch => @core.CrossAxisAlignment::CrossStretch
  }
}
