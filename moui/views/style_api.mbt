///|
pub(all) enum ButtonVariant {
  Primary
  Tonal
  Outline
  Ghost
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextFieldVariant {
  Filled
  Outline
  Plain
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SurfaceVariant {
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
pub(all) enum FormFieldStatus {
  Normal
  Required
  Invalid
  Disabled
  ReadOnly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FormFieldLayout {
  Vertical
  Horizontal
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FormValidationDisplay {
  Always
  OnInvalid
  Hidden
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ChoiceItem {
  id : String
  label : String
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
pub(all) struct StateViewAction[Msg] {
  label : String
  message : Msg
}

///|
pub(all) enum FileImportAvailability {
  Available
  Unavailable(String)
  Pending
}

///|
pub(all) struct FileSelection {
  paths : Array[String]
}

///|
pub fn[Msg] StateViewAction::new(
  label~ : String,
  message~ : Msg,
) -> StateViewAction[Msg] {
  { label, message }
}

///|
pub fn FileSelection::new(paths~ : Array[String]) -> FileSelection {
  { paths, }
}

///|
pub fn FileSelection::empty() -> FileSelection {
  { paths: [] }
}

///|
pub fn FileSelection::is_empty(self : FileSelection) -> Bool {
  self.paths.is_empty()
}

///|
pub fn FileSelection::count(self : FileSelection) -> Int {
  self.paths.length()
}

///|
pub fn FileSelection::summary(
  self : FileSelection,
  empty? : String = "No files selected",
) -> String {
  if self.paths.is_empty() {
    empty
  } else if self.paths.length() == 1 {
    self.paths[0]
  } else {
    "\{self.paths.length()} files selected"
  }
}

///|
pub(all) struct SectionListSection[T] {
  id : String
  title : String
  items : Array[T]
}

///|
pub(all) struct ScrollToIndexIntent {
  index : Int
  offset : @core.Point
}

///|
pub(all) struct BaselineFormRow[Msg] {
  label : @core.View[Msg]
  control : @core.View[Msg]
}

///|
pub fn[T] SectionListSection::new(
  id~ : String,
  title~ : String,
  items~ : Array[T],
) -> SectionListSection[T] {
  { id, title, items }
}

///|
pub fn ScrollToIndexIntent::new(
  index~ : Int,
  offset~ : @core.Point,
) -> ScrollToIndexIntent {
  { index, offset }
}

///|
pub fn[Msg] BaselineFormRow::new(
  label~ : @core.View[Msg],
  control~ : @core.View[Msg],
) -> BaselineFormRow[Msg] {
  { label, control }
}

///|
pub(all) struct MenuItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub(all) struct CommandMenuSection {
  title : String
  commands : Array[@core.ActionCommand]
}

///|
pub(all) enum PopoverPlacement {
  BottomStart
  BottomEnd
  TopStart
  TopEnd
}

///|
pub(all) struct DropdownState {
  expanded : Bool
  selected : String
}

///|
pub fn[Msg] MenuItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> MenuItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn CommandMenuSection::new(
  title~ : String,
  commands~ : Array[@core.ActionCommand],
) -> CommandMenuSection {
  { title, commands }
}

///|
pub fn DropdownState::new(
  expanded? : Bool = false,
  selected? : String = "",
) -> DropdownState {
  { expanded, selected }
}

///|
pub(all) struct SidebarItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub(all) struct BreadcrumbItem[Msg] {
  id : String
  label : String
  message : Msg?
}

///|
pub(all) struct WizardStep[Msg] {
  id : String
  title : String
  subtitle : String
  content : @core.View[Msg]
  enabled : Bool
}

///|
pub fn[Msg] SidebarItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> SidebarItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn[Msg] BreadcrumbItem::new(
  id~ : String,
  label~ : String,
  message? : Msg? = None,
) -> BreadcrumbItem[Msg] {
  { id, label, message }
}

///|
pub fn[Msg] WizardStep::new(
  id~ : String,
  title~ : String,
  subtitle? : String = "",
  content~ : @core.View[Msg],
  enabled? : Bool = true,
) -> WizardStep[Msg] {
  { id, title, subtitle, content, enabled }
}

///|
pub(all) struct DescriptionItem {
  term : String
  detail : String
}

///|
pub(all) struct TableColumn {
  id : String
  label : String
  width : Double
}

///|
pub(all) struct TreeItem {
  id : String
  label : String
  children : Array[TreeItem]
}

///|
pub fn description_item(term : String, detail : String) -> DescriptionItem {
  { term, detail }
}

///|
pub fn table_column(
  id~ : String,
  label~ : String,
  width? : Double = 120.0,
) -> TableColumn {
  { id, label, width }
}

///|
pub fn tree_item(
  id~ : String,
  label~ : String,
  children? : Array[TreeItem] = [],
) -> TreeItem {
  { id, label, children }
}

///|
fn ButtonVariant::style(
  self : ButtonVariant,
  theme : @core.Theme,
) -> @core.ButtonStyle {
  match self {
    Primary => @core.ButtonStyle::filled(theme~)
    Tonal => @core.ButtonStyle::tonal(theme~)
    Outline => @core.ButtonStyle::outline(theme~)
    Ghost => @core.ButtonStyle::ghost(theme~)
  }
}

///|
fn TextFieldVariant::style(
  self : TextFieldVariant,
  theme : @core.Theme,
) -> @core.TextFieldStyle {
  match self {
    Filled => @core.TextFieldStyle::filled(theme~)
    Outline => @core.TextFieldStyle::outline(theme~)
    Plain => {
      let base = @core.TextFieldStyle::filled(theme~)
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
fn SurfaceVariant::style(
  self : SurfaceVariant,
  theme : @core.Theme,
) -> @core.SurfaceStyle {
  match self {
    Base => @core.SurfaceStyle::default(theme~)
    Raised => @core.SurfaceStyle::raised(theme~)
    Overlay =>
      {
        ..@core.SurfaceStyle::default(theme~),
        brush: theme.surface_brush(@core.SurfaceLevel::Overlay),
        level: @core.SurfaceLevel::Overlay,
      }
  }
}

///|
fn TextRole::font(self : TextRole, theme : @core.Theme) -> @core.FontSpec {
  match self {
    Body => theme.typography.body
    Title => theme.typography.title
    Caption => theme.typography.caption
    Control => theme.typography.control
    Mono =>
      { ..theme.typography.body, families: @core.FontFamilyStack::monospace() }
  }
}

///|
fn TextRole::color(self : TextRole, theme : @core.Theme) -> @core.Color {
  match self {
    Caption => theme.palette.muted
    Body | Title | Control | Mono => theme.foreground
  }
}

///|
fn MainAlign::core(self : MainAlign) -> @core.MainAxisAlignment {
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
fn CrossAlign::core(self : CrossAlign) -> @core.CrossAxisAlignment {
  match self {
    Start => @core.CrossAxisAlignment::CrossStart
    Center => @core.CrossAxisAlignment::CrossCenter
    End => @core.CrossAxisAlignment::CrossEnd
    Stretch => @core.CrossAxisAlignment::CrossStretch
  }
}
