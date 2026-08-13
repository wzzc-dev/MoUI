///|
priv enum RuntimeSemanticActionMessage {
  ActionActivated
  ActionSetText(String)
  ActionSubmitted
  ActionScrolled(String)
  ActionSelected
  ActionExpanded
  ActionCollapsed
  ActionDismissed
}

///|
priv struct RuntimeSemanticActionModel {
  activations : Int
  value : String
  selected : Bool
  expanded : Bool
  dismissed : Bool
}

///|
priv enum RuntimeSemanticBatchMessage {
  BatchFirst
  BatchSecond
  BatchEffect
}

///|
priv enum RuntimeModalFocusMessage {
  OpenModal
  CloseModal
  RemoveOriginAndClose
}

///|
priv struct RuntimeModalFocusModel {
  modal_open : Bool
  origin_present : Bool
}

///|
fn runtime_modal_focus_program() -> @core.Program[
  RuntimeModalFocusModel,
  RuntimeModalFocusMessage,
] {
  let origin_id = runtime_test_semantic_id("modal.origin")
  let outside_id = runtime_test_semantic_id("modal.outside")
  let dialog_id = runtime_test_semantic_id("modal.dialog")
  let first_id = runtime_test_semantic_id("modal.first")
  let second_id = runtime_test_semantic_id("modal.second")
  @core.Program::simple(
    init={ modal_open: false, origin_present: true },
    update=(model, message) => {
      match message {
        OpenModal => { ..model, modal_open: true }
        CloseModal => { ..model, modal_open: false }
        RemoveOriginAndClose => { modal_open: false, origin_present: false }
      }
    },
    view=model => {
      let children : Array[@core.View[RuntimeModalFocusMessage]] = []
      if model.origin_present {
        children.push(
          runtime_semantic_test_view(
            semantic_id=origin_id,
            label="Open dialog",
            focusable=true,
            handlers=[
              @core.ViewSemanticsActionHandler::activate(_context => {
                @core.ViewSemanticsActionResult::message(OpenModal)
              }),
            ],
          ).key("modal.origin.key"),
        )
      }
      children.push(
        runtime_semantic_test_view(
          semantic_id=outside_id,
          label="Outside",
          focusable=true,
        ).key("modal.outside.key"),
      )
      if model.modal_open {
        let dialog = runtime_semantic_container(
            [
              runtime_semantic_test_view(
                semantic_id=first_id,
                label="Close dialog",
                focusable=true,
                handlers=[
                  @core.ViewSemanticsActionHandler::activate(_context => {
                    @core.ViewSemanticsActionResult::message(CloseModal)
                  }),
                ],
              ).key("modal.first.key"),
              runtime_semantic_test_view(
                semantic_id=second_id,
                label="Remove origin and close",
                focusable=true,
                handlers=[
                  @core.ViewSemanticsActionHandler::activate(_context => {
                    @core.ViewSemanticsActionResult::message(
                      RemoveOriginAndClose,
                    )
                  }),
                ],
              ).key("modal.second.key"),
            ],
            kind="RuntimeModalDialog",
            composition=@core.SemanticsComposition::Boundary,
            semantic_id=dialog_id,
            focus_trap=true,
          )
          .semantics_role(@core.SemanticsRole::Dialog)
          .semantics_state(modal=true)
        children.push(dialog)
      }
      runtime_semantic_container(children, kind="RuntimeModalRoot")
    },
  )
}

///|
fn runtime_semantic_batch_program(
  semantic_id : @core.SemanticId,
) -> @core.Program[Array[String], RuntimeSemanticBatchMessage] {
  @core.Program::new(
    init=() => ([], @core.Effect::none()),
    update=(model, message) => {
      let next = model.copy()
      let (label, effect) = match message {
        BatchFirst => ("first", @core.Effect::send(BatchEffect))
        BatchSecond => ("second", @core.Effect::none())
        BatchEffect => ("effect", @core.Effect::none())
      }
      next.push(label)
      (next, effect)
    },
    view=model => {
      runtime_semantic_test_view(
        semantic_id~,
        label="batch",
        value=model.join(","),
        handlers=[
          @core.ViewSemanticsActionHandler::activate(_context => {
            @core.ViewSemanticsActionResult::accepted(
              dirty=@core.ViewDirtyHint::ViewClean,
              messages=[BatchFirst, BatchSecond],
            )
          }),
        ],
      )
    },
  )
}

///|
fn runtime_semantic_scroll_label(
  direction : @core.SemanticsScrollDirection,
) -> String {
  match direction {
    @core.SemanticsScrollDirection::Forward => "forward"
    @core.SemanticsScrollDirection::Backward => "backward"
    @core.SemanticsScrollDirection::Up => "up"
    @core.SemanticsScrollDirection::Down => "down"
    @core.SemanticsScrollDirection::Left => "left"
    @core.SemanticsScrollDirection::Right => "right"
  }
}

