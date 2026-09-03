///|
priv enum DatePickerDisplayMode {
  Date
  DateAndTime
  Time
}

///|
priv enum DatePickerViewDateState {
  FollowSelection
  Month(Int, Int)
}

///|
impl @core.ViewStateValue for DatePickerViewDateState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.DatePickerViewDateState.v1")
}

///|
impl @core.ViewStateValue for DatePickerViewDateState with fn encode_view_state(
  self,
) {
  match self {
    FollowSelection => b"\x00"
    Month(year, month) => {
      let output = Buffer(size_hint=9)
      output.write_byte(1)
      output.write_int_be(year)
      output.write_int_be(month)
      output.to_bytes()
    }
  }
}

///|
impl @core.ViewStateValue for DatePickerViewDateState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes == b"\x00" {
    Some(FollowSelection)
  } else if bytes.length() == 9 && bytes[0] == 1 {
    let year = @core.ViewStateValue::decode_view_state(0, bytes[1:5].to_owned())
    let month = @core.ViewStateValue::decode_view_state(
      0,
      bytes[5:9].to_owned(),
    )
    match (year, month) {
      (Some(year), Some(month)) if month >= 1 && month <= 12 =>
        Some(Month(year, month))
      _ => None
    }
  } else {
    None
  }
}

///|
fn datepicker_view_date_slot() -> @core.ViewStateSlot[DatePickerViewDateState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.date-picker.view-date"),
    initial=DatePickerViewDateState::FollowSelection,
  )
}

///|
fn[Msg] date_picker_control(
  selected~ : @core.DateValue,
  mode~ : DatePickerDisplayMode,
  placeholder~ : String,
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
  on_select? : ((@core.DateValue) -> Msg)? = None,
  kind? : String = "DatePicker",
  key? : String? = None,
) -> @core.View[Msg] {
  let selected_snapshot = selected
  @core.View::from_node(
    DatePicker::{
      selected: selected_snapshot,
      mode,
      placeholder,
      theme,
      style,
      min_date,
      max_date,
      kind,
      key,
    },
    children=_node => {
      [
        @core.View::from_node(
          DatePickerPanel::{
            selected: selected_snapshot,
            min_date,
            max_date,
            on_select,
            theme,
            style,
          },
          event=(node, ctx) => datepicker_panel_event(node, ctx),
        ),
      ]
    },
    event=(node, ctx) => date_picker_event(node, ctx, selected, on_select),
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::activate(ctx => {
          @core.ViewSemanticsActionResult::accepted(
            state=Some({ ..ctx.state, expanded: !ctx.state.expanded }),
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
          )
        }),
      ]
    },
  )
}

///|
priv struct DatePicker {
  selected : @core.DateValue
  mode : DatePickerDisplayMode
  placeholder : String
  theme : @core.Theme?
  style : @style.PickerStyle?
  min_date : @core.DateValue?
  max_date : @core.DateValue?
  kind : String
  key : String?
}

