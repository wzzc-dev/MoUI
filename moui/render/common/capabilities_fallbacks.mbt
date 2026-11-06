///|
/// The scope kinds tracked for scope-balance validation. This is the shared
/// vocabulary renderers push/pop on their own execution state stacks while
/// interpreting a `@core.DrawCommand` stream directly, and the same kinds
/// `plan_renderer_command_fallbacks` validates on the stream itself.
#derive(Eq)
pub(all) enum PlanScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
  Layer
  Filter
}

///|
pub extend PlanScopeKind with Eq::{not_equal, equal}

///|
pub fn plan_scope_name(kind : PlanScopeKind) -> String {
  match kind {
    Clip => "clip"
    RoundedClip => "rounded-clip"
    Transform => "transform"
    Opacity => "opacity"
    Layer => "layer"
    Filter => "filter"
  }
}

///|
pub fn plan_scope_push_command(kind : PlanScopeKind) -> String {
  match kind {
    Clip => "PushClip"
    RoundedClip => "PushRoundedClip"
    Transform => "PushTransform"
    Opacity => "PushOpacity"
    Layer => "PushLayer"
    Filter => "PushFilter"
  }
}

///|
pub fn plan_scope_pop_command(kind : PlanScopeKind) -> String {
  match kind {
    Clip => "PopClip"
    RoundedClip => "PopRoundedClip"
    Transform => "PopTransform"
    Opacity => "PopOpacity"
    Layer => "PopLayer"
    Filter => "PopFilter"
  }
}

///|
/// The single standalone scope-balance validation of a `@core.DrawCommand`
/// stream, and the producer of the capability-report `RendererCommandPlan`.
/// Renderers execute `@core.DrawCommand` directly (each maintaining its own
/// execution state stacks); this check stays the one shared structural
/// validation with per-command fallback records.
pub fn plan_renderer_command_fallbacks(
  commands : Array[@core.DrawCommand],
) -> @render.RendererCommandPlan {
  let fallbacks : Array[@render.RendererCommandFallback] = []
  let mut clip_depth = 0
  let mut rounded_clip_depth = 0
  let mut transform_depth = 0
  let mut opacity_depth = 0
  let mut layer_depth = 0
  let mut filter_depth = 0
  for index, command in commands {
    match command {
      PushClip(_) => clip_depth = clip_depth + 1
      PopClip =>
        if clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=Clip,
              command="PopClip",
              kind=UnbalancedPop,
              reason="PopClip has no matching PushClip",
            ),
          )
        } else {
          clip_depth = clip_depth - 1
        }
      PushRoundedClip(_) => rounded_clip_depth = rounded_clip_depth + 1
      PopRoundedClip =>
        if rounded_clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=Clip,
              command="PopRoundedClip",
              kind=UnbalancedPop,
              reason="PopRoundedClip has no matching PushRoundedClip",
            ),
          )
        } else {
          rounded_clip_depth = rounded_clip_depth - 1
        }
      PushTransform(_) => transform_depth = transform_depth + 1
      PopTransform =>
        if transform_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=Transform,
              command="PopTransform",
              kind=UnbalancedPop,
              reason="PopTransform has no matching PushTransform",
            ),
          )
        } else {
          transform_depth = transform_depth - 1
        }
      PushOpacity(_) => opacity_depth = opacity_depth + 1
      PopOpacity =>
        if opacity_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=Opacity,
              command="PopOpacity",
              kind=UnbalancedPop,
              reason="PopOpacity has no matching PushOpacity",
            ),
          )
        } else {
          opacity_depth = opacity_depth - 1
        }
      PushLayer(_) | BeginRetainedLayer(_) => layer_depth = layer_depth + 1
      PopLayer | EndRetainedLayer(_) =>
        if layer_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=LayerCompositing,
              command="PopLayer",
              kind=UnbalancedPop,
              reason="PopLayer has no matching PushLayer",
            ),
          )
        } else {
          layer_depth = layer_depth - 1
        }
      PushFilter(_) => filter_depth = filter_depth + 1
      PopFilter =>
        if filter_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=FilterEffect,
              command="PopFilter",
              kind=UnbalancedPop,
              reason="PopFilter has no matching PushFilter",
            ),
          )
        } else {
          filter_depth = filter_depth - 1
        }
      DrawPath(_) => ()
      DrawShaderEffect(_) => ()
      _ => ()
    }
  }
  if clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=Clip,
        command="PushClip",
        kind=UnclosedScope,
        reason="command stream ended with an open clip scope",
      ),
    )
  }
  if rounded_clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=Clip,
        command="PushRoundedClip",
        kind=UnclosedScope,
        reason="command stream ended with an open rounded clip scope",
      ),
    )
  }
  if transform_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=Transform,
        command="PushTransform",
        kind=UnclosedScope,
        reason="command stream ended with an open transform scope",
      ),
    )
  }
  if opacity_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=Opacity,
        command="PushOpacity",
        kind=UnclosedScope,
        reason="command stream ended with an open opacity scope",
      ),
    )
  }
  if layer_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=LayerCompositing,
        command="PushLayer",
        kind=UnclosedScope,
        reason="command stream ended with an open layer scope",
      ),
    )
  }
  if filter_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=FilterEffect,
        command="PushFilter",
        kind=UnclosedScope,
        reason="command stream ended with an open filter scope",
      ),
    )
  }
  @render.RendererCommandPlan::new(
    total_commands=commands.length(),
    fallback_count=fallbacks.length(),
    final_layer_depth=layer_depth,
    final_filter_depth=filter_depth,
    fallbacks~,
  )
}

///|
fn renderer_command_fallback(
  index~ : Int32,
  feature~ : @render.RendererFeature,
  command~ : String,
  reason~ : String,
  kind~ : @render.RendererCommandFallbackKind = PlannedFallback,
) -> @render.RendererCommandFallback {
  @render.RendererCommandFallback::new(
    index~,
    feature~,
    command~,
    kind~,
    reason~,
  )
}