///|
fn runtime_semantic_action_handlers() -> Array[
  @core.ViewSemanticsActionHandler[RuntimeSemanticActionMessage],
] {
  [
    @core.ViewSemanticsActionHandler::activate(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionActivated],
      )
    }),
    @core.ViewSemanticsActionHandler::set_text((_context, value) => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionSetText(value)],
      )
    }),
    @core.ViewSemanticsActionHandler::submit(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionSubmitted],
      )
    }),
    @core.ViewSemanticsActionHandler::scroll((_context, direction) => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionScrolled(runtime_semantic_scroll_label(direction))],
      )
    }),
    @core.ViewSemanticsActionHandler::select(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionSelected],
      )
    }),
    @core.ViewSemanticsActionHandler::expand(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionExpanded],
      )
    }),
    @core.ViewSemanticsActionHandler::collapse(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionCollapsed],
      )
    }),
    @core.ViewSemanticsActionHandler::dismiss(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[ActionDismissed],
      )
    }),
  ]
}

///|
fn runtime_semantic_action_program(
  semantic_id : @core.SemanticId,
) -> @core.Program[RuntimeSemanticActionModel, RuntimeSemanticActionMessage] {
  @core.Program::simple(
    init={
      activations: 0,
      value: "initial",
      selected: false,
      expanded: false,
      dismissed: false,
    },
    update=(model, message) => {
      match message {
        ActionActivated => { ..model, activations: model.activations + 1 }
        ActionSetText(value) => { ..model, value, }
        ActionSubmitted => { ..model, value: "\{model.value}:submitted" }
        ActionScrolled(direction) => { ..model, value: "scroll:\{direction}" }
        ActionSelected => { ..model, selected: true }
        ActionExpanded => { ..model, expanded: true }
        ActionCollapsed => { ..model, expanded: false }
        ActionDismissed => { ..model, dismissed: true }
      }
    },
    view=model => {
      runtime_semantic_test_view(
        semantic_id~,
        label="activations:\{model.activations}",
        value=model.value,
        description=if model.dismissed { "dismissed" } else { "" },
        selected=model.selected,
        expanded=model.expanded,
        focusable=true,
        handlers=runtime_semantic_action_handlers(),
      )
    },
  )
}

///|
test "runtime semantics: typed actions commit through TEA without fake input" {
  let semantic_id = runtime_test_semantic_id("test.actions")
  let observed_events : Array[@core.AppEvent] = []
  let runtime = AppRuntime::new_program(
    program=runtime_semantic_action_program(semantic_id),
    size=@core.Size::new(width=200.0, height=80.0),
  )
  runtime.set_event_observer(event => observed_events.push(event))
  let initial = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(initial, semantic_id) is Some(initial_node) else {
    fail("missing initial semantic action node")
  }
  let initial_node_id = initial_node.node_id
  let initial_generation = initial.generation()
  let initial_runtime = runtime.inspector_snapshot().runtime()
  let mut generation = initial_generation
  let focus_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::ByNodeId(initial_node_id),
    @core.SemanticsAction::Focus,
    generation,
  )
  generation = focus_receipt.after
  let activate_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Activate,
    generation,
  )
  generation = activate_receipt.after
  let set_text_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::SetText("typed"),
    generation,
  )
  generation = set_text_receipt.after
  let scroll_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Scroll(@core.SemanticsScrollDirection::Down),
    generation,
  )
  generation = scroll_receipt.after
  let select_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Select,
    generation,
  )
  generation = select_receipt.after
  let expand_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Expand,
    generation,
  )
  generation = expand_receipt.after
  let collapse_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Collapse,
    generation,
  )
  generation = collapse_receipt.after
  let submit_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Submit,
    generation,
  )
  generation = submit_receipt.after
  let before_dismiss = generation
  let dismiss_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Dismiss,
    generation,
  )
  generation = dismiss_receipt.after
  let final_snapshot = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(final_snapshot, semantic_id) is Some(node) else {
    fail("missing final semantic action node")
  }
  assert_eq(node.node_id, initial_node_id)
  assert_true(node.state.focused)
  assert_true(node.state.selected)
  assert_false(node.state.expanded)
  assert_eq(node.label, "activations:1")
  assert_eq(node.value, "scroll:down:submitted")
  assert_eq(node.description, "dismissed")
  assert_eq(final_snapshot.generation(), generation)
  assert_true(generation > initial_generation)
  assert_true(observed_events.is_empty())
  let final_runtime = runtime.inspector_snapshot().runtime()
  assert_eq(
    final_runtime.layout_pass_count(),
    initial_runtime.layout_pass_count(),
  )
  assert_eq(
    final_runtime.paint_pass_count(),
    initial_runtime.paint_pass_count(),
  )
  match runtime.read_semantics(since=before_dismiss) {
    Ok(SemanticsRead::Delta(delta)) => {
      assert_eq(delta.from(), before_dismiss)
      assert_eq(delta.to(), generation)
      assert_eq(delta.upserted().length(), 1)
      assert_true(delta.removed().is_empty())
    }
    _ => fail("expected a one-node semantic delta")
  }
  match runtime.read_semantics(since=before_dismiss) {
    Ok(SemanticsRead::Delta(delta)) => assert_eq(delta.to(), generation)
    _ => fail("independent consumer should receive the same delta")
  }
  match runtime.read_semantics(since=generation) {
    Ok(SemanticsRead::Unchanged(current)) => assert_eq(current, generation)
    _ => fail("expected unchanged semantics cursor")
  }
  let generation_before_stale = final_snapshot.generation()
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(initial_generation),
    }) {
    Err(SemanticsActionDispatchError::StaleGeneration(expected, actual)) => {
      assert_eq(expected, initial_generation)
      assert_eq(actual, generation_before_stale)
    }
    _ => fail("expected stale generation rejection")
  }
  assert_eq(
    runtime_expect_full_semantics(runtime).generation(),
    generation_before_stale,
  )
}

