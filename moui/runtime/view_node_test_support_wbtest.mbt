///|
priv struct RuntimeWhiteBoxFixtureNode {
  identity : () -> @core.ViewIdentity
  revision : () -> String
  paint_revision : () -> String
  child_constraints : (@core.Constraints) -> @core.Constraints
  child_environment : (@core.Environment) -> @core.Environment
  child_style : (@core.ViewStyle) -> @core.ViewStyle
  layout : (@core.ViewLayoutContext) -> @core.ViewLayoutResult
  paint : (@core.ViewPaintContext) -> @core.ViewPaintPlan
  text_input_state : (@core.ViewPaintContext) -> @core.TextInputState?
  semantics : () -> @core.ViewSemanticsInfo
  focusable : () -> Bool
  flex_weight : () -> Double
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn identity(self) {
  (self.identity)()
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn revision(self) {
  (self.revision)()
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn paint_revision(self) {
  (self.paint_revision)()
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn child_constraints(
  self,
  constraints,
) {
  (self.child_constraints)(constraints)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn child_environment(
  self,
  environment,
) {
  (self.child_environment)(environment)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn child_style(
  self,
  style,
) {
  (self.child_style)(style)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn layout(self, context) {
  (self.layout)(context)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn paint(self, context) {
  (self.paint)(context)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn text_input_state(
  self,
  context,
) {
  (self.text_input_state)(context)
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn semantics(self) {
  (self.semantics)()
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn focusable(self) {
  (self.focusable)()
}

///|
impl @core.ViewNode for RuntimeWhiteBoxFixtureNode with fn flex_weight(self) {
  (self.flex_weight)()
}

///|
fn[Msg] runtime_wb_fixture_view(
  identity~ : () -> @core.ViewIdentity,
  revision? : () -> String = () => "",
  paint_revision? : () -> String = () => "",
  children? : () -> Array[@core.View[Msg]] = () => [],
  build_child? : ((@core.ComponentContext) -> @core.View[Msg])? = None,
  child_constraints? : (@core.Constraints) -> @core.Constraints = constraints => {
    constraints.loosen()
  },
  child_environment? : (@core.Environment) -> @core.Environment = environment => {
    let captured_environment = environment
    captured_environment
  },
  child_style? : (@core.ViewStyle) -> @core.ViewStyle = style => style,
  layout~ : (@core.ViewLayoutContext) -> @core.ViewLayoutResult,
  paint? : (@core.ViewPaintContext) -> @core.ViewPaintPlan = _context => {
    @core.ViewPaintPlan::empty()
  },
  event? : (@core.ViewEventContext) -> @core.ViewEventResult[Msg] = _context => {
    @core.ViewEventResult::ignored()
  },
  text_input_state? : (@core.ViewPaintContext) -> @core.TextInputState? = _context => {
    None
  },
  text_command? : (@core.ViewEventContext, @core.CommandIntent, String?) -> @core.ViewTextCommandResult[
    Msg,
  ] = (_context, _intent, _paste_text) => @core.ViewTextCommandResult::ignored(),
  semantics? : () -> @core.ViewSemanticsInfo = () => {
    @core.ViewSemanticsInfo::new()
  },
  focusable? : () -> Bool = () => false,
  flex_weight? : () -> Double = () => 0.0,
) -> @core.View[Msg] {
  @core.View::from_node(
    RuntimeWhiteBoxFixtureNode::{
      identity,
      revision,
      paint_revision,
      child_constraints,
      child_environment,
      child_style,
      layout,
      paint,
      text_input_state,
      semantics,
      focusable,
      flex_weight,
    },
    children=_node => children(),
    build_child=match build_child {
      Some(build) => Some((_node, context) => build(context))
      None => None
    },
    event=(_node, context) => event(context),
    text_command=(_node, context, intent, paste_text) => {
      text_command(context, intent, paste_text)
    },
  )
}
