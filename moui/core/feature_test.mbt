///|
struct ChildModel {
  count : Int
  label : String
} derive(Eq, Debug)

///|
enum ChildMsg {
  Inc
  SetLabel(String)
  Ping
} derive(Eq, Debug)

///|
struct ParentModel {
  title : String
  child : ChildModel
} derive(Eq, Debug)

///|
enum ParentMsg {
  Child(ChildMsg)
  Other(String)
} derive(Eq, Debug)

///|
fn child_read(parent : ParentModel) -> ChildModel {
  parent.child
}

///|
fn child_write(child : ChildModel, parent : ParentModel) -> ParentModel {
  { ..parent, child, }
}

///|
fn child_message(message : ChildMsg) -> ParentMsg {
  ParentMsg::Child(message)
}

///|
struct FeatureTestNode {
  message : String
}

///|
impl @core.ViewNode for FeatureTestNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="feature-test")
}

///|
impl @core.ViewNode for FeatureTestNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=4.0, height=4.0),
    ),
  )
}

///|
fn feature_test_view(message : String) -> @core.View[ChildMsg] {
  @core.View::from_node(
    FeatureTestNode::{ message, },
    event=(node, _context) =>
      @core.ViewEventResult::message(ChildMsg::SetLabel(node.message)),
  )
}

///|
fn child_feature() -> @core.Feature[ChildModel, ChildMsg] {
  @core.Feature::new(
    init=() => (
      { count: 0, label: "init", },
      @core.Effect::send(ChildMsg::Ping),
    ),
    update=(model, message) =>
      match message {
        Inc => (
          { ..model, count: model.count + 1, },
          @core.Effect::none(),
        )
        SetLabel(label) => (
          { ..model, label, },
          @core.Effect::send(ChildMsg::Ping),
        )
        Ping => (model, @core.Effect::none())
      },
    view=model => feature_test_view(model.label),
    subscriptions=model =>
      @core.Subscription::timer(
        key="child/tick",
        start=dispatch => {
          dispatch(ChildMsg::Inc)
          None
        },
        label=model.label,
      ),
  )
}

///|
fn title_feature() -> @core.Feature[String, String] {
  @core.Feature::new(
    init=() => ("", @core.Effect::none()),
    update=(_model, message) => (message, @core.Effect::none()),
    view=message => {
      let _ = message
      @core.View::from_node(
        FeatureTestNode::{ message: "title", },
        event=(_node, _context) => @core.ViewEventResult::ignored(),
      )
    },
  )
}

///|
fn child_scope() -> @core.ScopedFeature[
  ParentModel,
  ChildModel,
  ChildMsg,
  ParentMsg,
] {
  child_feature().scope(
    read=child_read,
    write=child_write,
    wrap=child_message,
  )
}

///|
fn sample_parent() -> ParentModel {
  { title: "shell", child: { count: 1, label: "before", }, }
}

///|
fn[Msg] collected(effect : @core.Effect[Msg]) -> Array[Msg] {
  let out : Array[Msg] = []
  effect.runtime_visit(
    message => out.push(message),
    _dispatch_effect => (),
    (_, _) => (),
    (_, _) => (),
  )
  out
}

///|
fn test_env() -> @core.ViewEnvironment {
  @core.ViewEnvironment::new(
    viewport_size=@core.Size::new(width=100.0, height=100.0),
    environment=@core.Environment::neutral(),
  )
}

///|
fn feature_test_event_context() -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
    child_frames: [],
    event: @core.AppEvent::CloseRequested,
    focused: false,
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
test "ScopedFeature update honors lens laws over the parent model" {
  let scoped = child_scope()
  let parent = sample_parent()
  // GetSet: the child written through the lens is exactly what read returns.
  let (after_label, _) = scoped.update(parent, ChildMsg::SetLabel("after"))
  assert_eq(child_read(after_label).label, "after")
  // SetGet: parent fields outside the lens are untouched.
  assert_eq(after_label.title, "shell")
  assert_eq(child_read(after_label).count, 1)
  // SetSet: a later write supersedes an earlier one.
  let (after_second, _) = scoped.update(
    after_label,
    ChildMsg::SetLabel("second"),
  )
  assert_eq(child_read(after_second).label, "second")
  // No-op update writes the same child back: write(read(p), p) == p.
  let (after_ping, _) = scoped.update(after_second, ChildMsg::Ping)
  assert_eq(after_ping, after_second)
}

///|
fn hand_written(
  parent : ParentModel,
  message : ChildMsg,
) -> (ParentModel, @core.Effect[ParentMsg]) {
  let (child, effect) = child_feature().runtime_update(parent.child, message)
  ({ ..parent, child, }, effect.map(child_message))
}