///|
test "runtime semantics: live changes announce without moving focus" {
  let semantic_id = runtime_test_semantic_id("test.live")
  let runtime = AppRuntime::new_program(
    program=@core.Program::simple(
      init=0,
      update=(value, _message : Unit) => value + 1,
      view=value => {
        runtime_semantic_test_view(
          semantic_id~,
          role=@core.SemanticsRole::Status,
          label="Status \{value}",
          handlers=[
            @core.ViewSemanticsActionHandler::activate(_context => {
              @core.ViewSemanticsActionResult::message(())
            }),
          ],
        ).semantics_live(@core.SemanticsLive::Polite, live_atomic=true)
      },
    ),
    size=@core.Size::new(width=200.0, height=80.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  let receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Activate,
    initial.generation(),
  )
  match runtime.read_semantics(since=initial.generation()) {
    Ok(SemanticsRead::Delta(delta)) => {
      assert_eq(delta.focused(), initial.focused())
      assert_eq(delta.announcements().length(), 1)
      let announcement = delta.announcements()[0]
      assert_eq(announcement.generation, receipt.after)
      assert_eq(announcement.live, @core.SemanticsLive::Polite)
      assert_true(announcement.is_atomic)
      assert_eq(announcement.text, "Status 1")
    }
    _ => fail("expected live-region delta")
  }
}

///|
test "runtime semantics: modal trap isolates tree and restores stable focus" {
  let runtime = AppRuntime::new_program(
    program=runtime_modal_focus_program(),
    size=@core.Size::new(width=240.0, height=160.0),
  )
  let origin_id = runtime_test_semantic_id("modal.origin")
  let outside_id = runtime_test_semantic_id("modal.outside")
  let dialog_id = runtime_test_semantic_id("modal.dialog")
  let first_id = runtime_test_semantic_id("modal.first")
  let second_id = runtime_test_semantic_id("modal.second")
  let initial = runtime_expect_full_semantics(runtime)
  let initial_background_ids = initial.nodes().map(node => node.node_id)
  assert_true(runtime.focus_key("modal.origin.key"))
  let focused_origin = runtime_expect_full_semantics(runtime)
  guard focused_origin.focused() is Some(_) else {
    fail("origin should receive keyboard focus")
  }
  guard runtime_semantic_node_by_id(focused_origin, origin_id) is Some(_) else {
    fail("origin semantic node missing")
  }
  let open_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(origin_id),
    @core.SemanticsAction::Activate,
    focused_origin.generation(),
  )
  guard runtime.read_semantics(since=open_receipt.after)
    is Ok(SemanticsRead::Unchanged(_)) else {
    fail("open action should commit synchronously")
  }
  let modal = runtime_expect_full_semantics(runtime)
  assert_true(modal.generation() > initial.generation())
  match runtime.read_semantics(since=focused_origin.generation()) {
    Ok(SemanticsRead::Delta(delta)) =>
      for node_id in initial_background_ids {
        assert_true(delta.removed().contains(node_id))
      }
    _ => fail("opening modal should remove every background semantic node")
  }
  assert_true(runtime_semantic_node_by_id(modal, dialog_id) is Some(_))
  assert_true(runtime_semantic_node_by_id(modal, first_id) is Some(_))
  assert_true(runtime_semantic_node_by_id(modal, second_id) is Some(_))
  assert_true(runtime_semantic_node_by_id(modal, origin_id) is None)
  assert_true(runtime_semantic_node_by_id(modal, outside_id) is None)
  guard modal.focused() is Some(first_node) else {
    fail("modal should focus its first descendant")
  }
  guard runtime_semantic_node_by_id(modal, first_id) is Some(node) else {
    fail("modal first node missing")
  }
  assert_eq(first_node, node.node_id)
  assert_true(runtime.focus_next())
  let second_focused = runtime_expect_full_semantics(runtime)
  guard second_focused.focused() is Some(_) else {
    fail("Tab should move within the trap")
  }
  guard runtime_semantic_node_by_id(second_focused, second_id) is Some(node) else {
    fail("modal second node missing")
  }
  assert_eq(second_focused.focused(), Some(node.node_id))
  assert_true(runtime.focus_next())
  assert_eq(runtime_expect_full_semantics(runtime).focused(), Some(first_node))
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(outside_id),
      action: @core.SemanticsAction::Focus,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::TargetNotFound(_)) => ()
    _ => fail("outside semantic focus must be isolated while modal is open")
  }
  let close_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(first_id),
    @core.SemanticsAction::Activate,
    runtime_expect_full_semantics(runtime).generation(),
  )
  let restored = runtime_expect_full_semantics(runtime)
  assert_true(restored.generation() >= close_receipt.after)
  match runtime.read_semantics(since=second_focused.generation()) {
    Ok(SemanticsRead::Delta(delta)) =>
      for node_id in initial_background_ids {
        assert_true(delta.upserted().any(node => node.node_id == node_id))
      }
    _ =>
      fail("closing modal should restore every live background semantic node")
  }
  for node_id in initial_background_ids {
    assert_true(restored.nodes().any(node => node.node_id == node_id))
  }
  guard restored.focused() is Some(restored_node) else {
    fail("closing modal should restore focus")
  }
  guard runtime_semantic_node_by_id(restored, origin_id) is Some(origin_node) else {
    fail("origin should return after modal close")
  }
  assert_eq(restored_node, origin_node.node_id)
}

