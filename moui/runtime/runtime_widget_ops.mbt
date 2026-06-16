///|
fn RuntimeWidget::identity_key(self : RuntimeWidget) -> Key? {
  match self.identity.key {
    Some(key) => Some(Key::new(key.value()))
    None => None
  }
}

///|
fn RuntimeWidget::kind(self : RuntimeWidget) -> Int {
  stable_widget_kind(self.identity.kind)
}

///|
fn RuntimeWidget::inspector_kind_label(self : RuntimeWidget) -> String {
  self.identity.kind
}

///|
fn RuntimeWidget::inspector_is_control(self : RuntimeWidget) -> Bool {
  (self.focusable)()
}

///|
fn RuntimeWidget::same_identity(
  self : RuntimeWidget,
  next : RuntimeWidget,
) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn RuntimeWidget::is_building_widget(self : RuntimeWidget) -> Bool {
  self.build_child is Some(_)
}

///|
fn RuntimeWidget::reconcile_dirty_kind(
  self : RuntimeWidget,
  next : RuntimeWidget,
) -> ReconcileDirtyKind {
  if self.revision != "" && self.revision == next.revision {
    ReconcileClean
  } else {
    ReconcileLayout
  }
}

///|
fn empty_runtime_widget() -> RuntimeWidget {
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
