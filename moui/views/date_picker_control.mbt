///|
priv enum DatePickerDisplayMode {
  Date
  DateAndTime
  Time
}

///|
fn[Msg] date_picker_control(
  selected~ : @core.Binding[@core.DateValue],
  mode~ : DatePickerDisplayMode,
  placeholder~ : String,
  theme? : @core.Theme,
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
  on_select? : ((@core.DateValue) -> Msg)? = None,
  kind? : String = "DatePicker",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  @core.View::from_node(
    DatePicker::{
      selected,
      mode,
      placeholder,
      theme,
      style,
      min_date,
      max_date,
      theme_revision,
      has_on_select: on_select is Some(_),
      kind,
      key,
    },
    event=(node, ctx) => date_picker_event(node, ctx, on_select),
  )
}

///|
priv struct DatePicker {
  selected : @core.Binding[@core.DateValue]
  mode : DatePickerDisplayMode
  placeholder : String
  theme : @core.Theme?
  style : PickerStyle?
  min_date : @core.DateValue?
  max_date : @core.DateValue?
  theme_revision : String
  has_on_select : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for DatePicker with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for DatePicker with fn revision(self) {
  "datepicker:\{datepicker_display_value(self.selected.get(), self.mode)}:\{datepicker_mode_revision(self.mode)}:\{self.placeholder}:\{self.theme_revision}:\{datepicker_value_option_revision(self.min_date)}:\{datepicker_value_option_revision(self.max_date)}:\{self.has_on_select}"
}

///|
impl @core.ViewNode for DatePicker with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=200.0, height=40.0)),
  )
}

///|
impl @core.ViewNode for DatePicker with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => PickerStyle::default(theme=resolved_theme)
  }
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  append_datepicker_commands(
    commands,
    overlay_commands,
    frame=ctx.frame,
    selected=self.selected.get(),
    view_date=datepicker_view_date(ctx.state, self.selected.get()),
    mode=self.mode,
    placeholder=self.placeholder,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    min_date=self.min_date,
    max_date=self.max_date,
    expanded=ctx.state.expanded,
    theme=resolved_theme,
  )
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands,
    platform_views: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for DatePicker with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Menu,
    label=self.placeholder,
    value=datepicker_display_value(self.selected.get(), self.mode),
    actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
  )
}

///|
impl @core.ViewNode for DatePicker with fn focusable(_self) {
  true
}