///|
test "runtime semantics: modal restore falls back when original target is gone" {
  let runtime = AppRuntime::new_program(
    program=runtime_modal_focus_program(),
    size=@core.Size::new(width=240.0, height=160.0),
  )
  let origin_id = runtime_test_semantic_id("modal.origin")
  let second_id = runtime_test_semantic_id("modal.second")
  assert_true(runtime.focus_key("modal.origin.key"))
  let opened = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(origin_id),
    @core.SemanticsAction::Activate,
    runtime_expect_full_semantics(runtime).generation(),
  )
  let modal = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(modal, second_id) is Some(second) else {
    fail("modal second node missing")
  }
  ignore(
    runtime_expect_semantics_action(
      runtime,
      @core.SemanticsTarget::ByNodeId(second.node_id),
      @core.SemanticsAction::Focus,
      opened.after,
    ),
  )
  let changed = runtime_expect_full_semantics(runtime)
  ignore(
    runtime_expect_semantics_action(
      runtime,
      @core.SemanticsTarget::BySemanticId(second_id),
      @core.SemanticsAction::Activate,
      changed.generation(),
    ),
  )
  let restored = runtime_expect_full_semantics(runtime)
  guard restored.focused() is Some(focused) else {
    fail("fallback focus should remain available")
  }
  assert_true(runtime_semantic_node_by_id(restored, origin_id) is None)
  assert_eq(restored.nodes().length(), 1)
  assert_eq(restored.focused(), Some(focused))
}

