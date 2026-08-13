///|
/// Runtime inputs available to a typed semantics-action handler.
///
/// The context contains only the reconciled node's transient UI state and
/// resolved declaration environment. Application model mutation still occurs
/// through the returned typed messages and the program's TEA `update`.
pub(all) struct ViewSemanticsActionContext {
  frame : Rect
  child_frames : Array[Rect]
  focused : Bool
  state : ViewStateContext
  text_control : TextControlStateContext
  text_system : TextSystem
  environment : Environment
  style : ViewStyle
}

///|
/// Result of invoking one typed semantic action adapter.
pub(all) struct ViewSemanticsActionResult[Msg] {
  accepted : Bool
  state : ViewStateContext?
  text_control : TextControlStateContext?
  dirty : ViewDirtyHint
  messages : Array[Msg]
  deferred_commits : Array[() -> Unit]
}

///|
/// One capability-paired semantic action adapter.
///
/// Public constructors pair each capability with a payload-correct callback;
/// callers cannot advertise `SetText` or `Scroll` without handling its typed
/// payload.
pub struct ViewSemanticsActionHandler[Msg] {
  kind : SemanticsActionKind
  handle : (ViewSemanticsActionContext, SemanticsAction) -> ViewSemanticsActionResult[
    Msg,
  ]
}

///|
pub fn[Msg] ViewSemanticsActionResult::accepted(
  state? : ViewStateContext? = None,
  text_control? : TextControlStateContext? = None,
  dirty? : ViewDirtyHint = ViewDirtyHint::ViewPaintDirty,
  messages? : Array[Msg] = [],
  commit? : (() -> Unit)? = None,
) -> ViewSemanticsActionResult[Msg] {
  {
    accepted: true,
    state,
    text_control,
    dirty,
    messages,
    deferred_commits: match commit {
      Some(run) => [run]
      None => []
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionResult::message(
  message : Msg,
) -> ViewSemanticsActionResult[Msg] {
  ViewSemanticsActionResult::accepted(messages=[message])
}

///|
pub fn[Msg] ViewSemanticsActionResult::rejected() -> ViewSemanticsActionResult[
  Msg,
] {
  {
    accepted: false,
    state: None,
    text_control: None,
    dirty: ViewDirtyHint::ViewClean,
    messages: [],
    deferred_commits: [],
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::activate(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Activate,
    handle: (context, action) => {
      match action {
        SemanticsAction::Activate => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::set_text(
  handle : (ViewSemanticsActionContext, String) -> ViewSemanticsActionResult[
    Msg,
  ],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::SetText,
    handle: (context, action) => {
      match action {
        SemanticsAction::SetText(value) => handle(context, value)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::submit(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Submit,
    handle: (context, action) => {
      match action {
        SemanticsAction::Submit => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::scroll(
  handle : (ViewSemanticsActionContext, SemanticsScrollDirection) -> ViewSemanticsActionResult[
    Msg,
  ],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Scroll,
    handle: (context, action) => {
      match action {
        SemanticsAction::Scroll(direction) => handle(context, direction)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::select(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Select,
    handle: (context, action) => {
      match action {
        SemanticsAction::Select => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::expand(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Expand,
    handle: (context, action) => {
      match action {
        SemanticsAction::Expand => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::collapse(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Collapse,
    handle: (context, action) => {
      match action {
        SemanticsAction::Collapse => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::dismiss(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Dismiss,
    handle: (context, action) => {
      match action {
        SemanticsAction::Dismiss => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::increment(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Increment,
    handle: (context, action) => {
      match action {
        SemanticsAction::Increment => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::decrement(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::Decrement,
    handle: (context, action) => {
      match action {
        SemanticsAction::Decrement => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::set_numeric_value(
  handle : (ViewSemanticsActionContext, Double) -> ViewSemanticsActionResult[
    Msg,
  ],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::SetNumericValue,
    handle: (context, action) => {
      match action {
        SemanticsAction::SetNumericValue(value) => handle(context, value)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::set_selection(
  handle : (ViewSemanticsActionContext, TextRange) -> ViewSemanticsActionResult[
    Msg,
  ],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::SetSelection,
    handle: (context, action) => {
      match action {
        SemanticsAction::SetSelection(selection) => handle(context, selection)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::show_menu(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: SemanticsActionKind::ShowMenu,
    handle: (context, action) => {
      match action {
        SemanticsAction::ShowMenu => handle(context)
        _ => ViewSemanticsActionResult::rejected()
      }
    },
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::kind(
  self : ViewSemanticsActionHandler[Msg],
) -> SemanticsActionKind {
  self.kind
}

///|
fn[Msg] ViewSemanticsActionHandler::dispatch(
  self : ViewSemanticsActionHandler[Msg],
  context : ViewSemanticsActionContext,
  action : SemanticsAction,
) -> ViewSemanticsActionResult[Msg] {
  (self.handle)(context, action)
}

///|
fn[Msg, NextMsg] ViewSemanticsActionHandler::map(
  self : ViewSemanticsActionHandler[Msg],
  map : (Msg) -> NextMsg,
) -> ViewSemanticsActionHandler[NextMsg] {
  {
    kind: self.kind,
    handle: (context, action) => {
      let result = self.dispatch(context, action)
      {
        accepted: result.accepted,
        state: result.state,
        text_control: result.text_control,
        dirty: result.dirty,
        messages: result.messages.map(map),
        deferred_commits: result.deferred_commits,
      }
    },
  }
}