///|
test "ScopedFeature matches hand-written wrapper delegation" {
  let scoped = child_scope()
  let messages : Array[ChildMsg] = [
    ChildMsg::SetLabel("x"),
    ChildMsg::Inc,
    ChildMsg::Ping,
  ]
  let mut scoped_model = sample_parent()
  let mut hand_model = sample_parent()
  for message in messages {
    let (scoped_next, scoped_effect) = scoped.update(scoped_model, message)
    let (hand_next, hand_effect) = hand_written(hand_model, message)
    assert_eq(scoped_next, hand_next)
    assert_eq(collected(scoped_effect), collected(hand_effect))
    scoped_model = scoped_next
    hand_model = hand_next
  }
  assert_eq(scoped_model, hand_model)
  // The SetLabel effect lifts through the wrapper: child Ping arrives wrapped.
  let (_, effect) = scoped.update(scoped_model, ChildMsg::SetLabel("lit"))
  assert_eq(collected(effect), [ParentMsg::Child(ChildMsg::Ping)])
}

///|
test "ScopedFeature::init lifts the startup effect to the parent type" {
  let scoped = child_scope()
  let (child, effect) = scoped.init()
  assert_eq(child, { count: 0, label: "init", })
  assert_eq(collected(effect), [ParentMsg::Child(ChildMsg::Ping)])
}

///|
test "Two scoped features do not clobber each other" {
  let child = child_scope()
  let title = title_feature().scope(
    read=(parent : ParentModel) => parent.title,
    write=(value, parent : ParentModel) => { ..parent, title: value, },
    wrap=message => ParentMsg::Other(message),
  )
  let parent = sample_parent()
  let (child_next, _) = child.update(parent, ChildMsg::SetLabel("only-child"))
  assert_eq(child_next.title, "shell")
  let (title_next, _) = title.update(parent, "only-title")
  assert_eq(child_read(title_next), child_read(parent))
}

///|
test "ScopedFeature::view lifts child messages through the wrapper" {
  let scoped = child_scope()
  let parent = sample_parent()
  let view = scoped.view(parent, test_env())
  assert_eq(view.identity().kind, "feature-test")
  // The child view emits its label back as SetLabel; the wrapper must retype it.
  let result = view.event(feature_test_event_context())
  assert_eq(
    result.messages,
    [ParentMsg::Child(ChildMsg::SetLabel("before"))],
  )
}

///|
test "ScopedFeature::subscriptions lifts source messages" {
  let scoped = child_scope()
  let parent = sample_parent()
  let subscription = scoped.subscriptions(parent)
  let descriptors = subscription.descriptors()
  assert_eq(descriptors.length(), 1)
  assert_eq(descriptors[0].key(), "child/tick")
  let sources = subscription.runtime_sources()
  assert_eq(sources.length(), 1)
  let out : Array[ParentMsg] = []
  let _stop = sources[0].start(message => out.push(message))
  assert_eq(out, [ParentMsg::Child(ChildMsg::Inc)])
}

///|
test "ScopedFeature::commands lifts command messages" {
  let feature = child_feature().with_commands(commands=model => {
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Ping child",
        ),
        message=ChildMsg::SetLabel("from-command-\{model.count}"),
      ),
    ]
  })
  let scoped = feature.scope(
    read=child_read,
    write=child_write,
    wrap=child_message,
  )
  let parent = sample_parent()
  let commands = scoped.commands(parent)
  assert_eq(commands.length(), 1)
  assert_eq(
    commands[0].message(),
    ParentMsg::Child(ChildMsg::SetLabel("from-command-1")),
  )
}

///|
test "Program::from_feature preserves init update view subscriptions commands" {
  let feature = child_feature().with_commands(commands=_model => {
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Submit,
          label="Save",
        ),
        message=ChildMsg::Ping,
      ),
    ]
  })
  let program = @core.Program::from_feature(feature=feature)
  let (program_model, program_effect) = program.runtime_init()
  let (feature_model, feature_effect) = feature.runtime_init()
  assert_eq(program_model, feature_model)
  assert_eq(collected(program_effect), collected(feature_effect))
  let (p1, e1) = program.runtime_update(program_model, ChildMsg::Inc)
  let (f1, f_effect) = feature.runtime_update(feature_model, ChildMsg::Inc)
  assert_eq(p1, f1)
  assert_eq(collected(e1), collected(f_effect))
  assert_eq(
    program.runtime_view(p1, test_env()).identity() ==
      feature.runtime_view(f1, test_env()).identity(),
    true,
  )
  assert_eq(
    program.runtime_subscriptions(p1).descriptors().map(d => d.key()),
    feature.runtime_subscriptions(f1).descriptors().map(d => d.key()),
  )
  assert_eq(
    program.runtime_commands(p1).map(c => c.message()),
    feature.runtime_commands(f1).map(c => c.message()),
  )
}