///|
test "runtime semantics: action message batch preserves FIFO before effects" {
  let semantic_id = runtime_test_semantic_id("test.batch")
  let runtime = AppRuntime::new_program(
    program=runtime_semantic_batch_program(semantic_id),
    size=@core.Size::new(width=160.0, height=60.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  ignore(
    runtime_expect_semantics_action(
      runtime,
      @core.SemanticsTarget::BySemanticId(semantic_id),
      @core.SemanticsAction::Activate,
      initial.generation(),
    ),
  )
  let final_snapshot = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(final_snapshot, semantic_id) is Some(node) else {
    fail("missing batch action node")
  }
  assert_eq(node.value, "first,second,effect")
}

///|
test "runtime semantics: rejection paths preserve committed state" {
  let unavailable_id = runtime_test_semantic_id("test.unavailable")
  let disabled_id = runtime_test_semantic_id("test.disabled")
  let rejected_id = runtime_test_semantic_id("test.rejected")
  let received : Array[String] = []
  let views : Array[@core.View[String]] = [
    runtime_semantic_test_view(semantic_id=unavailable_id, label="unavailable"),
    runtime_semantic_test_view(
      semantic_id=disabled_id,
      label="disabled",
      disabled=true,
      handlers=[
        @core.ViewSemanticsActionHandler::activate(_context => {
          @core.ViewSemanticsActionResult::accepted(messages=["disabled"])
        }),
      ],
    ),
    runtime_semantic_test_view(semantic_id=rejected_id, label="rejected", handlers=[
      @core.ViewSemanticsActionHandler::activate(_context => {
        @core.ViewSemanticsActionResult::rejected()
      }),
    ]),
  ]
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_container(views),
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(message => received.push(message)),
  )
  let before = runtime_expect_full_semantics(runtime)
  let generation = before.generation()
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(unavailable_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::ActionUnavailable(target, kind)) => {
      assert_eq(target, @core.SemanticsTarget::BySemanticId(unavailable_id))
      assert_eq(kind, @core.SemanticsActionKind::Activate)
    }
    _ => fail("expected unavailable action rejection")
  }
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(disabled_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::TargetDisabled(target)) =>
      assert_eq(target, @core.SemanticsTarget::BySemanticId(disabled_id))
    _ => fail("expected disabled target rejection")
  }
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(rejected_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::HandlerRejected(target, kind)) => {
      assert_eq(target, @core.SemanticsTarget::BySemanticId(rejected_id))
      assert_eq(kind, @core.SemanticsActionKind::Activate)
    }
    _ => fail("expected handler rejection")
  }
  let missing = runtime_test_semantic_id("test.missing")
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(missing),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::TargetNotFound(target)) =>
      assert_eq(target, @core.SemanticsTarget::BySemanticId(missing))
    _ => fail("expected missing target rejection")
  }
  let after = runtime_expect_full_semantics(runtime)
  assert_eq(after.generation(), generation)
  assert_eq(after.focused(), None)
  assert_true(received.is_empty())
}

///|
test "runtime semantics: duplicate ids are committed but never dispatched" {
  let duplicate_id = runtime_test_semantic_id("test.duplicate")
  let received : Array[String] = []
  let child = (label : String) => {
    runtime_semantic_test_view(semantic_id=duplicate_id, label~, handlers=[
      @core.ViewSemanticsActionHandler::activate(_context => {
        @core.ViewSemanticsActionResult::accepted(messages=[label])
      }),
    ])
  }
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_container([child("first"), child("second")]),
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(message => received.push(message)),
  )
  let snapshot = runtime_expect_full_semantics(runtime)
  assert_eq(snapshot.issues().length(), 1)
  match snapshot.issues()[0] {
    SemanticsIssue::DuplicateSemanticId(id, nodes) => {
      assert_eq(id, duplicate_id)
      assert_eq(nodes.length(), 2)
    }
    _ => fail("expected duplicate semantic ID issue")
  }
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(duplicate_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(
        snapshot.generation(),
      ),
    }) {
    Err(SemanticsActionDispatchError::TargetAmbiguous(id)) =>
      assert_eq(id, duplicate_id)
    _ => fail("expected ambiguous target rejection")
  }
  assert_true(received.is_empty())
  assert_eq(
    runtime_expect_full_semantics(runtime).generation(),
    snapshot.generation(),
  )
}

