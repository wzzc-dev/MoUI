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
  BeginRetainedLayer(@core.RetainedLayerSpec)
  EndRetainedLayer(String)
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
      Clear(color) => ops.push(Clear(color))
      FillRect(rect, color) => ops.push(FillRect(rect, color))
      StrokeRect(rect, color, width) => ops.push(StrokeRect(rect, color, width))
      FillRoundedRect(rounded, color) =>
        ops.push(FillRoundedRect(rounded, color))
      StrokeRoundedRect(rounded, color, width) =>
        ops.push(StrokeRoundedRect(rounded, color, width))
      FillRoundedRectBrush(rounded, brush) =>
        ops.push(FillRoundedRectBrush(rounded, brush))
      StrokeRoundedRectBrush(rounded, brush, width) =>
        ops.push(StrokeRoundedRectBrush(rounded, brush, width))
      DrawShadow(shadow) => ops.push(DrawShadow(shadow))
      DrawText(run) => ops.push(DrawText(run))
      DrawImage(run) => ops.push(DrawImage(run))
      PushClip(rect) => {
        scopes.push(Clip)
        ops.push(PushClip(rect))
      }
      PopClip => {
        plan_pop_scope(scopes, diagnostics, Clip)
        ops.push(PopClip)
      }
      PushRoundedClip(rounded) => {
        scopes.push(RoundedClip)
        ops.push(PushRoundedClip(rounded))
      }
      PopRoundedClip => {
        plan_pop_scope(scopes, diagnostics, RoundedClip)
        ops.push(PopRoundedClip)
      }
      PushTransform(transform) => {
        scopes.push(Transform)
        ops.push(PushTransform(transform))
      }
      PopTransform => {
        plan_pop_scope(scopes, diagnostics, Transform)
        ops.push(PopTransform)
      }
      PushOpacity(opacity) => {
        scopes.push(Opacity)
        ops.push(PushOpacity(opacity))
      }
      PopOpacity => {
        plan_pop_scope(scopes, diagnostics, Opacity)
        ops.push(PopOpacity)
      }
      PushLayer(layer) => {
        scopes.push(Layer)
        ops.push(PushLayer(layer))
      }
      PopLayer => {
        plan_pop_scope(scopes, diagnostics, Layer)
        ops.push(PopLayer)
      }
      BeginRetainedLayer(spec) => {
        scopes.push(Layer)
        ops.push(BeginRetainedLayer(spec))
      }
      EndRetainedLayer(key) => {
        plan_pop_scope(scopes, diagnostics, Layer)
        ops.push(EndRetainedLayer(key))
      }
      PushFilter(filter) => {
        scopes.push(Filter)
        ops.push(PushFilter(filter))
      }
      PopFilter => {
        plan_pop_scope(scopes, diagnostics, Filter)
        ops.push(PopFilter)
      }
      DrawPath(path) => ops.push(DrawPath(path))
      DrawShaderEffect(spec) => ops.push(DrawShaderEffect(spec))
    }
  }
  while scopes.length() > 0 {
    let scope = scopes.pop().unwrap()
    diagnostics.push({
      command: plan_scope_push_command(scope),
      reason: "push scope was never popped: \{plan_scope_name(scope)}",
    })
  }
  { ops, diagnostics, }
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