///|
impl @core.ViewNode for DatePicker with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for DatePicker with fn declaration(self) {
  let paint_key = @common.view_record_key("DatePicker.paint", [
    ("selected", datepicker_value_key(self.selected)),
    ("mode", datepicker_mode_key(self.mode)),
    ("placeholder", @core.DeclarationKey::string(self.placeholder)),
    ("min_date", datepicker_value_option_key(self.min_date)),
    ("max_date", datepicker_value_option_key(self.max_date)),
  ])
  @common.view_declaration(
    paint=if self.theme is Some(_) || self.style is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(paint_key)
    },
    semantics=@common.view_exact_channel(
      @common.view_record_key("DatePicker.semantics", [
        ("selected", datepicker_value_key(self.selected)),
        ("mode", datepicker_mode_key(self.mode)),
        ("placeholder", @core.DeclarationKey::string(self.placeholder)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for DatePicker with fn layout(_self, ctx) {
  let own = ctx.constraints.constrain(@core.Size::new(width=200.0, height=40.0))
  // The calendar panel is a real child subtree. Collapsed it receives no
  // frame (not placed, painted, hit-tested, or exposed to semantics);
  // expanded, the post-layout placement pass resolves its absolute frame.
  let child_frames = if ctx.state.expanded {
    let panel_size = if ctx.child_sizes.length() > 0 {
      ctx.child_sizes[0]
    } else {
      @core.Size::new(
        width=datepicker_popup_width(0.0),
        height=datepicker_popup_height(),
      )
    }
    [
      @core.Rect::new(
        x=0.0,
        y=-100000.0,
        width=panel_size.width,
        height=panel_size.height,
      ),
    ]
  } else {
    []
  }
  @core.ViewLayoutResult::new(size=own, child_frames~)
}

///|
impl @core.ViewNode for DatePicker with fn child_constraints(
  _self,
  _constraints,
) {
  // The panel sizes to its own content; parent constraints (tight at place
  // time) must not clamp it.
  @core.Constraints::unbounded()
}

///|
impl @core.ViewNode for DatePicker with fn place_overlays(_self, context) {
  if !context.state.expanded {
    return None
  }
  if context.child_sizes.is_empty() {
    return None
  }
  let natural = context.child_sizes[0]
  let content_size = @core.Size::new(
    width=@common.view_max_double(natural.width, context.host_frame.size.width),
    height=natural.height,
  )
  let placement = @presentation.PresentationPlacement::new(
    candidates=[
      @presentation.PresentationPlacementCandidate::BelowStart,
      @presentation.PresentationPlacementCandidate::AboveStart,
    ],
    viewport_insets=@core.Insets::all(0.0),
  )
  let frame = placement.resolve(
    context.host_frame,
    context.viewport,
    content_size,
  )
  Some([(0, frame)])
}

///|
impl @core.ViewNode for DatePicker with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => @style.PickerStyle::default(theme=resolved_theme)
  }
  let commands : Array[@core.DrawCommand] = []
  append_datepicker_commands(
    commands,
    frame=ctx.frame,
    selected=self.selected,
    mode=self.mode,
    placeholder=self.placeholder,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    expanded=ctx.state.expanded,
    theme=resolved_theme,
  )
  { ..@core.ViewPaintPlan::empty(), commands, }
}

///|
impl @core.ViewNode for DatePicker with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Menu,
    label=self.placeholder,
    value=datepicker_display_value(self.selected, self.mode),
  )
}

///|
impl @core.ViewNode for DatePicker with fn focusable(_self) {
  true
}

///|
fn[Msg] date_picker_event(
  _node : DatePicker,
  ctx : @core.ViewEventContext,
  selected : @core.DateValue,
  _on_select : ((@core.DateValue) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_datepicker_pointer(
        ctx.state,
        event,
        frame=ctx.frame,
        popup_frame=ctx.child_frames.get(0),
        selected~,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_datepicker_keyboard(ctx.state, event, selected~)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn append_datepicker_commands(
  commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  selected~ : @core.DateValue,
  mode~ : DatePickerDisplayMode,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  expanded~ : Bool,
  theme~ : @core.Theme,
) -> Unit {
  // Use the active theme (threaded from the paint environment) instead of a
  // reconstructed neutral theme, so the field outline and popup track the
  // real color scheme and accent in dark mode.
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(theme.palette.outline.multiply_alpha(0.6)),
      1.0,
    ),
  )
  let formatted = datepicker_display_value(selected, mode)
  let display_text = if formatted == "" { placeholder } else { formatted }
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=display_text,
        frame=frame.inset(
          @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
        ),
        font~,
        color=foreground,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  let arrow_size = 16.0
  let arrow_frame = @core.Rect::new(
    x=frame.origin.x + frame.size.width - arrow_size - 12.0,
    y=frame.origin.y + (frame.size.height - arrow_size) / 2.0,
    width=arrow_size,
    height=arrow_size,
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=if expanded { "▲" } else { "▼" },
        frame=arrow_frame,
        font=@core.FontSpec::new(size=12.0),
        color=foreground,
      ),
    ),
  )
}