///|
test "runtime semantics: explicit composition has no first-child inheritance" {
  let first_id = runtime_test_semantic_id("test.first")
  let second_id = runtime_test_semantic_id("test.second")
  let children : Array[@core.View[Unit]] = [
    runtime_semantic_test_view(
      semantic_id=first_id,
      role=@core.SemanticsRole::Button,
      label="first",
    ),
    runtime_semantic_test_view(
      semantic_id=second_id,
      role=@core.SemanticsRole::Text,
      label="second",
    ),
  ]
  let transparent = AppRuntime::new_view(
    root=runtime_semantic_container(children),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let transparent_snapshot = runtime_expect_full_semantics(transparent)
  assert_eq(transparent_snapshot.nodes().length(), 3)
  guard transparent_snapshot.root() is Some(root_id) else {
    fail("missing transparent synthetic root")
  }
  let mut root_node : @core.SemanticsNode? = None
  for node in transparent_snapshot.nodes() {
    if node.node_id == root_id {
      root_node = Some(node)
      break
    }
  }
  guard root_node is Some(root) else { fail("missing root node") }
  assert_eq(root.role, @core.SemanticsRole::Group)
  assert_eq(root.label, "")
  assert_eq(root.children.length(), 2)
  let merged = AppRuntime::new_view(
    root=runtime_semantic_container(
      children,
      composition=@core.SemanticsComposition::MergeDescendants,
    ),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let merged_snapshot = runtime_expect_full_semantics(merged)
  assert_eq(merged_snapshot.nodes().length(), 1)
  assert_eq(merged_snapshot.nodes()[0].role, @core.SemanticsRole::Group)
  assert_eq(merged_snapshot.nodes()[0].label, "first second")
  assert_true(merged_snapshot.nodes()[0].children.is_empty())
  let hidden = AppRuntime::new_view(
    root=runtime_semantic_container(
      children,
      composition=@core.SemanticsComposition::Hidden,
    ),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let hidden_snapshot = runtime_expect_full_semantics(hidden)
  assert_eq(hidden_snapshot.root(), None)
  assert_true(hidden_snapshot.nodes().is_empty())
  let overlay_id = runtime_test_semantic_id("test.overlay")
  let overlay = AppRuntime::new_view(
    root=runtime_semantic_container([children[0]], semantic_id=overlay_id),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let overlay_snapshot = runtime_expect_full_semantics(overlay)
  assert_eq(overlay_snapshot.nodes().length(), 1)
  assert_eq(overlay_snapshot.nodes()[0].semantic_id, Some(overlay_id))
}

///|
priv enum RuntimeSemanticToggleMessage {
  ToggleTarget
}

///|
fn runtime_semantic_toggle_program(
  toggle_id : @core.SemanticId,
  target_id : @core.SemanticId,
) -> @core.Program[Bool, RuntimeSemanticToggleMessage] {
  @core.Program::simple(init=true, update=(visible, _message) => !visible, view=visible => {
    let children : Array[@core.View[RuntimeSemanticToggleMessage]] = [
      runtime_semantic_test_view(
        kind="RuntimeSemanticToggle",
        semantic_id=toggle_id,
        label="toggle",
        handlers=[
          @core.ViewSemanticsActionHandler::activate(_context => {
            @core.ViewSemanticsActionResult::accepted(
              dirty=@core.ViewDirtyHint::ViewClean,
              messages=[ToggleTarget],
            )
          }),
        ],
      ),
    ]
    if visible {
      children.push(
        runtime_semantic_test_view(
          kind="RuntimeSemanticRemountTarget",
          semantic_id=target_id,
          label="target",
        ),
      )
    }
    runtime_semantic_container(children)
  })
}

///|
fn runtime_semantic_visibility_program(
  toggle_id : @core.SemanticId,
  target_id : @core.SemanticId,
) -> @core.Program[Bool, RuntimeSemanticToggleMessage] {
  @core.Program::simple(init=true, update=(visible, _message) => !visible, view=visible => {
    runtime_semantic_container([
      runtime_semantic_test_view(
        kind="RuntimeSemanticVisibilityToggle",
        semantic_id=toggle_id,
        label="toggle visibility",
        handlers=[
          @core.ViewSemanticsActionHandler::activate(_context => {
            @core.ViewSemanticsActionResult::accepted(
              dirty=@core.ViewDirtyHint::ViewClean,
              messages=[ToggleTarget],
            )
          }),
        ],
      ),
      runtime_semantic_container(
        [],
        kind="RuntimeSemanticVisibilityTarget",
        semantic_id=target_id,
        composition=if visible {
          @core.SemanticsComposition::Boundary
        } else {
          @core.SemanticsComposition::Hidden
        },
      ),
    ])
  })
}

///|
test "runtime semantics: node ids survive rebuild and are never reused after removal" {
  let toggle_id = runtime_test_semantic_id("test.toggle")
  let target_id = runtime_test_semantic_id("test.remount")
  let runtime = AppRuntime::new_program(
    program=runtime_semantic_toggle_program(toggle_id, target_id),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(initial, toggle_id) is Some(initial_toggle) else {
    fail("missing initial toggle")
  }
  guard runtime_semantic_node_by_id(initial, target_id) is Some(initial_target) else {
    fail("missing initial target")
  }
  let removed_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(toggle_id),
    @core.SemanticsAction::Activate,
    initial.generation(),
  )
  let removed = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(removed, toggle_id) is Some(retained_toggle) else {
    fail("toggle should remain mounted")
  }
  assert_eq(retained_toggle.node_id, initial_toggle.node_id)
  assert_eq(runtime_semantic_node_by_id(removed, target_id), None)
  let restored_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(toggle_id),
    @core.SemanticsAction::Activate,
    removed_receipt.after,
  )
  let restored = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(restored, target_id)
    is Some(restored_target) else {
    fail("target should be restored")
  }
  assert_true(restored_target.node_id > initial_target.node_id)
  assert_eq(restored.generation(), restored_receipt.after)
}

///|
test "runtime semantics: hidden then restored boundary retains its node id" {
  let toggle_id = runtime_test_semantic_id("test.visibility.toggle")
  let target_id = runtime_test_semantic_id("test.visibility.target")
  let runtime = AppRuntime::new_program(
    program=runtime_semantic_visibility_program(toggle_id, target_id),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(initial, target_id) is Some(initial_target) else {
    fail("missing initial visibility target")
  }
  let hidden_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(toggle_id),
    @core.SemanticsAction::Activate,
    initial.generation(),
  )
  let hidden = runtime_expect_full_semantics(runtime)
  assert_eq(runtime_semantic_node_by_id(hidden, target_id), None)
  let restored_receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(toggle_id),
    @core.SemanticsAction::Activate,
    hidden_receipt.after,
  )
  let restored = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(restored, target_id)
    is Some(restored_target) else {
    fail("visibility target should be restored")
  }
  assert_eq(restored_target.node_id, initial_target.node_id)
  assert_eq(restored.generation(), restored_receipt.after)
}

///|
test "runtime semantics: reentrant and closed runtimes reject without mutation" {
  let semantic_id = runtime_test_semantic_id("test.reentrant")
  let runtime_ref : Ref[AppRuntime?] = Ref(None)
  let nested_error : Ref[SemanticsActionDispatchError?] = Ref(None)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(_context => {
      match runtime_ref.val {
        Some(runtime) =>
          match
            runtime.perform_semantics_action({
              target: @core.SemanticsTarget::BySemanticId(semantic_id),
              action: @core.SemanticsAction::Activate,
              precondition: SemanticsGenerationPrecondition::Latest,
            }) {
            Ok(_) => ()
            Err(error) => nested_error.val = Some(error)
          }
        None => ()
      }
      @core.ViewSemanticsActionResult::rejected()
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(semantic_id~, label="reentrant", handlers=[
      handler,
    ]),
    size=@core.Size::new(width=160.0, height=60.0),
  )
  runtime_ref.val = Some(runtime)
  let before = runtime_expect_full_semantics(runtime)
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(before.generation()),
    }) {
    Err(SemanticsActionDispatchError::HandlerRejected(_, _)) => ()
    _ => fail("expected outer handler rejection")
  }
  assert_eq(
    nested_error.val,
    Some(SemanticsActionDispatchError::ReentrantDispatch),
  )
  assert_eq(
    runtime_expect_full_semantics(runtime).generation(),
    before.generation(),
  )
  runtime.destroy()
  match runtime.read_semantics() {
    Err(SemanticsReadError::RuntimeClosed) => ()
    _ => fail("expected closed semantics read rejection")
  }
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(SemanticsActionDispatchError::RuntimeClosed) => ()
    _ => fail("expected closed action rejection")
  }
}

