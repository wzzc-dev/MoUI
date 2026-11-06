///|
/// Immutable declaration data for the example custom control.
///
/// The current value, numeric bounds, and handler availability affect the
/// declaration channels; transient focus, pressed, selection, and IME state
/// stay in the runtime's typed view state.
priv struct EditableCounter {
  label : String
  value : String
  numeric_value : Double
  min_value : Double
  max_value : Double
  step : Double
  width : Double
  height : Double
  has_increment : Bool
  has_decrement : Bool
  key : String?
}

///|
impl @core.ViewNode for EditableCounter with fn identity(self) {
  @core.ViewIdentity::new(kind="EditableCounter", key=self.key)
}

///|
impl @core.ViewNode for EditableCounter with fn declaration(self) {
  let size = @core.DeclarationKey::record(type_tag="EditableCounter.size", fields=[
    ("width", @core.DeclarationKey::double(self.width)),
    ("height", @core.DeclarationKey::double(self.height)),
  ])
  let paint = @core.DeclarationKey::record(type_tag="EditableCounter.paint", fields=[
    ("value", @core.DeclarationKey::string(self.value)),
    ("width", @core.DeclarationKey::double(self.width)),
    ("height", @core.DeclarationKey::double(self.height)),
  ])
  let semantics = @core.DeclarationKey::record(
    type_tag="EditableCounter.semantics",
    fields=[
      ("label", @core.DeclarationKey::string(self.label)),
      ("value", @core.DeclarationKey::string(self.value)),
      ("numeric", @core.DeclarationKey::double(self.numeric_value)),
      ("min", @core.DeclarationKey::double(self.min_value)),
      ("max", @core.DeclarationKey::double(self.max_value)),
      ("step", @core.DeclarationKey::double(self.step)),
      ("increment", @core.DeclarationKey::bool(self.has_increment)),
      ("decrement", @core.DeclarationKey::bool(self.has_decrement)),
    ],
  )
  @core.ViewDeclaration::channels(
    layout=Exact(size),
    paint=Exact(paint),
    semantics=Exact(semantics),
    platform=Constant,
  )
}

///|
impl @core.ViewNode for EditableCounter with fn layout(self, context) {
  let desired = @core.Size::new(width=self.width, height=self.height)
  @core.ViewLayoutResult::new(size=context.constraints.constrain(desired))
}

///|
impl @core.ViewNode for EditableCounter with fn paint(self, context) {
  let theme = context.environment.theme
  let frame = context.frame
  let metrics = editable_counter_metrics(
    frame,
    context.environment.layout_direction,
  )
  let radius = (metrics.value_frame.size.height * 0.2).min(8.0)
  let outer = @core.RoundedRect::new(rect=frame, radius~)
  let border_color = if context.focused {
    theme.palette.focus
  } else {
    theme.palette.outline
  }
  let border_width = if context.focused { 2.0 } else { 1.0 }
  let font = theme.typography.control
  let commands : Array[@core.DrawCommand] = [
    FillRoundedRect(outer, theme.palette.surface),
    StrokeRoundedRect(outer, border_color, border_width),
    FillRect(metrics.leading_divider, theme.palette.outline_variant),
    FillRect(metrics.trailing_divider, theme.palette.outline_variant),
    DrawText(
      @core.TextRun::new(
        text=metrics.leading_glyph,
        frame=metrics.leading_frame,
        font~,
        color=theme.palette.on_surface,
      ),
    ),
    DrawText(
      @core.TextRun::new(
        text=self.value,
        frame=metrics.value_frame,
        font~,
        color=theme.palette.on_surface,
      ),
    ),
    DrawText(
      @core.TextRun::new(
        text=metrics.trailing_glyph,
        frame=metrics.trailing_frame,
        font~,
        color=theme.palette.on_surface,
      ),
    ),
  ]
  @core.ViewPaintPlan::commands(commands)
}

///|
impl @core.ViewNode for EditableCounter with fn text_input_state(self, context) {
  let metrics = editable_counter_metrics(
    context.frame,
    context.environment.layout_direction,
  )
  let font = context.environment.theme.typography.control
  let measured = context.text_system.measure_text(
    @core.TextLayoutInput::new(
      text=self.value,
      font~,
      max_width=metrics.value_frame.size.width,
    ),
  )
  let boundaries = @core.TextGraphemeBoundaries::new(text=self.value)
  let caret = boundaries.clamp_index(context.text_control.caret)
  let caret_x = metrics.value_frame.origin.x +
    (match measured.caret_positions.get(caret) {
      Some(position) => position
      None =>
        match measured.caret_positions.last() {
          Some(position) => position
          None => 0.0
        }
    })
  Some({
    focused: true,
    text: self.value,
    caret,
    selection: context.text_control.selection,
    composition: context.text_control.composition,
    composition_cursor: context.text_control.composition_cursor,
    frame: metrics.value_frame,
    caret_rect: @core.Rect::new(
      x=caret_x,
      y=metrics.value_frame.origin.y + 8.0,
      width=1.0,
      height=(metrics.value_frame.size.height - 16.0).max(1.0),
    ),
  })
}

