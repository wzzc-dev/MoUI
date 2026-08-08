///|
priv struct RuntimeFixtureNode {
  identity : () -> @core.ViewIdentity
  declaration : () -> @core.ViewDeclaration
  child_constraints : (@core.Constraints) -> @core.Constraints
  child_environment : (@core.Environment) -> @core.Environment
  child_style : (@core.ViewStyle) -> @core.ViewStyle
  layout : (@core.ViewLayoutContext) -> @core.ViewLayoutResult
  paint : (@core.ViewPaintContext) -> @core.ViewPaintPlan
  platform_views : (@core.ViewPlatformContext) -> Array[
    @core.PlatformViewPlacement,
  ]
  text_input_state : (@core.ViewPaintContext) -> @core.TextInputState?
  semantics : () -> @core.ViewSemanticsInfo
  focusable : () -> Bool
  flex_weight : () -> Double
}

///|
fn runtime_fixture_exact_declaration(
  type_tag : String,
  fields : Array[(String, @core.DeclarationKey)],
) -> @core.ViewDeclaration {
  let key = @core.DeclarationKey::record(type_tag~, fields~)
  @core.ViewDeclaration::channels(
    layout=@core.DeclarationChannel::Exact(key),
    paint=@core.DeclarationChannel::Exact(key),
    semantics=@core.DeclarationChannel::Exact(key),
    platform=@core.DeclarationChannel::Exact(key),
  )
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn identity(self) {
  (self.identity)()
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn declaration(self) {
  (self.declaration)()
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn child_constraints(
  self,
  constraints,
) {
  (self.child_constraints)(constraints)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn child_environment(
  self,
  environment,
) {
  (self.child_environment)(environment)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn child_style(self, style) {
  (self.child_style)(style)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn layout(self, context) {
  (self.layout)(context)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn paint(self, context) {
  (self.paint)(context)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn platform_views(self, context) {
  (self.platform_views)(context)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn text_input_state(
  self,
  context,
) {
  (self.text_input_state)(context)
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn semantics(self) {
  (self.semantics)()
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn focusable(self) {
  (self.focusable)()
}

///|
impl @core.ViewNode for RuntimeFixtureNode with fn flex_weight(self) {
  (self.flex_weight)()
}

///|
fn[Msg] runtime_fixture_view(
  identity~ : () -> @core.ViewIdentity,
  declaration? : () -> @core.ViewDeclaration = () => {
    @core.ViewDeclaration::constant()
  },
  children? : () -> Array[@core.View[Msg]] = () => [],
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
  platform_views? : (@core.ViewPlatformContext) -> Array[
    @core.PlatformViewPlacement,
  ] = _context => [],
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
    RuntimeFixtureNode::{
      identity,
      declaration,
      child_constraints,
      child_environment,
      child_style,
      layout,
      paint,
      platform_views,
      text_input_state,
      semantics,
      focusable,
      flex_weight,
    },
    children=_node => children(),
    event=(_node, context) => event(context),
    text_command=(_node, context, intent, paste_text) => {
      text_command(context, intent, paste_text)
    },
  )
}
