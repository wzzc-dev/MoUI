///|
/// Tests for the single standalone scope-balance validation
/// (`plan_renderer_command_fallbacks`, formerly split between the deleted
/// `lower_draw_commands` diagnostics and this checker) and the shared
/// `PlanScopeKind` vocabulary renderers use on their execution stacks.

///|
test "balanced streams produce no fallbacks" {
  let balanced = [
    @core.DrawCommand::Clear(@core.Color::white()),
    PushClip(@core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0)),
    PushTransform(@core.Transform2D::identity()),
    PushOpacity(0.5),
    PopOpacity,
    PopTransform,
    PopClip,
    BeginRetainedLayer(
      @core.RetainedLayerSpec::new(
        key="k",
        frame=@core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
        content_revision=1,
      ),
    ),
    EndRetainedLayer("k"),
    PushLayer(@core.LayerSpec::new()),
    PushFilter(@core.FilterEffect::blur(2.0)),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::black(),
    ),
    PopFilter,
    PopLayer,
  ]
  let plan = @common.plan_renderer_command_fallbacks(balanced)
  assert_eq(plan.total_commands(), balanced.length())
  assert_eq(plan.fallback_count(), 0)
  assert_eq(plan.final_layer_depth(), 0)
  assert_eq(plan.final_filter_depth(), 0)
}

///|
test "unbalanced pops surface as UnbalancedPop fallbacks" {
  let plan = @common.plan_renderer_command_fallbacks([@core.PopClip])
  assert_eq(plan.fallback_count(), 1)
  let fallback = plan.fallbacks()[0]
  inspect(fallback.command(), content="PopClip")
  assert_true(fallback.kind() is UnbalancedPop)
  inspect(fallback.index(), content="0")
}

///|
test "mismatched pop kinds count per kind" {
  // PushTransform then PopClip: the clip pop is unbalanced and the transform
  // scope is left open — per-kind depths catch both, independent of order.
  let plan = @common.plan_renderer_command_fallbacks([
    @core.PushTransform(@core.Transform2D::identity()),
    @core.PopClip,
  ])
  assert_eq(plan.fallback_count(), 2)
  inspect(plan.fallbacks()[0].command(), content="PopClip")
  inspect(plan.fallbacks()[1].command(), content="PushTransform")
}

///|
test "unpopped scopes surface as UnclosedScope fallbacks" {
  let plan = @common.plan_renderer_command_fallbacks([
    @core.PushLayer(@core.LayerSpec::new()),
    @core.PushFilter(@core.FilterEffect::blur(2.0)),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::black(),
    ),
  ])
  assert_eq(plan.fallback_count(), 2)
  assert_eq(plan.final_layer_depth(), 1)
  assert_eq(plan.final_filter_depth(), 1)
  inspect(plan.fallbacks()[0].command(), content="PushLayer")
  inspect(plan.fallbacks()[1].command(), content="PushFilter")
}

///|
test "scope kind names match push and pop commands" {
  let kinds = [
    @common.Clip,
    @common.RoundedClip,
    @common.Transform,
    @common.Opacity,
    @common.Layer,
    @common.Filter,
  ]
  for kind in kinds {
    let push = @common.plan_scope_push_command(kind)
    let pop = @common.plan_scope_pop_command(kind)
    inspect(
      "\{push}->\{@common.plan_scope_name(kind)}->\{pop}",
      content=match kind {
        Clip => "PushClip->clip->PopClip"
        RoundedClip => "PushRoundedClip->rounded-clip->PopRoundedClip"
        Transform => "PushTransform->transform->PopTransform"
        Opacity => "PushOpacity->opacity->PopOpacity"
        Layer => "PushLayer->layer->PopLayer"
        Filter => "PushFilter->filter->PopFilter"
      },
    )
  }
}
