///|
priv struct CustomLayout {
  measure : (@core.Constraints) -> @core.Size // declaration-exempt: consumed only by the Uncacheable layout channel
  paint : (@common.PaintContext, @core.Rect) -> Unit // declaration-exempt: consumed only by the Uncacheable paint channel
  semantics_role : @core.SemanticsRole
  semantics_label : String
}

///|
impl @core.ViewNode for CustomLayout with fn identity(_self) {
  @core.ViewIdentity::new(kind="CustomLayout")
}

///|
impl @core.ViewNode for CustomLayout with fn declaration(self) {
  @common.view_declaration(
    layout=@core.DeclarationChannel::Uncacheable,
    paint=@core.DeclarationChannel::Uncacheable,
    semantics=@common.view_exact_channel(
      @common.view_record_key("CustomLayout.semantics", [
        ("role", @common.view_semantics_role_key(self.semantics_role)),
        ("label", @core.DeclarationKey::string(self.semantics_label)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for CustomLayout with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=(self.measure)(ctx.constraints))
}

///|
impl @core.ViewNode for CustomLayout with fn paint(self, ctx) {
  let pctx = @common.PaintContext::new()
  (self.paint)(pctx, ctx.frame)
  @core.ViewPaintPlan::commands(@common.PaintContext::finish(pctx))
}

///|
impl @core.ViewNode for CustomLayout with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=if self.semantics_label == "" &&
      self.semantics_role == @core.SemanticsRole::Group {
      @core.SemanticsComposition::Transparent
    } else {
      @core.SemanticsComposition::Boundary
    },
    role=self.semantics_role,
    label=self.semantics_label,
    value=self.semantics_label,
  )
}

///|
pub fn[Msg] custom_layout(
  measure~ : (@core.Constraints) -> @core.Size,
  paint~ : (@common.PaintContext, @core.Rect) -> Unit,
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::from_node(CustomLayout::{
    measure,
    paint,
    semantics_role,
    semantics_label,
  })
}
