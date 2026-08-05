///|
/// Shared DrawCommand lowering (ADR 0019). Renderers used to interpret the
/// 27 `@core.DrawCommand` variants themselves, each maintaining its own
/// transform/clip/opacity state stack. This module owns that interpretation
/// once: `lower_draw_commands` matches every variant and validates scope
/// balance, producing a neutral `DrawPlan` of `PlanOp`s that renderers
/// execute natively. Adding a DrawCommand variant now touches the core
/// contract plus this single lowering instead of four parallel interpreters.

///|
/// Neutral plan operation. Mirrors `@core.DrawCommand` payloads exactly so
/// every renderer can map ops to its native backend without semantic
/// re-interpretation.
pub(all) enum PlanOp {
  Clear(@core.Color)
  FillRect(@core.Rect, @core.Color)
  StrokeRect(@core.Rect, @core.Color, Double)
  FillRoundedRect(@core.RoundedRect, @core.Color)
  StrokeRoundedRect(@core.RoundedRect, @core.Color, Double)
  FillRoundedRectBrush(@core.RoundedRect, @core.Brush)
  StrokeRoundedRectBrush(@core.RoundedRect, @core.Brush, Double)
  DrawShadow(@core.ShadowSpec)
  DrawText(@core.TextRun)
  DrawImage(@core.ImageRun)
  PushClip(@core.Rect)
  PopClip
  PushRoundedClip(@core.RoundedRect)
  PopRoundedClip
  PushTransform(@core.Transform2D)
  PopTransform
  PushOpacity(Double)
  PopOpacity
  PushLayer(@core.LayerSpec)
  PopLayer
  BeginCachedLayer(@core.CachedLayerSpec)
  EndCachedLayer(String)
  DrawCachedLayer(@core.CachedLayerSpec)
  PushFilter(@core.FilterEffect)
  PopFilter
  DrawPath(@core.PathSpec)
  DrawShaderEffect(@core.ShaderEffectSpec)
} derive(Eq, Debug, ToJson)

///|
/// A lowered draw stream: neutral ops plus diagnostics for structural
/// problems found during lowering (unbalanced clip/transform/opacity/layer/
/// filter scopes). Renderers execute `ops`; `diagnostics` is an additional
/// shared signal that does not change native execution.
pub(all) struct DrawPlan {
  ops : Array[PlanOp]
  diagnostics : Array[DrawPlanDiagnostic]
}

///|
pub(all) struct DrawPlanDiagnostic {
  command : String
  reason : String
} derive(Eq, Debug)

///|
/// The scope kinds tracked for balance validation. Mirrors the state stacks
/// every renderer used to maintain independently.
pub(all) enum PlanScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
  Layer
  Filter
} derive(Eq)

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
/// The single interpretation of a `DrawCommand` stream: match every variant
/// once, maintain the transform/clip/opacity/layer/filter state stack, and
/// emit neutral ops plus balance diagnostics.
pub fn lower_draw_commands(commands : Array[@core.DrawCommand]) -> DrawPlan {
  let ops : Array[PlanOp] = []
  let diagnostics : Array[DrawPlanDiagnostic] = []
  let scopes : Array[PlanScopeKind] = []
  for command in commands {
    match command {
      @core.DrawCommand::Clear(color) => ops.push(PlanOp::Clear(color))
      @core.DrawCommand::FillRect(rect, color) =>
        ops.push(PlanOp::FillRect(rect, color))
      @core.DrawCommand::StrokeRect(rect, color, width) =>
        ops.push(PlanOp::StrokeRect(rect, color, width))
      @core.DrawCommand::FillRoundedRect(rounded, color) =>
        ops.push(PlanOp::FillRoundedRect(rounded, color))
      @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
        ops.push(PlanOp::StrokeRoundedRect(rounded, color, width))
      @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
        ops.push(PlanOp::FillRoundedRectBrush(rounded, brush))
      @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
        ops.push(PlanOp::StrokeRoundedRectBrush(rounded, brush, width))
      @core.DrawCommand::DrawShadow(shadow) =>
        ops.push(PlanOp::DrawShadow(shadow))
      @core.DrawCommand::DrawText(run) => ops.push(PlanOp::DrawText(run))
      @core.DrawCommand::DrawImage(run) => ops.push(PlanOp::DrawImage(run))
      @core.DrawCommand::PushClip(rect) => {
        scopes.push(PlanScopeKind::Clip)
        ops.push(PlanOp::PushClip(rect))
      }
      @core.DrawCommand::PopClip => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Clip)
        ops.push(PlanOp::PopClip)
      }
      @core.DrawCommand::PushRoundedClip(rounded) => {
        scopes.push(PlanScopeKind::RoundedClip)
        ops.push(PlanOp::PushRoundedClip(rounded))
      }
      @core.DrawCommand::PopRoundedClip => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::RoundedClip)
        ops.push(PlanOp::PopRoundedClip)
      }
      @core.DrawCommand::PushTransform(transform) => {
        scopes.push(PlanScopeKind::Transform)
        ops.push(PlanOp::PushTransform(transform))
      }
      @core.DrawCommand::PopTransform => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Transform)
        ops.push(PlanOp::PopTransform)
      }
      @core.DrawCommand::PushOpacity(opacity) => {
        scopes.push(PlanScopeKind::Opacity)
        ops.push(PlanOp::PushOpacity(opacity))
      }
      @core.DrawCommand::PopOpacity => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Opacity)
        ops.push(PlanOp::PopOpacity)
      }
      @core.DrawCommand::PushLayer(layer) => {
        scopes.push(PlanScopeKind::Layer)
        ops.push(PlanOp::PushLayer(layer))
      }
      @core.DrawCommand::PopLayer => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Layer)
        ops.push(PlanOp::PopLayer)
      }
      @core.DrawCommand::BeginCachedLayer(spec) => {
        scopes.push(PlanScopeKind::Layer)
        ops.push(PlanOp::BeginCachedLayer(spec))
      }
      @core.DrawCommand::EndCachedLayer(key) => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Layer)
        ops.push(PlanOp::EndCachedLayer(key))
      }
      @core.DrawCommand::DrawCachedLayer(spec) =>
        ops.push(PlanOp::DrawCachedLayer(spec))
      @core.DrawCommand::PushFilter(filter) => {
        scopes.push(PlanScopeKind::Filter)
        ops.push(PlanOp::PushFilter(filter))
      }
      @core.DrawCommand::PopFilter => {
        plan_pop_scope(scopes, diagnostics, PlanScopeKind::Filter)
        ops.push(PlanOp::PopFilter)
      }
      @core.DrawCommand::DrawPath(path) => ops.push(PlanOp::DrawPath(path))
      @core.DrawCommand::DrawShaderEffect(spec) =>
        ops.push(PlanOp::DrawShaderEffect(spec))
    }
  }
  while scopes.length() > 0 {
    let scope = scopes.pop().unwrap()
    diagnostics.push({
      command: plan_scope_push_command(scope),
      reason: "push scope was never popped: \{plan_scope_name(scope)}",
    })
  }
  { ops, diagnostics }
}

///|
fn plan_pop_scope(
  scopes : Array[PlanScopeKind],
  diagnostics : Array[DrawPlanDiagnostic],
  expected : PlanScopeKind,
) -> Unit {
  match scopes.pop() {
    Some(actual) =>
      if actual != expected {
        diagnostics.push({
          command: plan_scope_pop_command(expected),
          reason: "pop did not match active \{plan_scope_name(actual)} scope",
        })
      }
    None =>
      diagnostics.push({
        command: plan_scope_pop_command(expected),
        reason: "pop has no matching push scope",
      })
  }
}