///|
fn[Msg] handle_datepicker_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  frame~ : @core.Rect,
  popup_frame~ : @core.Rect?,
  selected~ : @core.DateValue,
) -> @core.ViewEventResult[Msg] {
  let main_button_clicked = event.phase == @core.PointerPhase::Up &&
    frame.contains(event.position)
  let panel_hit = match popup_frame {
    Some(popup) => popup.contains(event.position)
    None => false
  }
  let inside_panel = state.expanded && panel_hit
  // Panel interactions (month nav, day selection) are handled by the panel
  // subtree itself; this handler only toggles and closes the popup.
  let claim_focus = event.phase == @core.PointerPhase::Down &&
    frame.contains(event.position)
  if state.expanded {
    if main_button_clicked && !inside_panel {
      @common.view_event_result(
        changed=true,
        focused=true,
        captured=true,
        state=Some(datepicker_state(state, expanded=false, selected)),
        dirty=@core.ViewDirtyHint::ViewLayoutDirty,
      )
    } else if event.phase == @core.PointerPhase::Up {
      @common.view_event_result(
        changed=true,
        captured=true,
        state=Some(datepicker_state(state, expanded=false, selected)),
        dirty=@core.ViewDirtyHint::ViewLayoutDirty,
      )
    } else if frame.contains(event.position) {
      @common.view_event_result(
        changed=true,
        focused=claim_focus,
        captured=true,
      )
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if main_button_clicked {
    @common.view_event_result(
      changed=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, selected)),
      dirty=@core.ViewDirtyHint::ViewLayoutDirty,
    )
  } else if claim_focus {
    @common.view_event_result(changed=true, focused=true, captured=true)
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
/// Panel-local pointer handling. Month navigation keeps the popup open
/// (`activated=true` stops the parent datepicker from closing it); day
/// selection deliberately does NOT activate so the parent's close branch also
/// runs, matching the previous single-handler behavior.
fn[Msg] handle_datepicker_panel_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  panel_frame~ : @core.Rect,
  selected~ : @core.DateValue,
  min_date~ : @core.DateValue?,
  max_date~ : @core.DateValue?,
  on_select~ : ((@core.DateValue) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let view_date = datepicker_view_date(state, selected)
  if datepicker_left_nav_frame(panel_frame).contains(event.position) {
    let next_view = datepicker_previous_month(view_date)
    @common.view_event_result(
      changed=true,
      activated=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, next_view)),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if datepicker_right_nav_frame(panel_frame).contains(event.position) {
    let next_view = datepicker_next_month(view_date)
    @common.view_event_result(
      changed=true,
      activated=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, next_view)),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    match datepicker_day_at_position(panel_frame, event.position, view_date) {
      Some(day) => {
        let current = selected
        let next = {
          ..current,
          year: view_date.year,
          month: view_date.month,
          day,
        }
        if datepicker_value_in_range(next, min_date, max_date) {
          @common.view_event_result(
            changed=true,
            focused=true,
            captured=true,
            state=Some(datepicker_state(state, expanded=true, next)),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=datepicker_messages(on_select, next),
          )
        } else {
          @common.view_event_result(changed=true, focused=true, captured=true)
        }
      }
      None =>
        @common.view_event_result(changed=true, focused=true, captured=true)
    }
  }
}

///|
fn[Msg] handle_datepicker_keyboard(
  state : @core.ViewStateContext,
  event : @core.KeyboardEvent,
  selected~ : @core.DateValue,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    @core.ViewEventResult::ignored()
  } else if event.key == "Escape" && state.expanded {
    @common.view_event_result(
      changed=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=false, selected)),
      dirty=@core.ViewDirtyHint::ViewLayoutDirty,
    )
  } else if event.key == "Enter" || event.key == "Space" || event.key == " " {
    @common.view_event_result(
      changed=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=!state.expanded, selected)),
      dirty=@core.ViewDirtyHint::ViewLayoutDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] datepicker_messages(
  on_select : ((@core.DateValue) -> Msg)?,
  value : @core.DateValue,
) -> Array[Msg] {
  match on_select {
    Some(handler) => [handler(value)]
    None => []
  }
}