///|
fn[Msg] date_picker_event(
  node : DatePicker,
  ctx : @core.ViewEventContext,
  on_select : ((@core.DateValue) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_datepicker_pointer(
        ctx.state,
        event,
        frame=ctx.frame,
        selected=node.selected,
        min_date=node.min_date,
        max_date=node.max_date,
        on_select~,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_datepicker_keyboard(ctx.state, event, selected=node.selected)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn append_datepicker_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  selected~ : @core.DateValue,
  view_date~ : @core.DateValue,
  mode~ : DatePickerDisplayMode,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  min_date~ : @core.DateValue?,
  max_date~ : @core.DateValue?,
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
  if expanded {
    append_datepicker_popup_commands(
      overlay_commands,
      frame~,
      selected~,
      view_date~,
      foreground~,
      background~,
      min_date~,
      max_date~,
      theme~,
    )
  }
}

///|
fn append_datepicker_popup_commands(
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  selected~ : @core.DateValue,
  view_date~ : @core.DateValue,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  min_date~ : @core.DateValue?,
  max_date~ : @core.DateValue?,
  theme~ : @core.Theme,
) -> Unit {
  let panel_frame = datepicker_popup_frame(frame)
  let panel_rounded = @core.RoundedRect::new(
    rect=panel_frame,
    radius=theme.radius_scale.lg,
  )
  // Align with popover/menu floating surfaces: prefer the component overlay
  // shadow token, fall back to mid elevation (theme docs reserve `md` for
  // picker-like mid layers).
  let shadow = theme.components.surface.overlay_shadow.unwrap_or(
    theme.shadow_scale.md,
  )
  overlay_commands.push(
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
  overlay_commands.push(
    @core.DrawCommand::FillRoundedRectBrush(panel_rounded, background),
  )
  let header_height = datepicker_header_height()
  let header_frame = @core.Rect::new(
    x=panel_frame.origin.x,
    y=panel_frame.origin.y,
    width=panel_frame.size.width,
    height=header_height,
  )
  overlay_commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="\{view_date.year}年\{view_date.month}月",
        frame=header_frame,
        font=@core.FontSpec::new(size=16.0, weight=600),
        color=foreground,
      ),
    ),
  )
  let left_button_frame = datepicker_left_nav_frame(panel_frame)
  let right_button_frame = datepicker_right_nav_frame(panel_frame)
  overlay_commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="◀",
        frame=left_button_frame,
        font=@core.FontSpec::new(size=18.0),
        color=foreground,
      ),
    ),
  )
  overlay_commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="▶",
        frame=right_button_frame,
        font=@core.FontSpec::new(size=18.0),
        color=foreground,
      ),
    ),
  )
  let day_header_height = datepicker_day_header_height()
  let day_cell_width = panel_frame.size.width / 7.0
  let day_names = ["日", "一", "二", "三", "四", "五", "六"]
  for index, day in day_names {
    let day_frame = @core.Rect::new(
      x=panel_frame.origin.x + index.to_double() * day_cell_width,
      y=panel_frame.origin.y + header_height,
      width=day_cell_width,
      height=day_header_height,
    )
    overlay_commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=day,
          frame=day_frame,
          font=@core.FontSpec::new(size=12.0, weight=500),
          color=foreground.with_alpha(0.6),
        ),
      ),
    )
  }
  let cell_height = datepicker_cell_height()
  let start_y = panel_frame.origin.y + header_height + day_header_height
  let year = view_date.year
  let month = view_date.month
  let first_day_weekday = datepicker_first_weekday_of_month_sunday0(year, month)
  let days_in_month_count = datepicker_days_in_month(year, month)
  for day in 1..<=days_in_month_count {
    let total_index = first_day_weekday + day - 1
    let col = total_index % 7
    let row = total_index / 7
    let cell_frame = @core.Rect::new(
      x=panel_frame.origin.x + col.to_double() * day_cell_width,
      y=start_y + row.to_double() * cell_height,
      width=day_cell_width,
      height=cell_height,
    )
    let is_selected = selected.year == year &&
      selected.month == month &&
      selected.day == day
    let candidate = { ..selected, year, month, day }
    let is_selectable = datepicker_value_in_range(candidate, min_date, max_date)
    let cell_rounded = @core.RoundedRect::new(
      rect=cell_frame.inset(@core.Insets::all(4.0)),
      radius=18.0,
    )
    if is_selected {
      overlay_commands.push(
        @core.DrawCommand::FillRoundedRect(cell_rounded, theme.palette.primary),
      )
    }
    let day_color = if is_selected {
      @core.Color::white()
    } else if !is_selectable {
      foreground.with_alpha(0.28)
    } else {
      foreground
    }
    overlay_commands.push(
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
}

///|
fn[Msg] handle_datepicker_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  frame~ : @core.Rect,
  selected~ : @core.Binding[@core.DateValue],
  min_date~ : @core.DateValue?,
  max_date~ : @core.DateValue?,
  on_select~ : ((@core.DateValue) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let main_button_clicked = event.phase == @core.PointerPhase::Up &&
    frame.contains(event.position)
  let panel_frame = datepicker_popup_frame(frame)
  let inside_panel = state.expanded && panel_frame.contains(event.position)
  let claim_focus = event.phase == @core.PointerPhase::Down &&
    (frame.contains(event.position) || inside_panel)
  if state.expanded {
    if main_button_clicked && !panel_frame.contains(event.position) {
      view_event_result(
        changed=true,
        focused=true,
        captured=true,
        state=Some(datepicker_state(state, expanded=false, selected.get())),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if event.phase == @core.PointerPhase::Up &&
      panel_frame.contains(event.position) {
      handle_datepicker_panel_pointer(
        state,
        event,
        panel_frame~,
        selected~,
        min_date~,
        max_date~,
        on_select~,
      )
    } else if event.phase == @core.PointerPhase::Up {
      view_event_result(
        changed=true,
        captured=true,
        state=Some(datepicker_state(state, expanded=false, selected.get())),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if frame.contains(event.position) ||
      panel_frame.contains(event.position) {
      view_event_result(changed=true, focused=claim_focus, captured=true)
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if main_button_clicked {
    view_event_result(
      changed=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, selected.get())),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if claim_focus {
    view_event_result(changed=true, focused=true, captured=true)
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_datepicker_panel_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  panel_frame~ : @core.Rect,
  selected~ : @core.Binding[@core.DateValue],
  min_date~ : @core.DateValue?,
  max_date~ : @core.DateValue?,
  on_select~ : ((@core.DateValue) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let view_date = datepicker_view_date(state, selected.get())
  if datepicker_left_nav_frame(panel_frame).contains(event.position) {
    let next_view = datepicker_previous_month(view_date)
    view_event_result(
      changed=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, next_view)),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if datepicker_right_nav_frame(panel_frame).contains(event.position) {
    let next_view = datepicker_next_month(view_date)
    view_event_result(
      changed=true,
      focused=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=true, next_view)),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    match datepicker_day_at_position(panel_frame, event.position, view_date) {
      Some(day) => {
        let current = selected.get()
        let next = {
          ..current,
          year: view_date.year,
          month: view_date.month,
          day,
        }
        if datepicker_value_in_range(next, min_date, max_date) {
          selected.set(next)
          view_event_result(
            changed=true,
            activated=true,
            focused=true,
            captured=true,
            state=Some(datepicker_state(state, expanded=false, next)),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=datepicker_messages(on_select, next),
          )
        } else {
          @core.ViewEventResult::ignored()
        }
      }
      None => view_event_result(changed=true, focused=true, captured=true)
    }
  }
}

///|
fn[Msg] handle_datepicker_keyboard(
  state : @core.ViewStateContext,
  event : @core.KeyboardEvent,
  selected~ : @core.Binding[@core.DateValue],
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    @core.ViewEventResult::ignored()
  } else if event.key == "Escape" && state.expanded {
    view_event_result(
      changed=true,
      captured=true,
      state=Some(datepicker_state(state, expanded=false, selected.get())),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.key == "Enter" || event.key == "Space" || event.key == " " {
    view_event_result(
      changed=true,
      captured=true,
      state=Some(
        datepicker_state(state, expanded=!state.expanded, selected.get()),
      ),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
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
  { ..state, expanded, scratch: datepicker_encode_view_date(view_date) }
}

///|
fn datepicker_view_date(
  state : @core.ViewStateContext,
  selected : @core.DateValue,
) -> @core.DateValue {
  match datepicker_decode_view_date(state.scratch, selected) {
    Some(value) => value
    None => selected
  }
}

///|
fn datepicker_encode_view_date(value : @core.DateValue) -> String {
  "\{value.year}:\{value.month}"
}

///|
fn datepicker_decode_view_date(
  value : String,
  selected : @core.DateValue,
) -> @core.DateValue? {
  match datepicker_split_once(value, ':') {
    Some((year, month)) =>
      match (datepicker_parse_int(year), datepicker_parse_int(month)) {
        (Some(year), Some(month)) =>
          if month >= 1 && month <= 12 {
            Some({ ..selected, year, month })
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn datepicker_split_once(value : String, delimiter : Char) -> (String, String)? {
  let chars = value.to_array()
  for index, char in chars {
    if char == delimiter {
      return Some(
        (
          datepicker_chars_to_string(chars[:index]),
          datepicker_chars_to_string(chars[index + 1:]),
        ),
      )
    }
  } nobreak {
    None
  }
}

///|
fn datepicker_chars_to_string(chars : ArrayView[Char]) -> String {
  let builder = StringBuilder()
  for char in chars {
    builder.write_char(char)
  }
  builder.to_string()
}

///|
fn datepicker_parse_int(value : String) -> Int? {
  let chars = value.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut index = 0
  let mut sign = 1
  if chars[index] == '-' {
    sign = -1
    index = index + 1
  }
  if index >= chars.length() {
    return None
  }
  let mut parsed = 0
  while index < chars.length() {
    let char = chars[index]
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
    index = index + 1
  }
  Some(parsed * sign)
}

///|
fn datepicker_popup_frame(frame : @core.Rect) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + frame.size.height + 4.0,
    width=view_max_double(frame.size.width, 280.0),
    height=350.0,
  )
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
fn datepicker_mode_revision(mode : DatePickerDisplayMode) -> String {
  match mode {
    Date => "date"
    DateAndTime => "datetime"
    Time => "time"
  }
}

///|
fn datepicker_value_option_revision(value : @core.DateValue?) -> String {
  match value {
    Some(value) => value.format_date_time()
    None => "none"
  }
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
