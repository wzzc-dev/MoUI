///|
/// Skia owns the capability declarations used by both its raster and GPU
/// providers. The backend enum is descriptive metadata; the id is the report
/// identity used by composition roots.
pub fn skia_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render_common.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let base_note = skia_feature_note(feature)
    let note = match backend {
      @render.RendererBackendKind::SkiaGpuNative =>
        "Skia GPU reuses the native Skia command and resource semantics; " +
        base_note
      _ => base_note
    }
    (@render.RendererFeatureStatus::Supported, note)
  })
}

///|
/// Feature evidence belongs to the Skia provider package. This is deliberately
/// not mirrored in `moui/render`: reports aggregate the declarations from the
/// providers registered by a composition root.
fn skia_feature_note(feature : @render.RendererFeature) -> String {
  match feature {
    Rect =>
      "Skia raster renders clear, rect fill, and rect stroke commands in the real native renderer pixel smoke through moui_skia/native."
    RoundedRect =>
      "Skia raster renders rounded rect fills, strokes, and solid rounded brushes in the real native renderer pixel smoke."
    Gradient =>
      "Skia raster renders linear-gradient and radial-gradient fills and strokes for rounded rects and paths; linear gradients have real native renderer pixel smoke coverage and radial brushes have renderer-local guarded pixel coverage."
    Shadow =>
      "Skia raster renders soft rounded shadows through moui_skia MaskFilter blur and real native renderer pixel smoke coverage."
    Text =>
      "Skia raster text measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interior stabilization for both caret paths, grapheme-safe mixed-run fallback segments, and best-available glyph-run rendering clip to the TextRun frame while resolving FontSpec family, weight, style, and representative coverage characters through Skia FontMgr FontFallbackRequest/Font; real native renderer smoke covers glyph-run pixels and bounded TextRun frame clipping; broader shaping remains tracked separately."
    Image =>
      "Skia raster decodes PNG/JPEG/BMP data URIs and local PNG/JPEG/BMP files through moui_skia encoded image APIs, validates contain/cover/stretch/scale-down/fit-width/fit-height placement geometry and draw_image_rect output, records ready/failed image lifecycle states, and renders failed-image placeholders in the real native renderer smoke."
    Clip =>
      "Skia raster applies canvas clip_rect, clip_rrect, and clip_path scopes, with rectangular, rounded, and path-clipped gradient output covered by the real native renderer smoke."
    Transform =>
      "Skia raster maps MoUI affine fields into Skia matrix members and validates translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform output in the real native renderer smoke."
    Opacity =>
      "Skia raster applies save_layer opacity, with blended pixel output covered by the real native renderer smoke."
    LayerCompositing =>
      "Skia raster composites save_layer scopes with renderer-local pixel tests and real native renderer smoke coverage for opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter combinations."
    BlendMode =>
      "Skia raster maps all MoUI blend modes to Skia paint blend modes with renderer-local multiply pixel coverage plus real native renderer smoke coverage for multiply, screen, overlay, darken, and lighten output pixels."
    FilterEffect =>
      "Skia raster applies image-filter and color-filter save_layer scopes with renderer-local saturation/color-matrix coverage plus real native renderer smoke coverage for blur, saturation, brightness, contrast, and identity-normalized color matrix filters."
    PathVector =>
      "Skia raster replays MoUI PathSpec into native Skia paths with renderer-local pixel tests and real native smoke coverage for solid and linear-gradient fills and strokes, plus quadratic and cubic curve verbs."
    ShaderEffect =>
      "Skia raster executes solid, checker, linear-gradient-debug, and vignette effects with renderer-local pixel tests and real native renderer pixel smoke coverage; unknown shader names still use fallback paths."
    TextShaping =>
      "Skia raster text provider maps FontSpec family, weight, and style to Skia FontMgr/Font, builds FontFallbackRequest values with representative emoji/non-ASCII coverage characters before regular family matching, splits mixed-script text into grapheme-safe fallback segments for per-run FontMgr resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or Skia-measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interiors in both caret paths, retries emoji-family fonts for emoji-hint text on the system FontMgr path, uses optional SkShaper shaped glyph-run drawing once linked, and marks SkParagraph-style line breaking plus bidi reordering ready in the text maturity preflight."
    EmojiText =>
      "Skia raster detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, emoji tag-sequence, Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark, and Hangul Jamo grapheme cluster samples, prefers emoji coverage characters and inferred language tags in system FontMgr FontFallbackRequest matching, stabilizes representative cluster interior carets, retries platform emoji font candidates before default-font fallback, and reports deterministic color emoji readiness through Typeface::has_color_glyphs and glyph format metadata."
    AsyncImage =>
      "Skia raster image lifecycle uses renderer-neutral records and tokenized image load events. Platform backends expose local-file bytes through HostImageSource without decoding them; the Skia factory owns RendererImageDecoder format detection, RGBA decode, and completion creation. RendererSession de-duplicates requests and rejects stale completions while backend WindowImageTasks owns only cancellable I/O. Skia caches immutable failures, retries a missing local file after it appears, applies ready completions to its renderer-local cache, and records second-frame repaint and disposal diagnostics."
  }
}