///|
fn datepicker_state(
  state : @core.ViewStateContext,
  expanded~ : Bool,
  view_date : @core.DateValue,
) -> @core.ViewStateContext {
  { ..state, expanded, }.with_slot(
    datepicker_view_date_slot(),
    DatePickerViewDateState::Month(view_date.year, view_date.month),
  )
}

///|
fn datepicker_view_date(
  state : @core.ViewStateContext,
  selected : @core.DateValue,
) -> @core.DateValue {
  match state.read_slot(datepicker_view_date_slot()) {
    Month(year, month) => { ..selected, year, month }
    FollowSelection => selected
  }
}

///|
fn datepicker_left_nav_frame(panel_frame : @core.Rect) -> @core.Rect {
  let button_size = datepicker_nav_button_size()
  @core.Rect::new(
    x=panel_frame.origin.x + 8.0,
    y=panel_frame.origin.y + (datepicker_header_height() - button_size) / 2.0,
    width=button_size,
    height=button_size,
  )
}

///|
fn datepicker_right_nav_frame(panel_frame : @core.Rect) -> @core.Rect {
  let button_size = datepicker_nav_button_size()
  @core.Rect::new(
    x=panel_frame.origin.x + panel_frame.size.width - button_size - 8.0,
    y=panel_frame.origin.y + (datepicker_header_height() - button_size) / 2.0,
    width=button_size,
    height=button_size,
  )
}

///|
fn datepicker_day_at_position(
  panel_frame : @core.Rect,
  position : @core.Point,
  view_date : @core.DateValue,
) -> Int? {
  let start_y = panel_frame.origin.y +
    datepicker_header_height() +
    datepicker_day_header_height()
  if position.y < start_y {
    return None
  }
  let day_cell_width = panel_frame.size.width / 7.0
  let clicked_x = position.x - panel_frame.origin.x
  let clicked_y = position.y - start_y
  let col = (clicked_x / day_cell_width).to_int()
  let row = (clicked_y / datepicker_cell_height()).to_int()
  let total_index = row * 7 + col
  let first_day_weekday = datepicker_first_weekday_of_month_sunday0(
    view_date.year,
    view_date.month,
  )
  let day = total_index - first_day_weekday + 1
  let days_in_month_count = datepicker_days_in_month(
    view_date.year,
    view_date.month,
  )
  if day >= 1 && day <= days_in_month_count {
    Some(day)
  } else {
    None
  }
}

///|
fn datepicker_previous_month(value : @core.DateValue) -> @core.DateValue {
  if value.month == 1 {
    { ..value, year: value.year - 1, month: 12 }
  } else {
    { ..value, month: value.month - 1 }
  }
}

///|
fn datepicker_next_month(value : @core.DateValue) -> @core.DateValue {
  if value.month == 12 {
    { ..value, year: value.year + 1, month: 1 }
  } else {
    { ..value, month: value.month + 1 }
  }
}

///|
fn datepicker_compare_int(left : Int, right : Int) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn datepicker_compare_value(
  left : @core.DateValue,
  right : @core.DateValue,
) -> Int {
  let year = datepicker_compare_int(left.year, right.year)
  if year != 0 {
    year
  } else {
    let month = datepicker_compare_int(left.month, right.month)
    if month != 0 {
      month
    } else {
      let day = datepicker_compare_int(left.day, right.day)
      if day != 0 {
        day
      } else {
        let hour = datepicker_compare_int(left.hour, right.hour)
        if hour != 0 {
          hour
        } else {
          let minute = datepicker_compare_int(left.minute, right.minute)
          if minute != 0 {
            minute
          } else {
            datepicker_compare_int(left.second, right.second)
          }
        }
      }
    }
  }
}

