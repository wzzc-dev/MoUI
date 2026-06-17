///|
pub fn[Msg] component(
  build : (@core.ComponentContext) -> @core.View[Msg],
  kind? : String = "Component",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::widget(
    @core.Widget::new(
      identity=() => @core.WidgetIdentity::new(kind~, key~),
      revision=() => "component",
      build_child=Some(build),
      layout=ctx => {
        @core.WidgetLayoutResult::new(
          size=ctx.constraints.constrain(first_child_size(ctx.child_sizes)),
          child_frames=if ctx.child_sizes.length() > 0 {
            let size = first_child_size(ctx.child_sizes)
            [
              @core.Rect::new(
                x=0.0,
                y=0.0,
                width=size.width,
                height=size.height,
              ),
            ]
          } else {
            []
          },
        )
      },
      semantics=() => {
        @core.WidgetSemanticsInfo::new(role=@core.SemanticsRole::Group)
      },
    ),
  )
}
