///|
fn Widget::identity_key(self : Widget) -> Key? {
  match self.identity.key {
    Some(key) => Some(Key::new(key.value()))
    None => None
  }
}

///|
fn Widget::kind(self : Widget) -> Int {
  stable_widget_kind(self.identity.kind)
}

///|
fn Widget::inspector_kind_label(self : Widget) -> String {
  self.identity.kind
}

///|
fn Widget::inspector_is_control(self : Widget) -> Bool {
  (self.focusable)()
}

///|
fn Widget::same_identity(self : Widget, next : Widget) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn Widget::is_building_widget(self : Widget) -> Bool {
  self.build_child is Some(_)
}

///|
fn Widget::reconcile_dirty_kind(
  self : Widget,
  next : Widget,
) -> ReconcileDirtyKind {
  if self.revision != "" && self.revision == next.revision {
    ReconcileClean
  } else {
    ReconcileLayout
  }
}

///|
fn empty_widget() -> Widget {
  {
    identity: @core.WidgetIdentity::new(kind="Empty"),
    revision: "empty",
    children: () => [],
    build_child: None,
    child_constraints: constraints => constraints.loosen(),
    layout: context => {
      @core.WidgetLayoutResult::new(
        size=context.constraints.constrain(Size::new(width=0.0, height=0.0)),
      )
    },
    paint: _context => @core.WidgetPaintPlan::empty(),
    event: _context => @core.WidgetEventResult::ignored(),
    text_input_state: _context => None,
    text_command: (_context, _intent, _paste_text) => {
      @core.WidgetTextCommandResult::ignored()
    },
    semantics: () => @core.WidgetSemanticsInfo::new(),
    focusable: () => false,
    state: widget_state_context_default(),
  }
}

///|
fn stable_widget_kind(kind : String) -> Int {
  let mut hash = 0
  for ch in kind {
    hash = (hash * 31 + ch.to_int()) % 1000000007
  }
  1000 + (if hash < 0 { -hash } else { hash })
}
