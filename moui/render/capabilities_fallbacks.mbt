///|
pub fn plan_renderer_command_fallbacks(
  commands : Array[@core.DrawCommand],
) -> RendererCommandPlan {
  let fallbacks : Array[RendererCommandFallback] = []
  let mut clip_depth = 0
  let mut rounded_clip_depth = 0
  let mut transform_depth = 0
  let mut opacity_depth = 0
  let mut layer_depth = 0
  let mut filter_depth = 0
  for index, command in commands {
    match command {
      @core.DrawCommand::PushClip(_) => clip_depth = clip_depth + 1
      @core.DrawCommand::PopClip =>
        if clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Clip,
              command="PopClip",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopClip has no matching PushClip",
            ),
          )
        } else {
          clip_depth = clip_depth - 1
        }
      @core.DrawCommand::PushRoundedClip(_) =>
        rounded_clip_depth = rounded_clip_depth + 1
      @core.DrawCommand::PopRoundedClip =>
        if rounded_clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Clip,
              command="PopRoundedClip",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopRoundedClip has no matching PushRoundedClip",
            ),
          )
        } else {
          rounded_clip_depth = rounded_clip_depth - 1
        }
      @core.DrawCommand::PushTransform(_) =>
        transform_depth = transform_depth + 1
      @core.DrawCommand::PopTransform =>
        if transform_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Transform,
              command="PopTransform",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopTransform has no matching PushTransform",
            ),
          )
        } else {
          transform_depth = transform_depth - 1
        }
      @core.DrawCommand::PushOpacity(_) => opacity_depth = opacity_depth + 1
      @core.DrawCommand::PopOpacity =>
        if opacity_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Opacity,
              command="PopOpacity",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopOpacity has no matching PushOpacity",
            ),
          )
        } else {
          opacity_depth = opacity_depth - 1
        }
      @core.DrawCommand::PushLayer(_)
      | @core.DrawCommand::BeginCachedLayer(_) => layer_depth = layer_depth + 1
      @core.DrawCommand::PopLayer | @core.DrawCommand::EndCachedLayer(_) =>
        if layer_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::LayerCompositing,
              command="PopLayer",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopLayer has no matching PushLayer",
            ),
          )
        } else {
          layer_depth = layer_depth - 1
        }
      @core.DrawCommand::DrawCachedLayer(_) => ()
      @core.DrawCommand::PushFilter(_) => filter_depth = filter_depth + 1
      @core.DrawCommand::PopFilter =>
        if filter_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::FilterEffect,
              command="PopFilter",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopFilter has no matching PushFilter",
            ),
          )
        } else {
          filter_depth = filter_depth - 1
        }
      @core.DrawCommand::DrawPath(_) => ()
      @core.DrawCommand::DrawShaderEffect(_) => ()
      _ => ()
    }
  }
  if clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Clip,
        command="PushClip",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open clip scope",
      ),
    )
  }
  if rounded_clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Clip,
        command="PushRoundedClip",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open rounded clip scope",
      ),
    )
  }
  if transform_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Transform,
        command="PushTransform",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open transform scope",
      ),
    )
  }
  if opacity_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Opacity,
        command="PushOpacity",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open opacity scope",
      ),
    )
  }
  if layer_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::LayerCompositing,
        command="PushLayer",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open layer scope",
      ),
    )
  }
  if filter_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::FilterEffect,
        command="PushFilter",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open filter scope",
      ),
    )
  }
  {
    total_commands: commands.length(),
    fallback_count: fallbacks.length(),
    final_layer_depth: layer_depth,
    final_filter_depth: filter_depth,
    fallbacks,
  }
}

///|
fn renderer_command_fallback(
  index~ : Int,
  feature~ : RendererFeature,
  command~ : String,
  reason~ : String,
  kind? : RendererCommandFallbackKind = RendererCommandFallbackKind::PlannedFallback,
) -> RendererCommandFallback {
  { index, feature, command, kind, reason }
}
