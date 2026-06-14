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
  Validating
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
pub struct ChoiceItem {
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
pub struct StateViewAction[Msg] {
  label : String
  message : Msg
}

///|
pub struct ToastStackItem[Msg] {
  id : String
  message : String
  tone : FeedbackTone
  action : StateViewAction[Msg]?
  dismiss : Msg?
}

///|
pub struct ToastQueueItem[Msg] {
  id : String
  message : String
  tone : FeedbackTone
  action : StateViewAction[Msg]?
  dismiss : Msg?
  created_at_ms : Double
  ttl_ms : Double
}

///|
pub struct ToastQueue[Msg] {
  items : Array[ToastQueueItem[Msg]]
}

///|
pub(all) enum FileImportAvailability {
  Available
  Unavailable(String)
  Pending
}

///|
pub struct FileSelection {
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
pub fn[Msg] ToastStackItem::new(
  id~ : String,
  message~ : String,
  tone? : FeedbackTone = FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  dismiss? : Msg? = None,
) -> ToastStackItem[Msg] {
  { id, message, tone, action, dismiss }
}

///|
pub fn[Msg] ToastQueueItem::new(
  id~ : String,
  message~ : String,
  tone? : FeedbackTone = FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  dismiss? : Msg? = None,
  created_at_ms? : Double = 0.0,
  ttl_ms? : Double = 0.0,
) -> ToastQueueItem[Msg] {
  { id, message, tone, action, dismiss, created_at_ms, ttl_ms }
}

///|
pub fn[Msg] ToastQueue::new(
  items? : Array[ToastQueueItem[Msg]] = [],
) -> ToastQueue[Msg] {
  { items: items.copy() }
}

///|
pub fn[Msg] ToastQueue::push(
  self : ToastQueue[Msg],
  item : ToastQueueItem[Msg],
) -> ToastQueue[Msg] {
  let items = self.items.filter(existing => existing.id != item.id)
  items.push(item)
  ToastQueue::new(items~)
}

///|
pub fn[Msg] ToastQueue::expire(
  self : ToastQueue[Msg],
  now_ms : Double,
) -> ToastQueue[Msg] {
  ToastQueue::new(
    items=self.items.filter(item => {
      item.ttl_ms <= 0.0 || now_ms - item.created_at_ms < item.ttl_ms
    }),
  )
}

///|
pub fn[Msg] ToastQueue::to_stack_items(
  self : ToastQueue[Msg],
) -> Array[ToastStackItem[Msg]] {
  self.items.map(item => {
    ToastStackItem::new(
      id=item.id,
      message=item.message,
      tone=item.tone,
      action=item.action,
      dismiss=item.dismiss,
    )
  })
}

///|
pub fn FileSelection::new(paths~ : Array[String]) -> FileSelection {
  { paths, }
}

///|
fn FileSelection::is_empty(self : FileSelection) -> Bool {
  self.paths.is_empty()
}

///|
fn FileSelection::summary(
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
pub struct SectionListSection[T] {
  id : String
  title : String
  items : Array[T]
}

///|
pub struct ScrollToIndexIntent {
  index : Int
  offset : @core.Point
}

///|
pub struct BaselineFormRow[Msg] {
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
fn ScrollToIndexIntent::new(
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
pub struct MenuItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct CommandMenuSection {
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
pub struct DropdownState {
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
pub struct SidebarItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct SectionNavItem[Msg] {
  id : String
  label : String
  summary : String
  message : Msg
  enabled : Bool
}

///|
pub struct BreadcrumbItem[Msg] {
  id : String
  label : String
  message : Msg?
}

///|
pub struct WizardStep[Msg] {
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
pub fn[Msg] SectionNavItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  summary? : String = "",
  enabled? : Bool = true,
) -> SectionNavItem[Msg] {
  { id, label, summary, message, enabled }
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
