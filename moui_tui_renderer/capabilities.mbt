///|
/// TUI cell 投影的特性能力。这里记录的是投影器真正能做到的事,
/// 不是像素渲染器的能力表换个名字:等宽栅格没有渐变、阴影、
/// 变换与矢量路径,把它们写成 supported 会让能力报告说谎。
pub fn tui_feature_status(
  feature : @render.RendererFeature,
) -> @render.RendererFeatureStatus {
  match feature {
    Rect | Text | Clip => Supported
    RoundedRect | Opacity | LayerCompositing | TextShaping | EmojiText =>
      Partial
    Gradient
    | Shadow
    | Image
    | Transform
    | BlendMode
    | FilterEffect
    | PathVector
    | ShaderEffect
    | AsyncImage => Gap
  }
}

///|
pub fn tui_feature_note(feature : @render.RendererFeature) -> String {
  match feature {
    Rect =>
      "Terminal ANSI paints rectangular regions as box-drawing borders plus SGR background runs over the quantized cell grid."
    RoundedRect =>
      "A cell grid only has the four corner glyphs, so rounded rects project as box-drawing corners without radius control."
    Clip =>
      "Every paint is clipped to the node's own quantized box and wraps inside it; fully off-screen nodes are dropped rather than clamped."
    Text =>
      "Cell text goes through the equal-width cell TextSystem, so layout boxes and the terminal grid share one coordinate system."
    TextShaping =>
      "There is no shaper: advance is one or two cells per code point, and CJK/emoji double width is honored by the cell buffer."
    EmojiText =>
      "Emoji are emitted as-is with width from `moui_tui.unicode_width`; presentation depends on the host terminal font."
    Opacity =>
      "Opacity has exactly two visible levels in a terminal: normal and the SGR dim attribute."
    LayerCompositing =>
      "Layering is the projector's claim rule: chrome borders at priority 1, container titles at 2, leaf content at 3, first-come-wins at equal priority."
    Gradient =>
      "A cell grid cannot represent a gradient; gradient brushes are dropped with a degrade diagnostic."
    Shadow =>
      "Shadows have no cell representation and are dropped with a degrade diagnostic."
    Image =>
      "Image nodes render as an explicit placeholder token with a degrade diagnostic; pixels never silently vanish."
    AsyncImage =>
      "Image loading is not driven by the cell projector, so async image records stay empty."
    Transform =>
      "Affine transforms cannot be sampled onto an integer cell grid; transformed scopes fall back to their untransformed box."
    BlendMode =>
      "Terminals composite by overwrite, so blend modes have no representation."
    FilterEffect =>
      "Filter scopes have no cell representation and are dropped with a degrade diagnostic."
    PathVector =>
      "Vector paths are not rasterized onto cells and are dropped with a degrade diagnostic."
    ShaderEffect =>
      "Shader effects are not evaluated onto cells and are dropped with a degrade diagnostic."
  }
}

///|
/// 全特性能力表。provider_id 是能力报告的聚合身份,
/// backend 只是诊断分类元数据(ADR 0027)。
pub fn tui_feature_capabilities() -> Array[
  @render.RendererBackendFeatureCapability,
] {
  let all_features = [
    @render.RendererFeature::Rect,
    RoundedRect,
    Gradient,
    Shadow,
    Text,
    Image,
    Clip,
    Transform,
    Opacity,
    LayerCompositing,
    BlendMode,
    FilterEffect,
    PathVector,
    ShaderEffect,
    TextShaping,
    EmojiText,
    AsyncImage,
  ]
  all_features.map(feature => {
    @render.RendererBackendFeatureCapability::new(
      provider_id="tui-ansi",
      feature~,
      backend=TerminalAnsiNative,
      status=tui_feature_status(feature),
      note=tui_feature_note(feature),
    )
  })
}

///|
pub fn tui_terminal_ansi_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=TerminalAnsiNative,
    family=Terminal,
    presentation=ExternalSurface,
    supported_targets=[Native],
    capabilities=tui_feature_capabilities(),
    description="Terminal ANSI renderer that projects semantics frames onto an equal-width cell grid and writes byte streams to a host-supplied sink.",
  )
}