///|
impl @core.ViewNode for EditableCounter with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=Boundary,
    role=@core.SemanticsRole::TextField,
    label=self.label,
    value=self.value,
    numeric=@core.SemanticsNumericValue::new(
      current=self.numeric_value,
      min=self.min_value,
      max=self.max_value,
      step=self.step,
      value_text=self.value,
    ),
    text=@core.SemanticsTextValue::new(
      caret=@core.TextGraphemeBoundaries::new(text=self.value).length(),
      editable=true,
    ),
  )
}

///|
impl @core.ViewNode for EditableCounter with fn focusable(_self) {
  true
}

///|
priv struct EditableCounterMetrics {
  leading_frame : @core.Rect
  value_frame : @core.Rect
  trailing_frame : @core.Rect
  leading_divider : @core.Rect
  trailing_divider : @core.Rect
  leading_glyph : String
  trailing_glyph : String
}

///|
/// One geometry source for paint, hit testing, text input, and golden tests.
/// Step actions always follow reading order: decrement is on the leading edge
/// and increment on the trailing edge.
fn editable_counter_metrics(
  frame : @core.Rect,
  direction : @core.LayoutDirection,
) -> EditableCounterMetrics {
  let step_width = 40.0.min(frame.size.width * 0.25)
  let leading_x = frame.mirrored_x(
    x=frame.origin.x,
    width=step_width,
    direction~,
  )
  let trailing_x = frame.mirrored_x(
    x=frame.origin.x + frame.size.width - step_width,
    width=step_width,
    direction~,
  )
  let value_x = frame.mirrored_x(
    x=frame.origin.x + step_width,
    width=(frame.size.width - step_width * 2.0).max(0.0),
    direction~,
  )
  let leading_frame = @core.Rect::new(
    x=leading_x,
    y=frame.origin.y,
    width=step_width,
    height=frame.size.height,
  )
  let trailing_frame = @core.Rect::new(
    x=trailing_x,
    y=frame.origin.y,
    width=step_width,
    height=frame.size.height,
  )
  let value_frame = @core.Rect::new(
    x=value_x,
    y=frame.origin.y,
    width=(frame.size.width - step_width * 2.0).max(0.0),
    height=frame.size.height,
  )
  {
    leading_frame,
    value_frame,
    trailing_frame,
    leading_divider: @core.Rect::new(
      x=leading_frame.max_x() - 1.0,
      y=frame.origin.y + 8.0,
      width=1.0,
      height=(frame.size.height - 16.0).max(0.0),
    ),
    trailing_divider: @core.Rect::new(
      x=trailing_frame.origin.x,
      y=frame.origin.y + 8.0,
      width=1.0,
      height=(frame.size.height - 16.0).max(0.0),
    ),
    leading_glyph: "−",
    trailing_glyph: "+",
  }
}

