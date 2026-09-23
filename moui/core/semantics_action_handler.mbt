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
  dirty? : ViewDirtyHint = ViewPaintDirty,
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
    dirty: ViewClean,
    messages: [],
    deferred_commits: [],
  }
}

///|
pub fn[Msg] ViewSemanticsActionHandler::activate(
  handle : (ViewSemanticsActionContext) -> ViewSemanticsActionResult[Msg],
) -> ViewSemanticsActionHandler[Msg] {
  {
    kind: Activate,
    handle: (context, action) => {
      match action {
        Activate => handle(context)
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
    kind: SetText,
    handle: (context, action) => {
      match action {
        SetText(value) => handle(context, value)
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
    kind: Submit,
    handle: (context, action) => {
      match action {
        Submit => handle(context)
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
    kind: Scroll,
    handle: (context, action) => {
      match action {
        Scroll(direction) => handle(context, direction)
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
    kind: Select,
    handle: (context, action) => {
      match action {
        Select => handle(context)
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
    kind: Expand,
    handle: (context, action) => {
      match action {
        Expand => handle(context)
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
    kind: Collapse,
    handle: (context, action) => {
      match action {
        Collapse => handle(context)
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
    kind: Dismiss,
    handle: (context, action) => {
      match action {
        Dismiss => handle(context)
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
    kind: Increment,
    handle: (context, action) => {
      match action {
        Increment => handle(context)
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
    kind: Decrement,
    handle: (context, action) => {
      match action {
        Decrement => handle(context)
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
    kind: SetNumericValue,
    handle: (context, action) => {
      match action {
        SetNumericValue(value) => handle(context, value)
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
    kind: SetSelection,
    handle: (context, action) => {
      match action {
        SetSelection(selection) => handle(context, selection)
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
    kind: ShowMenu,
    handle: (context, action) => {
      match action {
        ShowMenu => handle(context)
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