///|
test "runtime semantics: rejected handler discards a transactional destroy request" {
  let semantic_id = runtime_test_semantic_id("test.transaction.reject-destroy")
  let runtime_ref : Ref[AppRuntime?] = Ref(None)
  let destroy_requested = Ref(false)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(_context => {
      destroy_requested.val = true
      match runtime_ref.val {
        Some(runtime) => runtime.destroy()
        None => ()
      }
      @core.ViewSemanticsActionResult::rejected()
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(
      semantic_id~,
      label="rejected transactional destroy",
      handlers=[handler],
    ),
    size=@core.Size::new(width=160.0, height=60.0),
  )
  runtime_ref.val = Some(runtime)
  let before = runtime_expect_full_semantics(runtime)
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(before.generation()),
    }) {
    Err(SemanticsActionDispatchError::HandlerRejected(_, _)) => ()
    _ => fail("expected rejected action")
  }
  assert_true(destroy_requested.val)
  let after = runtime_expect_full_semantics(runtime)
  assert_eq(after.generation(), before.generation())
  assert_true(runtime_semantic_node_by_id(after, semantic_id) is Some(_))
}

///|
test "runtime semantics: accepted handler defers destroy until after commit" {
  let semantic_id = runtime_test_semantic_id("test.transaction.accept-destroy")
  let runtime_ref : Ref[AppRuntime?] = Ref(None)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(context => {
      match runtime_ref.val {
        Some(runtime) => runtime.destroy()
        None => ()
      }
      @core.ViewSemanticsActionResult::accepted(
        state=Some({ ..context.state, checked: true }),
        dirty=@core.ViewDirtyHint::ViewClean,
      )
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(
      semantic_id~,
      role=@core.SemanticsRole::Checkbox,
      label="accepted transactional destroy",
      handlers=[handler],
    ),
    size=@core.Size::new(width=160.0, height=60.0),
  )
  runtime_ref.val = Some(runtime)
  let before = runtime_expect_full_semantics(runtime)
  let receipt = match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(before.generation()),
    }) {
    Ok(receipt) => receipt
    Err(_) => fail("accepted transactional destroy unexpectedly failed")
  }
  assert_true(receipt.after.value() > receipt.before.value())
  assert_false(receipt.pending_work)
  match runtime.read_semantics() {
    Err(SemanticsReadError::RuntimeClosed) => ()
    _ => fail("accepted transactional destroy must close after commit")
  }
}