///|
fn datepicker_value_in_range(
  value : @core.DateValue,
  min_date : @core.DateValue?,
  max_date : @core.DateValue?,
) -> Bool {
  let after_min = match min_date {
    Some(min_date) => datepicker_compare_value(value, min_date) >= 0
    None => true
  }
  let before_max = match max_date {
    Some(max_date) => datepicker_compare_value(value, max_date) <= 0
    None => true
  }
  after_min && before_max
}

///|
fn datepicker_first_weekday_of_month_sunday0(year : Int, month : Int) -> Int {
  let q = 1
  let zeller_month = if month < 3 { month + 12 } else { month }
  let zeller_year = if month < 3 { year - 1 } else { year }
  let k = zeller_year % 100
  let j = zeller_year / 100
  let h = (q + 13 * (zeller_month + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
  if h == 0 {
    6
  } else {
    h - 1
  }
}

///|
fn datepicker_is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn datepicker_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if datepicker_is_leap_year(year) { 29 } else { 28 }
    _ => 31
  }
}

///|
fn datepicker_mode_key(mode : DatePickerDisplayMode) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match mode {
      Date => 0
      DateAndTime => 1
      Time => 2
    },
  )
}

///|
fn datepicker_value_key(value : @core.DateValue) -> @core.DeclarationKey {
  @common.view_record_key("DateValue", [
    ("year", @core.DeclarationKey::int(value.year)),
    ("month", @core.DeclarationKey::int(value.month)),
    ("day", @core.DeclarationKey::int(value.day)),
    ("hour", @core.DeclarationKey::int(value.hour)),
    ("minute", @core.DeclarationKey::int(value.minute)),
    ("second", @core.DeclarationKey::int(value.second)),
  ])
}

///|
fn datepicker_value_option_key(
  value : @core.DateValue?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(datepicker_value_key))
}

///|
fn datepicker_display_value(
  value : @core.DateValue,
  mode : DatePickerDisplayMode,
) -> String {
  match mode {
    Date => value.format_date()
    DateAndTime => value.format_date_time()
    Time => value.format_time()
  }
}

///|
fn datepicker_header_height() -> Double {
  50.0
}

///|
fn datepicker_day_header_height() -> Double {
  36.0
}

///|
fn datepicker_cell_height() -> Double {
  36.0
}

///|
fn datepicker_nav_button_size() -> Double {
  32.0
}

///|
fn datepicker_popup_width(anchor_width : Double) -> Double {
  @common.view_max_double(anchor_width, 280.0)
}

///|
fn datepicker_popup_height() -> Double {
  350.0
}