///|
/// A message-independent, focusable editable counter.
///
/// The caller owns the model value and supplies typed messages. The control
/// stores only declaration data; selection and IME composition use the
/// runtime-owned text-control state.
pub fn[Msg] editable_counter(
  label~ : String,
  value~ : String,
  numeric_value~ : Double,
  on_input~ : (String) -> Msg,
  on_increment? : Msg,
  on_decrement? : Msg,
  min_value~ : Double = 0.0,
  max_value~ : Double = 100.0,
  step~ : Double = 1.0,
  width~ : Double = 220.0,
  height~ : Double = 40.0,
  key? : String,
) -> @moui.View[Msg] {
  let node = EditableCounter::{
    label,
    value,
    numeric_value,
    min_value,
    max_value,
    step,
    width,
    height,
    has_increment: on_increment is Some(_),
    has_decrement: on_decrement is Some(_),
    key,
  }
  @core.View::from_node(
    node,
    event=(node, context) => {
      editable_counter_event(
        node, context, on_input, on_increment, on_decrement,
      )
    },
    text_command=(node, context, intent, paste_text) => {
      editable_counter_text_command(node, context, intent, paste_text, on_input)
    },
    semantics_actions=_node => {
      let actions : Array[@core.ViewSemanticsActionHandler[Msg]] = [
        @core.ViewSemanticsActionHandler::set_text((_context, next) => {
          @core.ViewSemanticsActionResult::message(on_input(next))
        }),
      ]
      match on_increment {
        Some(message) =>
          actions.push(
            @core.ViewSemanticsActionHandler::increment(_context => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          )
        None => ()
      }
      match on_decrement {
        Some(message) =>
          actions.push(
            @core.ViewSemanticsActionHandler::decrement(_context => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          )
        None => ()
      }
      actions
    },
  )
}

///|
fn[Msg] editable_counter_event(
  node : EditableCounter,
  context : @core.ViewEventContext,
  on_input : (String) -> Msg,
  on_increment : Msg?,
  on_decrement : Msg?,
) -> @core.ViewEventResult[Msg] {
  let metrics = editable_counter_metrics(
    context.frame,
    context.environment.layout_direction,
  )
  match context.event {
    Pointer(event) =>
      if event.button != 0 {
        @core.ViewEventResult::ignored()
      } else {
        match event.phase {
          Down =>
            if metrics.leading_frame.contains(event.position) {
              match on_decrement {
                Some(message) => editable_counter_event_result(message~)
                None =>
                  editable_counter_event_result(
                    changed=true,
                    focused=true,
                    captured=true,
                  )
              }
            } else if metrics.trailing_frame.contains(event.position) {
              match on_increment {
                Some(message) => editable_counter_event_result(message~)
                None =>
                  editable_counter_event_result(
                    changed=true,
                    focused=true,
                    captured=true,
                  )
              }
            } else if metrics.value_frame.contains(event.position) {
              let boundaries = @core.TextGraphemeBoundaries::new(
                text=node.value,
              )
              let caret = editable_counter_caret_at_position(
                node.value,
                metrics.value_frame,
                context.environment.theme.typography.control,
                context.text_system,
                event.position,
              )
              editable_counter_event_result(
                changed=true,
                focused=true,
                captured=true,
                text_control=Some({
                  ..context.text_control,
                  caret: boundaries.clamp_index(caret),
                  selection: None,
                  text_selection_anchor: None,
                  text_selection_origin: None,
                  composition: None,
                  composition_cursor: None,
                  goal_column: None,
                }),
              )
            } else {
              @core.ViewEventResult::ignored()
            }
          Move | Up | Cancel | Exit =>
            editable_counter_event_result(
              captured=metrics.value_frame.contains(event.position),
            )
        }
      }
    Keyboard(event) if event.pressed &&
      event.modifiers.control == false &&
      event.modifiers.meta == false =>
      match event.key {
        "ArrowUp" =>
          match on_increment {
            Some(message) => editable_counter_event_result(message~)
            None => @core.ViewEventResult::ignored()
          }
        "ArrowDown" =>
          match on_decrement {
            Some(message) => editable_counter_event_result(message~)
            None => @core.ViewEventResult::ignored()
          }
        "Backspace" => {
          let boundaries = @core.TextGraphemeBoundaries::new(text=node.value)
          let end = boundaries.length()
          if end == 0 {
            @core.ViewEventResult::ignored()
          } else {
            let range = @core.TextRange::new(
              start=boundaries.previous_boundary(end),
              end~,
            )
            let next = editable_counter_replace(node.value, range, "")
            editable_counter_text_event(next, on_input)
          }
        }
        _ => @core.ViewEventResult::ignored()
      }
    TextInput(event) =>
      match event {
        InsertText(inserted) => {
          let boundaries = @core.TextGraphemeBoundaries::new(text=node.value)
          let range = match context.text_control.selection {
            Some(selection) =>
              @core.normalize_grapheme_range(boundaries, selection)
            None =>
              @core.TextRange::collapsed(
                boundaries.clamp_index(context.text_control.caret),
              )
          }
          editable_counter_text_event(
            editable_counter_replace(node.value, range, inserted),
            on_input,
          )
        }
        DeleteRange(range) => {
          let boundaries = @core.TextGraphemeBoundaries::new(text=node.value)
          editable_counter_text_event(
            editable_counter_replace(
              node.value,
              @core.normalize_grapheme_range(boundaries, range),
              "",
            ),
            on_input,
          )
        }
        DeleteSurrounding(before, after) => {
          let boundaries = @core.TextGraphemeBoundaries::new(text=node.value)
          let caret = boundaries.clamp_index(context.text_control.caret)
          let start = @core.TextRange::collapsed(caret).start - before
          let end = caret + after
          editable_counter_text_event(
            editable_counter_replace(
              node.value,
              @core.normalize_grapheme_range(
                boundaries,
                @core.TextRange::new(
                  start=boundaries.clamp_index(start),
                  end=boundaries.clamp_index(end),
                ),
              ),
              "",
            ),
            on_input,
          )
        }
        CompositionStart =>
          editable_counter_event_result(
            changed=true,
            captured=true,
            text_control=Some({
              ..context.text_control,
              composition: Some(""),
              composition_cursor: Some(
                @core.TextRange::collapsed(context.text_control.caret),
              ),
            }),
            dirty=ViewPaintDirty,
          )
        CompositionUpdate(update) =>
          editable_counter_event_result(
            changed=true,
            captured=true,
            text_control=Some({
              ..context.text_control,
              composition: Some(update.text()),
              composition_cursor: update.cursor(),
            }),
            dirty=ViewPaintDirty,
          )
        CompositionEnd(text) =>
          editable_counter_text_event(
            editable_counter_replace(
              node.value,
              @core.TextRange::collapsed(context.text_control.caret),
              text,
            ),
            on_input,
          )
        ReplaceText(range, text) =>
          editable_counter_text_event(
            editable_counter_replace(node.value, range, text),
            on_input,
          )
        SetSelection(selection) =>
          editable_counter_event_result(
            changed=true,
            captured=true,
            text_control=Some({
              ..context.text_control,
              caret: selection.end,
              selection: Some(selection),
            }),
            dirty=ViewPaintDirty,
          )
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn editable_counter_replace(
  value : String,
  range : @core.TextRange,
  replacement : String,
) -> String {
  let boundaries = @core.TextGraphemeBoundaries::new(text=value)
  let normalized = @core.normalize_grapheme_range(boundaries, range)
  @core.replace_text_range_edit(text=value, normalized, replacement).0
}

///|
fn editable_counter_caret_at_position(
  value : String,
  frame : @core.Rect,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
  position : @core.Point,
) -> Int32 {
  let boundaries = @core.TextGraphemeBoundaries::new(text=value)
  let measured = text_system.measure_text(
    @core.TextLayoutInput::new(text=value, font~, max_width=frame.size.width),
  )
  if measured.caret_positions.is_empty() {
    return 0
  }
  let x = position.x - frame.origin.x
  let mut best = 0
  let mut best_distance = 1.0e18
  for boundary in boundaries.boundaries() {
    if boundary >= measured.caret_positions.length() {
      break
    }
    let distance = (measured.caret_positions[boundary] - x).abs()
    if distance <= best_distance {
      best = boundary
      best_distance = distance
    }
  }
  best
}

///|
fn[Msg] editable_counter_text_event(
  next : String,
  on_input : (String) -> Msg,
) -> @core.ViewEventResult[Msg] {
  editable_counter_event_result(
    changed=true,
    captured=true,
    text_control=Some({
      caret: @core.TextGraphemeBoundaries::new(text=next).length(),
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    }),
    dirty=ViewBuildDirty,
    messages=[on_input(next)],
  )
}

///|
fn[Msg] editable_counter_text_command(
  node : EditableCounter,
  context : @core.ViewEventContext,
  intent : @core.CommandIntent,
  paste_text : String?,
  on_input : (String) -> Msg,
) -> @core.ViewTextCommandResult[Msg] {
  match intent {
    Copy =>
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(clipboard_text=Some(node.value)),
      )
    Cut =>
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(
          changed=true,
          clipboard_text=Some(node.value),
        ),
        text_control=Some({
          ..context.text_control,
          caret: 0,
          selection: None,
          composition: None,
          composition_cursor: None,
        }),
        messages=[on_input("")],
      )
    Paste =>
      match paste_text {
        Some(text) => {
          let boundaries = @core.TextGraphemeBoundaries::new(text=node.value)
          let range = match context.text_control.selection {
            Some(selection) =>
              @core.normalize_grapheme_range(boundaries, selection)
            None =>
              @core.TextRange::collapsed(
                boundaries.clamp_index(context.text_control.caret),
              )
          }
          let next = editable_counter_replace(node.value, range, text)
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(changed=true),
            text_control=Some({
              ..context.text_control,
              caret: @core.TextGraphemeBoundaries::new(text=next).length(),
              selection: None,
              composition: None,
              composition_cursor: None,
            }),
            messages=[on_input(next)],
          )
        }
        None =>
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::ignored(),
          )
      }
    _ =>
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::ignored(),
      )
  }
}

///|
fn[Msg] editable_counter_event_result(
  message? : Msg,
  changed~ : Bool = false,
  focused~ : Bool = false,
  captured~ : Bool = false,
  text_control~ : @core.TextControlStateContext? = None,
  dirty~ : @core.ViewDirtyHint = ViewClean,
  messages~ : Array[Msg] = [],
) -> @core.ViewEventResult[Msg] {
  let all_messages = match message {
    Some(message) => [message, ..messages]
    None => messages
  }
  {
    changed,
    activated: !all_messages.is_empty(),
    focused,
    captured,
    state: None,
    text_control,
    dirty,
    messages: all_messages,
  }
}