///|
test "runtime semantics: reentrant reads observe only the committed snapshot" {
  let semantic_id = runtime_test_semantic_id("test.transaction.read")
  let runtime_ref : Ref[AppRuntime?] = Ref(None)
  let observed_checked = Ref(true)
  let observed_generation : Ref[@core.SemanticsGeneration?] = Ref(None)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(context => {
      @core.ViewSemanticsActionResult::accepted(
        state=Some({ ..context.state, checked: true }),
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[()],
      )
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(
      semantic_id~,
      role=@core.SemanticsRole::Checkbox,
      label="transaction read",
      handlers=[handler],
    ),
    size=@core.Size::new(width=160.0, height=60.0),
    on_message=Some(_message => {
      match runtime_ref.val {
        Some(runtime) =>
          match runtime.read_semantics() {
            Ok(SemanticsRead::Full(snapshot)) => {
              observed_generation.val = Some(snapshot.generation())
              match runtime_semantic_node_by_id(snapshot, semantic_id) {
                Some(node) =>
                  observed_checked.val = node.state.checked ==
                    Some(@core.SemanticsCheckedState::Checked)
                None => ()
              }
            }
            _ => ()
          }
        None => ()
      }
    }),
  )
  runtime_ref.val = Some(runtime)
  let before = runtime_expect_full_semantics(runtime)
  let receipt = runtime_expect_semantics_action(
    runtime,
    @core.SemanticsTarget::BySemanticId(semantic_id),
    @core.SemanticsAction::Activate,
    before.generation(),
  )
  assert_false(observed_checked.val)
  assert_eq(observed_generation.val, Some(before.generation()))
  let after = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(after, semantic_id) is Some(node) else {
    fail("missing transaction read node")
  }
  assert_eq(node.state.checked, Some(@core.SemanticsCheckedState::Checked))
  assert_eq(after.generation(), receipt.after)
}

///|
test "runtime semantics: destruction during delivery still completes the accepted transaction" {
  let semantic_id = runtime_test_semantic_id("test.transaction.destroy")
  let runtime_ref : Ref[AppRuntime?] = Ref(None)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(_context => {
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewClean,
        messages=[()],
      )
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(semantic_id~, label="transaction destroy", handlers=[
      handler,
    ]),
    size=@core.Size::new(width=160.0, height=60.0),
    on_message=Some(_message => {
      match runtime_ref.val {
        Some(runtime) => runtime.destroy()
        None => ()
      }
    }),
  )
  runtime_ref.val = Some(runtime)
  let before = runtime_expect_full_semantics(runtime)
  let receipt = match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(before.generation()),
    }) {
    Ok(receipt) => receipt
    Err(_) => fail("accepted action unexpectedly failed")
  }
  assert_eq(receipt.before, before.generation())
  assert_eq(receipt.after, before.generation())
  assert_false(receipt.pending_work)
  match runtime.read_semantics() {
    Err(SemanticsReadError::RuntimeClosed) => ()
    _ => fail("destroyed runtime should reject semantics reads")
  }
}

///|
test "runtime semantics: rejected proposal never runs deferred commits" {
  let semantic_id = runtime_test_semantic_id("test.transaction.deferred-reject")
  let committed = Ref(false)
  let handler : @core.ViewSemanticsActionHandler[Unit] = @core.ViewSemanticsActionHandler::activate(_context => {
      let rejected : @core.ViewSemanticsActionResult[Unit] = @core.ViewSemanticsActionResult::rejected()
      { ..rejected, deferred_commits: [() => committed.val = true] }
    },
  )
  let runtime = AppRuntime::new_view(
    root=runtime_semantic_test_view(semantic_id~, label="deferred reject", handlers=[
      handler,
    ]),
    size=@core.Size::new(width=160.0, height=60.0),
  )
  let before = runtime_expect_full_semantics(runtime)
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: SemanticsGenerationPrecondition::Exact(before.generation()),
    }) {
    Err(SemanticsActionDispatchError::HandlerRejected(_, _)) => ()
    _ => fail("expected rejected deferred proposal")
  }
  assert_false(committed.val)
  assert_eq(
    runtime_expect_full_semantics(runtime).generation(),
    before.generation(),
  )
}

///|
test "runtime semantics: expired delta cursor falls back to full snapshot" {
  let semantic_id = runtime_test_semantic_id("test.journal")
  let runtime = AppRuntime::new_program(
    program=runtime_semantic_action_program(semantic_id),
    size=@core.Size::new(width=200.0, height=80.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  let mut generation = initial.generation()
  for _ in 0..<66 {
    generation = runtime_expect_semantics_action(
        runtime,
        @core.SemanticsTarget::BySemanticId(semantic_id),
        @core.SemanticsAction::Activate,
        generation,
      ).after
  }
  match runtime.read_semantics(since=initial.generation()) {
    Ok(SemanticsRead::Full(snapshot)) =>
      assert_eq(snapshot.generation(), generation)
    _ => fail("expired cursor should recover with a full snapshot")
  }
}