///|
/// The calendar popup as a real child subtree. It owns the visible-month slot
/// (month navigation repaints the panel without closing it) and paints the
/// day grid; escaping ancestor clips is handled by the runtime's overlay
/// placement hoist.
priv struct DatePickerPanel[Msg] {
  selected : @core.DateValue
  min_date : @core.DateValue?
  max_date : @core.DateValue?
  on_select : ((@core.DateValue) -> Msg)?
  theme : @core.Theme?
  style : @style.PickerStyle?
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn identity(_self) {
  @core.ViewIdentity::new(kind="DatePickerPanel")
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn declaration(_self) {
  @core.ViewDeclaration::uncacheable()
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn child_constraints(
  _self,
  _constraints,
) {
  @core.Constraints::unbounded()
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(
        width=datepicker_popup_width(0.0),
        height=datepicker_popup_height(),
      ),
    ),
  )
}

///|

///|
fn[Msg] datepicker_panel_event(
  node : DatePickerPanel[Msg],
  ctx : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_datepicker_panel_pointer(
        ctx.state,
        event,
        panel_frame=ctx.frame,
        selected=node.selected,
        min_date=node.min_date,
        max_date=node.max_date,
        on_select=node.on_select,
      )
    _ => @core.ViewEventResult::ignored()
  }
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => @style.PickerStyle::default(theme=resolved_theme)
  }
  let view_date = datepicker_view_date(ctx.state, self.selected)
  let commands : Array[@core.DrawCommand] = []
  let panel_rounded = @core.RoundedRect::new(
    rect=ctx.frame,
    radius=resolved_theme.radius_scale.lg,
  )
  // Align with popover/menu floating surfaces: prefer the component overlay
  // shadow token, fall back to mid elevation.
  let shadow = @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
    resolved_theme.shadow_scale.md,
  )
  commands.push(
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=panel_rounded,
        color=shadow.color,
        offset=shadow.offset,
        blur_radius=shadow.blur_radius,
        spread=shadow.spread,
      ),
    ),
  )
  commands.push(
    @core.DrawCommand::FillRoundedRectBrush(
      panel_rounded,
      resolved_style.background,
    ),
  )
  let header_height = datepicker_header_height()
  let header_frame = @core.Rect::new(
    x=ctx.frame.origin.x,
    y=ctx.frame.origin.y,
    width=ctx.frame.size.width,
    height=header_height,
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="\{view_date.year}年\{view_date.month}月",
        frame=header_frame,
        font=@core.FontSpec::new(size=16.0, weight=600),
        color=resolved_style.foreground,
      ),
    ),
  )
  let left_button_frame = datepicker_left_nav_frame(ctx.frame)
  let right_button_frame = datepicker_right_nav_frame(ctx.frame)
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="◀",
        frame=left_button_frame,
        font=@core.FontSpec::new(size=18.0),
        color=resolved_style.foreground,
      ),
    ),
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="▶",
        frame=right_button_frame,
        font=@core.FontSpec::new(size=18.0),
        color=resolved_style.foreground,
      ),
    ),
  )
  let day_header_height = datepicker_day_header_height()
  let day_cell_width = ctx.frame.size.width / 7.0
  let day_names = ["日", "一", "二", "三", "四", "五", "六"]
  for index, day in day_names {
    let day_frame = @core.Rect::new(
      x=ctx.frame.origin.x + index.to_double() * day_cell_width,
      y=ctx.frame.origin.y + header_height,
      width=day_cell_width,
      height=day_header_height,
    )
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=day,
          frame=day_frame,
          font=@core.FontSpec::new(size=12.0, weight=500),
          color=resolved_style.foreground.with_alpha(0.6),
        ),
      ),
    )
  }
  let cell_height = datepicker_cell_height()
  let start_y = ctx.frame.origin.y + header_height + day_header_height
  let year = view_date.year
  let month = view_date.month
  let first_day_weekday = datepicker_first_weekday_of_month_sunday0(year, month)
  let days_in_month_count = datepicker_days_in_month(year, month)
  for day in 1..<=days_in_month_count {
    let total_index = first_day_weekday + day - 1
    let col = total_index % 7
    let row = total_index / 7
    let cell_frame = @core.Rect::new(
      x=ctx.frame.origin.x + col.to_double() * day_cell_width,
      y=start_y + row.to_double() * cell_height,
      width=day_cell_width,
      height=cell_height,
    )
    let is_selected = self.selected.year == year &&
      self.selected.month == month &&
      self.selected.day == day
    let candidate = { ..self.selected, year, month, day }
    let is_selectable = datepicker_value_in_range(
      candidate,
      self.min_date,
      self.max_date,
    )
    let cell_rounded = @core.RoundedRect::new(
      rect=cell_frame.inset(@core.Insets::all(4.0)),
      radius=18.0,
    )
    if is_selected {
      commands.push(
        @core.DrawCommand::FillRoundedRect(
          cell_rounded,
          resolved_theme.palette.primary,
        ),
      )
    }
    let day_color = if is_selected {
      @core.Color::white()
    } else if !is_selectable {
      resolved_style.foreground.with_alpha(0.28)
    } else {
      resolved_style.foreground
    }
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text="\{day}",
          frame=cell_frame,
          font=@core.FontSpec::new(size=14.0),
          color=day_color,
        ),
      ),
    )
  }
  { ..@core.ViewPaintPlan::empty(), commands, }
}

///|
impl[Msg] @core.ViewNode for DatePickerPanel[Msg] with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Dialog,
    label="Calendar",
  )
}
