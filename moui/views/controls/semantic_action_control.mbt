///|
priv enum SemanticControlAction {
  Expand
  Collapse
  Dismiss
}

///|
priv struct SemanticActionControl {
  action : SemanticControlAction
  expanded : Bool?
  role : @core.SemanticsRole?
}

///|
impl @core.ViewNode for SemanticActionControl with fn identity(self) {
  @core.ViewIdentity::new(
    kind=match self.action {
      Expand => "SemanticExpandAction"
      Collapse => "SemanticCollapseAction"
      Dismiss => "SemanticDismissAction"
    },
  )
}

///|
impl @core.ViewNode for SemanticActionControl with fn declaration(self) {
  @common.view_semantics_declaration(
    @common.view_record_key("SemanticActionControl", [
      (
        "action",
        @core.DeclarationKey::int(
          match self.action {
            Expand => 0
            Collapse => 1
            Dismiss => 2
          },
        ),
      ),
      (
        "expanded",
        @core.DeclarationKey::option(
          self.expanded.map(@core.DeclarationKey::bool),
        ),
      ),
      (
        "role",
        @core.DeclarationKey::option(
          self.role.map(@common.view_semantics_role_key),
        ),
      ),
    ]),
  )
}

///|
impl @core.ViewNode for SemanticActionControl with fn child_constraints(
  _self,
  constraints,
) {
  constraints
}

///|
impl @core.ViewNode for SemanticActionControl with fn layout(_self, ctx) {
  let child_size = @common.first_child_size(ctx.child_sizes)
  @core.ViewLayoutResult::new(size=child_size, child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
impl @core.ViewNode for SemanticActionControl with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::MergeDescendants,
    role?=self.role,
    expanded?=self.expanded,
  )
}

///|
pub fn[Msg] semantic_toggle_action_control(
  child : @core.View[Msg],
  expanded : Bool,
  message : Msg,
) -> @core.View[Msg] {
  let action = if expanded {
    SemanticControlAction::Collapse
  } else {
    SemanticControlAction::Expand
  }
  @core.View::from_node(
    SemanticActionControl::{ action, expanded: Some(expanded), role: None },
    children=_node => [child],
    semantics_actions=_node => {
      match action {
        Expand =>
          [
            @core.ViewSemanticsActionHandler::expand(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          ]
        Collapse =>
          [
            @core.ViewSemanticsActionHandler::collapse(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          ]
        Dismiss => []
      }
    },
  )
}

///|
pub fn[Msg] semantic_dismiss_action_control(
  child : @core.View[Msg],
  message : Msg,
  role? : @core.SemanticsRole? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    SemanticActionControl::{ action: Dismiss, expanded: None, role },
    children=_node => [child],
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::dismiss(_ctx => {
          @core.ViewSemanticsActionResult::message(message)
        }),
      ]
    },
  )
}
