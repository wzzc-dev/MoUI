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
pub fn[Msg] ToastQueue::dismiss(
  self : ToastQueue[Msg],
  id : String,
) -> ToastQueue[Msg] {
  ToastQueue::new(items=self.items.filter(item => item.id != id))
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
pub fn FileSelection::empty() -> FileSelection {
  { paths: [] }
}

///|
fn FileSelection::is_empty(self : FileSelection) -> Bool {
  self.paths.is_empty()
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
pub struct DescriptionItem {
  term : String
  detail : String
}

///|
pub struct TableColumn {
  id : String
  label : String
  width : Double
}

///|
pub struct DataSortState {
  column : String
  ascending : Bool
}

///|
pub struct PaginationState {
  page : Int
  page_size : Int
  total_count : Int
}

///|
pub(all) struct ColumnVisibilityState {
  visible : Array[String]
  locked : Array[String]
}

///|
pub(all) struct ColumnWidthState {
  widths : Array[TableColumn]
  min_width : Double
  max_width : Double
}

///|
pub(all) struct ColumnOrderState {
  order : Array[String]
}

///|
pub(all) struct SelectionState {
  selected : Array[String]
}

///|
pub struct DataFilter[Msg] {
  id : String
  label : String
  selected : Bool
  message : Msg
  enabled : Bool
}

///|
pub struct SelectableListItem[Msg] {
  id : String
  title : String
  subtitle : String
  detail : String
  message : Msg
  enabled : Bool
}

///|
pub struct TreeItem {
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
pub fn TableColumn::id(self : TableColumn) -> String {
  self.id
}

///|
pub fn TableColumn::width(self : TableColumn) -> Double {
  self.width
}

///|
pub fn DataSortState::new(
  column? : String = "",
  ascending? : Bool = true,
) -> DataSortState {
  { column, ascending }
}

///|
pub fn DataSortState::column(self : DataSortState) -> String {
  self.column
}

///|
pub fn DataSortState::ascending(self : DataSortState) -> Bool {
  self.ascending
}

///|
pub fn DataSortState::toggle(
  self : DataSortState,
  column : String,
) -> DataSortState {
  if self.column == column {
    { column, ascending: !self.ascending }
  } else {
    { column, ascending: true }
  }
}

///|
pub fn PaginationState::new(
  page? : Int = 0,
  page_size? : Int = 25,
  total_count? : Int = 0,
) -> PaginationState {
  {
    page: views_max_int(0, page),
    page_size: views_max_int(1, page_size),
    total_count: views_max_int(0, total_count),
  }
}

///|
pub fn PaginationState::page(self : PaginationState) -> Int {
  self.page
}

///|
pub fn PaginationState::page_size(self : PaginationState) -> Int {
  self.page_size
}

///|
pub fn PaginationState::page_count(self : PaginationState) -> Int {
  if self.total_count == 0 {
    1
  } else {
    (self.total_count + self.page_size - 1) / self.page_size
  }
}

///|
pub fn PaginationState::clamped(self : PaginationState) -> PaginationState {
  let page_count = self.page_count()
  { ..self, page: views_min_int(views_max_int(0, self.page), page_count - 1) }
}

///|
pub fn PaginationState::next(self : PaginationState) -> PaginationState {
  { ..self, page: views_min_int(self.page + 1, self.page_count() - 1) }
}

///|
pub fn PaginationState::previous(self : PaginationState) -> PaginationState {
  { ..self, page: views_max_int(0, self.page - 1) }
}

///|
pub fn PaginationState::start_index(self : PaginationState) -> Int {
  self.clamped().page * self.page_size
}

///|
pub fn PaginationState::end_index(self : PaginationState) -> Int {
  views_min_int(self.total_count, self.start_index() + self.page_size)
}

///|
pub fn ColumnVisibilityState::new(
  visible~ : Array[String],
  locked? : Array[String] = [],
) -> ColumnVisibilityState {
  { visible: visible.copy(), locked: locked.copy() }
}

///|
pub fn ColumnVisibilityState::is_visible(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.visible, id)
}

///|
fn ColumnVisibilityState::is_locked(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.locked, id)
}

///|
pub fn ColumnVisibilityState::set_visible(
  self : ColumnVisibilityState,
  id : String,
  visible : Bool,
) -> ColumnVisibilityState {
  if self.is_locked(id) {
    self
  } else {
    { ..self, visible: set_string_selected(self.visible, id, visible) }
  }
}

///|
pub fn ColumnWidthState::new(
  widths? : Array[TableColumn] = [],
  min_width? : Double = 72.0,
  max_width? : Double = 360.0,
) -> ColumnWidthState {
  {
    widths: widths.copy(),
    min_width,
    max_width: views_max_double(min_width, max_width),
  }
}

///|
pub fn ColumnWidthState::width_for(
  self : ColumnWidthState,
  id : String,
  fallback : Double,
) -> Double {
  for column in self.widths {
    if column.id == id {
      return column.width
    }
  }
  fallback
}

///|
pub fn ColumnWidthState::resize(
  self : ColumnWidthState,
  id : String,
  width : Double,
) -> ColumnWidthState {
  let next = self.widths.copy()
  let clamped = views_clamp_double(width, self.min_width, self.max_width)
  for index, column in next {
    if column.id == id {
      next[index] = { ..column, width: clamped }
      return { ..self, widths: next }
    }
  }
  next.push(table_column(id~, label=id, width=clamped))
  { ..self, widths: next }
}

///|
pub fn ColumnWidthState::apply(
  self : ColumnWidthState,
  columns : Array[TableColumn],
) -> Array[TableColumn] {
  columns.map(column => {
    ..column,
    width: self.width_for(column.id, column.width),
  })
}

///|
pub fn ColumnOrderState::new(order? : Array[String] = []) -> ColumnOrderState {
  { order: order.copy() }
}

///|
pub fn ColumnOrderState::ordered_columns(
  self : ColumnOrderState,
  columns : Array[TableColumn],
) -> Array[TableColumn] {
  let ordered : Array[TableColumn] = []
  for id in self.order {
    for column in columns {
      if column.id == id && !table_columns_contain(ordered, id) {
        ordered.push(column)
      }
    }
  }
  for column in columns {
    if !table_columns_contain(ordered, column.id) {
      ordered.push(column)
    }
  }
  ordered
}

///|
pub fn ColumnOrderState::move_before(
  self : ColumnOrderState,
  id : String,
  before : String,
) -> ColumnOrderState {
  let remaining = self.order.filter(item => item != id)
  let next : Array[String] = []
  let mut inserted = false
  for item in remaining {
    if item == before && !inserted {
      next.push(id)
      inserted = true
    }
    next.push(item)
  }
  if !inserted {
    next.push(id)
  }
  { order: next }
}

///|
pub fn ColumnOrderState::move_after(
  self : ColumnOrderState,
  id : String,
  after : String,
) -> ColumnOrderState {
  let remaining = self.order.filter(item => item != id)
  let next : Array[String] = []
  let mut inserted = false
  for item in remaining {
    next.push(item)
    if item == after && !inserted {
      next.push(id)
      inserted = true
    }
  }
  if !inserted {
    next.push(id)
  }
  { order: next }
}

///|
pub fn SelectionState::new(selected? : Array[String] = []) -> SelectionState {
  { selected: selected.copy() }
}

///|
pub fn SelectionState::contains(self : SelectionState, id : String) -> Bool {
  string_array_contains(self.selected, id)
}

///|
pub fn SelectionState::toggle(
  self : SelectionState,
  id : String,
) -> SelectionState {
  { selected: toggle_string_selected(self.selected, id) }
}

///|
pub fn SelectionState::clear(self : SelectionState) -> SelectionState {
  ignore(self)
  { selected: [] }
}

///|
pub fn SelectionState::count(self : SelectionState) -> Int {
  self.selected.length()
}

///|
fn set_string_selected(
  selected : Array[String],
  id : String,
  enabled : Bool,
) -> Array[String] {
  if enabled {
    if string_array_contains(selected, id) {
      selected.copy()
    } else {
      let next = selected.copy()
      next.push(id)
      next
    }
  } else {
    selected.filter(item => item != id)
  }
}

///|
fn toggle_string_selected(
  selected : Array[String],
  id : String,
) -> Array[String] {
  set_string_selected(selected, id, !string_array_contains(selected, id))
}

///|
fn table_columns_contain(columns : Array[TableColumn], id : String) -> Bool {
  for column in columns {
    if column.id == id {
      return true
    }
  }
  false
}

///|
fn views_clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
pub fn[Msg] data_filter(
  id~ : String,
  label~ : String,
  selected~ : Bool,
  message~ : Msg,
  enabled? : Bool = true,
) -> DataFilter[Msg] {
  { id, label, selected, message, enabled }
}

///|
pub fn[Msg] SelectableListItem::new(
  id~ : String,
  title~ : String,
  message~ : Msg,
  subtitle? : String = "",
  detail? : String = "",
  enabled? : Bool = true,
) -> SelectableListItem[Msg] {
  { id, title, subtitle, detail, message, enabled }
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
