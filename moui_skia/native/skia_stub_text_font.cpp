#include "skia_stub_common.h"

#if defined(MOUI_SKIA_HAS_SKSHAPER_HEADERS)
#if __has_include("modules/skshaper/include/SkShaper_harfbuzz.h")
#include "modules/skshaper/include/SkShaper_harfbuzz.h"
#define MOUI_SKIA_HAS_SKSHAPER_HARFBUZZ 1
#endif
#if __has_include("modules/skunicode/include/SkUnicode_icu.h")
#include "modules/skunicode/include/SkUnicode_icu.h"
#define MOUI_SKIA_HAS_SKUNICODE_ICU 1
#endif
#endif

#if defined(MOUI_SKIA_HAS_SKIA)
static SkFontMetrics moonbit_skia_get_font_metrics(MoonbitSkiaFont* wrapper) {
  SkFontMetrics metrics = {};
  if (wrapper != nullptr && wrapper->font != nullptr) {
    wrapper->font->getMetrics(&metrics);
  }
  return metrics;
}
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_HEADERS) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_LEGACY)
class MoonbitSkiaShaperRunHandler final : public SkShaper::RunHandler {
public:
  void beginLine() override {
    max_run_ascent_ = 0.0f;
    max_run_descent_ = 0.0f;
    max_run_leading_ = 0.0f;
  }

  void runInfo(const RunInfo& info) override {
    if (
      info.glyphCount >
      static_cast<size_t>(std::numeric_limits<int32_t>::max()) - total_glyph_count_
    ) {
      overflow_ = true;
      return;
    }
    total_glyph_count_ += info.glyphCount;

    SkFontMetrics metrics = {};
    info.fFont.getMetrics(&metrics);
    max_run_ascent_ = std::min(max_run_ascent_, metrics.fAscent);
    max_run_descent_ = std::max(max_run_descent_, metrics.fDescent);
    max_run_leading_ = std::max(max_run_leading_, metrics.fLeading);
  }

  void commitRunInfo() override {
    if (overflow_) {
      glyphs_.clear();
      positions_.clear();
      clusters_.clear();
      return;
    }
    glyphs_.resize(total_glyph_count_);
    positions_.resize(total_glyph_count_);
    clusters_.resize(total_glyph_count_);
  }

  Buffer runBuffer(const RunInfo& info) override {
    active_glyph_offset_ = next_glyph_offset_;
    active_glyph_count_ = info.glyphCount;
    active_point_ = current_position_;
    active_advance_ = info.fAdvance;

    if (
      overflow_ ||
      active_glyph_count_ == 0 ||
      active_glyph_offset_ + active_glyph_count_ > glyphs_.size()
    ) {
      scratch_glyphs_.resize(std::max<size_t>(1, active_glyph_count_));
      scratch_positions_.resize(std::max<size_t>(1, active_glyph_count_));
      scratch_clusters_.resize(std::max<size_t>(1, active_glyph_count_));
      return {
        scratch_glyphs_.data(),
        scratch_positions_.data(),
        nullptr,
        scratch_clusters_.data(),
        active_point_
      };
    }

    return {
      glyphs_.data() + active_glyph_offset_,
      positions_.data() + active_glyph_offset_,
      nullptr,
      clusters_.data() + active_glyph_offset_,
      active_point_
    };
  }

  void commitRunBuffer(const RunInfo&) override {
    if (
      overflow_ ||
      active_glyph_count_ == 0 ||
      active_glyph_offset_ + active_glyph_count_ > positions_.size()
    ) {
      return;
    }

    for (size_t i = 0; i < active_glyph_count_; ++i) {
      size_t index = active_glyph_offset_ + i;
      positions_[index] = SkPoint::Make(
        positions_[index].x() + active_point_.x(),
        positions_[index].y() + active_point_.y()
      );
    }
    next_glyph_offset_ += active_glyph_count_;
    current_position_ = SkPoint::Make(
      current_position_.x() + active_advance_.x(),
      current_position_.y() + active_advance_.y()
    );
  }

  void commitLine() override {
    advance_x_ = std::max(advance_x_, current_position_.x());
    advance_y_ = current_position_.y();

    float line_height = max_run_descent_ - max_run_ascent_ + max_run_leading_;
    if (line_height > 0.0f) {
      current_position_ = SkPoint::Make(0.0f, current_position_.y() + line_height);
    }
  }

  bool ok() const {
    return !overflow_ && !glyphs_.empty() && glyphs_.size() == next_glyph_offset_;
  }

  int32_t glyph_count() const {
    if (glyphs_.size() > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
      return std::numeric_limits<int32_t>::max();
    }
    return static_cast<int32_t>(glyphs_.size());
  }

  float advance_x() const { return advance_x_; }
  float advance_y() const { return advance_y_; }

  const std::vector<SkGlyphID>& glyphs() const { return glyphs_; }
  const std::vector<SkPoint>& positions() const { return positions_; }
  const std::vector<uint32_t>& clusters() const { return clusters_; }

private:
  std::vector<SkGlyphID> glyphs_;
  std::vector<SkPoint> positions_;
  std::vector<uint32_t> clusters_;
  std::vector<SkGlyphID> scratch_glyphs_;
  std::vector<SkPoint> scratch_positions_;
  std::vector<uint32_t> scratch_clusters_;
  size_t total_glyph_count_ = 0;
  size_t next_glyph_offset_ = 0;
  size_t active_glyph_offset_ = 0;
  size_t active_glyph_count_ = 0;
  SkPoint active_point_ = SkPoint::Make(0.0f, 0.0f);
  SkVector active_advance_ = SkVector::Make(0.0f, 0.0f);
  SkPoint current_position_ = SkPoint::Make(0.0f, 0.0f);
  float max_run_ascent_ = 0.0f;
  float max_run_descent_ = 0.0f;
  float max_run_leading_ = 0.0f;
  float advance_x_ = 0.0f;
  float advance_y_ = 0.0f;
  bool overflow_ = false;
};

static std::unique_ptr<SkShaper> moonbit_skia_make_shaper() {
  // Always resolve and validate the fallback manager before constructing a
  // shaper.  The legacy CoreText convenience path creates its own font-run
  // iterator; on macOS that iterator can dereference a null manager during
  // character fallback (SkFontMgr::matchFamilyStyleCharacter).
  sk_sp<SkFontMgr> fallback = moonbit_skia_default_font_mgr();
  if (!fallback) {
    return nullptr;
  }
  // Do not use SkShapers::CT::CoreText() directly here.  Its legacy
  // single-font overload owns the fallback iterator and has no way to pass
  // the validated manager above.
#if defined(MOUI_SKIA_HAS_SKSHAPER_HARFBUZZ) && defined(MOUI_SKIA_HAS_SKUNICODE_ICU)
  // Prefer HarfBuzz on Android/Linux — MakePrimitive alone has crashed with a
  // null deref when shaping denser layouts after rotation / catalog navigation.
  if (sk_sp<SkUnicode> unicode = SkUnicodes::ICU::Make()) {
    if (std::unique_ptr<SkShaper> shaper = SkShapers::HB::ShapeDontWrapOrReorder(
          unicode,
          fallback
        )) {
      return shaper;
    }
    if (std::unique_ptr<SkShaper> shaper = SkShapers::HB::ShapeThenWrap(
          unicode,
          fallback
        )) {
      return shaper;
    }
  }
#endif
#if defined(MOUI_SKIA_HAS_SKSHAPER_HEADERS)
  if (std::unique_ptr<SkShaper> shaper = SkShaper::Make(
        fallback
      )) {
    return shaper;
  }
  return SkShaper::MakePrimitive();
#else
  return nullptr;
#endif
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_is_null(MoonbitSkiaFont* wrapper) {
  return wrapper == nullptr || wrapper->font == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFont*
moonbit_skia_font_default(float size) {
  if (size <= 0.0f) {
    return moonbit_skia_make_font_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkTypeface> typeface = moonbit_skia_default_typeface();
  SkFont* font = typeface ? new SkFont(typeface, size) : new SkFont();
  if (!typeface) {
    font->setSize(size);
  }
  return moonbit_skia_make_font_wrapper(font);
#else
  (void)size;
  return moonbit_skia_make_font_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFont*
moonbit_skia_font_empty(float size) {
  if (size <= 0.0f) {
    return moonbit_skia_make_font_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFont* font = new SkFont();
  font->setTypeface(nullptr);
  font->setSize(size);
  return moonbit_skia_make_font_wrapper(font);
#else
  (void)size;
  return moonbit_skia_make_font_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFont*
moonbit_skia_font_from_typeface(MoonbitSkiaTypeface* typeface, float size) {
  if (typeface == nullptr || typeface->typeface == nullptr || size <= 0.0f) {
    return moonbit_skia_make_font_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFont* font = new SkFont(sk_ref_sp(typeface->typeface), size);
  return moonbit_skia_make_font_wrapper(font);
#else
  (void)size;
  return moonbit_skia_make_font_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_size(MoonbitSkiaFont* wrapper) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->font->getSize();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_font_set_size(MoonbitSkiaFont* wrapper, float size) {
  if (wrapper == nullptr || wrapper->font == nullptr || size <= 0.0f) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->font->setSize(size);
#else
  (void)size;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_utf8(MoonbitSkiaFont* wrapper, moonbit_bytes_t text) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->font->measureText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_count_text_utf8(MoonbitSkiaFont* wrapper, moonbit_bytes_t text) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  size_t glyph_count = wrapper->font->countText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
  if (glyph_count > static_cast<size_t>(INT32_MAX)) {
    return INT32_MAX;
  }
  return static_cast<int32_t>(glyph_count);
#else
  return 0;
#endif
}

#if defined(MOUI_SKIA_HAS_SKIA)
static bool moonbit_skia_font_text_to_glyphs_utf8_vector(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  std::vector<SkGlyphID>* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    glyphs == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return false;
  }

  size_t glyph_count = wrapper->font->countText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
  if (glyph_count == 0) {
    return false;
  }

  glyphs->resize(glyph_count);
  size_t copied = wrapper->font->textToGlyphs(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8,
    SkSpan<SkGlyphID>(glyphs->data(), glyphs->size())
  );
  if (copied == 0) {
    glyphs->clear();
    return false;
  }
  if (copied < glyphs->size()) {
    glyphs->resize(copied);
  }
  return true;
}

static int32_t moonbit_skia_font_text_to_glyphs_utf8_at(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index
) {
  if (index < 0) {
    return 0;
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return 0;
  }
  if (static_cast<size_t>(index) >= glyphs.size()) {
    return 0;
  }
  return static_cast<int32_t>(glyphs[static_cast<size_t>(index)]);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_text_to_glyphs_utf8_value(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_text_to_glyphs_utf8_at(wrapper, text, index);
#else
  (void)wrapper;
  (void)text;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGlyphIdArray*
moonbit_skia_font_text_to_glyphs_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(
    wrapper,
    text,
    &glyphs
  ) || glyphs.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_glyph_id_array(
      0,
      moonbit_empty_int16_array
    );
  }

  uint16_t* buffer = moonbit_skia_make_glyph_id_array_storage(
    static_cast<int32_t>(glyphs.size())
  );
  for (size_t i = 0; i < glyphs.size(); ++i) {
    buffer[i] = static_cast<uint16_t>(glyphs[i]);
  }
  return moonbit_skia_make_glyph_id_array(
    static_cast<int32_t>(glyphs.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  return moonbit_skia_make_glyph_id_array(
    0,
    moonbit_empty_int16_array
  );
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_width(MoonbitSkiaFont* wrapper, int32_t glyph) {
  if (wrapper == nullptr || wrapper->font == nullptr || glyph < 0) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->font->getWidth(static_cast<SkGlyphID>(glyph));
#else
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFloatArray*
moonbit_skia_font_glyph_widths(
  MoonbitSkiaFont* wrapper,
  MoonbitSkiaGlyphIdArray* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    glyphs == nullptr ||
    glyphs->length <= 0 ||
    glyphs->buffer == nullptr
  ) {
    return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  int32_t glyph_count = glyphs->length;
  float* buffer = moonbit_make_float_array_raw(glyph_count);
  for (int32_t i = 0; i < glyph_count; ++i) {
    buffer[i] = wrapper->font->getWidth(
      static_cast<SkGlyphID>(glyphs->buffer[i])
    );
  }
  return moonbit_skia_make_float_array(glyph_count, buffer);
#else
  return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPointArray*
moonbit_skia_font_text_glyph_positions_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin_x,
  float origin_y
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(
    wrapper,
    text,
    &glyphs
  ) || glyphs.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_point_array(
      0,
      reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
    );
  }

  std::vector<SkPoint> positions(glyphs.size());
  wrapper->font->getPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkPoint>(positions.data(), positions.size()),
    SkPoint::Make(origin_x, origin_y)
  );

  MoonbitSkiaPoint** buffer = moonbit_skia_make_point_array_storage(
    static_cast<int32_t>(positions.size())
  );
  for (size_t i = 0; i < positions.size(); ++i) {
    buffer[i] = moonbit_skia_make_point(positions[i].x(), positions[i].y());
  }
  return moonbit_skia_make_point_array(
    static_cast<int32_t>(positions.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  (void)origin_x;
  (void)origin_y;
  return moonbit_skia_make_point_array(
    0,
    reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
  );
#endif
}

#if defined(MOUI_SKIA_HAS_SKIA)
static SkPoint moonbit_skia_font_text_glyph_position_utf8_point(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
  if (index < 0) {
    return SkPoint::Make(0.0f, 0.0f);
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return SkPoint::Make(0.0f, 0.0f);
  }
  if (static_cast<size_t>(index) >= glyphs.size()) {
    return SkPoint::Make(0.0f, 0.0f);
  }

  std::vector<SkPoint> positions(glyphs.size());
  wrapper->font->getPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkPoint>(positions.data(), positions.size()),
    SkPoint::Make(origin_x, origin_y)
  );
  return positions[static_cast<size_t>(index)];
}

static bool moonbit_skia_font_text_glyph_x_positions_utf8_vector(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin,
  std::vector<SkScalar>* positions
) {
  if (positions == nullptr) {
    return false;
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return false;
  }

  positions->resize(glyphs.size());
  wrapper->font->getXPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkScalar>(positions->data(), positions->size()),
    origin
  );
  return true;
}

static float moonbit_skia_font_text_glyph_x_position_utf8_value(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin
) {
  if (index < 0) {
    return 0.0f;
  }

  std::vector<SkScalar> positions;
  if (!moonbit_skia_font_text_glyph_x_positions_utf8_vector(
    wrapper,
    text,
    origin,
    &positions
  )) {
    return 0.0f;
  }
  if (static_cast<size_t>(index) >= positions.size()) {
    return 0.0f;
  }
  return positions[static_cast<size_t>(index)];
}
#endif

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_position_utf8_x(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_text_glyph_position_utf8_point(
    wrapper,
    text,
    index,
    origin_x,
    origin_y
  ).x();
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin_x;
  (void)origin_y;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_position_utf8_y(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_text_glyph_position_utf8_point(
    wrapper,
    text,
    index,
    origin_x,
    origin_y
  ).y();
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin_x;
  (void)origin_y;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_x_position_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_text_glyph_x_position_utf8_value(
    wrapper,
    text,
    index,
    origin
  );
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFloatArray*
moonbit_skia_font_text_glyph_x_positions_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  std::vector<SkScalar> positions;
  if (!moonbit_skia_font_text_glyph_x_positions_utf8_vector(
    wrapper,
    text,
    origin,
    &positions
  ) || positions.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
  }

  float* buffer = moonbit_make_float_array_raw(
    static_cast<int32_t>(positions.size())
  );
  for (size_t i = 0; i < positions.size(); ++i) {
    buffer[i] = positions[i];
  }
  return moonbit_skia_make_float_array(
    static_cast<int32_t>(positions.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  (void)origin;
  return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShapedTextRun*
moonbit_skia_font_shape_text_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float width,
  int32_t left_to_right
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    Moonbit_array_length(text) <= 0 ||
    width <= 0.0f
  ) {
    return moonbit_skia_make_empty_shaped_text_run();
  }
#if defined(MOUI_SKIA_HAS_SKIA) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_HEADERS) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_LEGACY)
  // Cap layout width so a pathological call cannot force huge run buffers.
  // Callers that want "no wrap" still get effectively unconstrained layout.
  const float layout_width = width > 1.0e7f ? 1.0e7f : width;
  std::unique_ptr<SkShaper> shaper = moonbit_skia_make_shaper();
  if (shaper == nullptr) {
    return moonbit_skia_make_empty_shaped_text_run();
  }
  if (wrapper->font->getTypeface() == nullptr) {
    // Empty typeface fonts must not enter the shaper — observed as
    // SIGSEGV/null deref on Android after rotation / denser catalog layout.
    return moonbit_skia_make_empty_shaped_text_run();
  }

  MoonbitSkiaShaperRunHandler handler;
  shaper->shape(
    reinterpret_cast<const char*>(text),
    static_cast<size_t>(Moonbit_array_length(text)),
    *wrapper->font,
    left_to_right != 0,
    layout_width,
    &handler
  );
  if (!handler.ok()) {
    return moonbit_skia_make_empty_shaped_text_run();
  }

  int32_t glyph_count = handler.glyph_count();
  if (glyph_count <= 0 || glyph_count > 1000000) {
    return moonbit_skia_make_empty_shaped_text_run();
  }
  uint16_t* glyph_buffer = moonbit_skia_make_glyph_id_array_storage(
    glyph_count
  );
  MoonbitSkiaPoint** position_buffer = moonbit_skia_make_point_array_storage(
    glyph_count
  );
  int32_t* cluster_buffer = moonbit_make_int32_array_raw(glyph_count);
  if (
    glyph_buffer == nullptr ||
    position_buffer == nullptr ||
    cluster_buffer == nullptr
  ) {
    return moonbit_skia_make_empty_shaped_text_run();
  }
  const std::vector<SkGlyphID>& glyphs = handler.glyphs();
  const std::vector<SkPoint>& positions = handler.positions();
  const std::vector<uint32_t>& clusters = handler.clusters();
  if (
    glyphs.size() != static_cast<size_t>(glyph_count) ||
    positions.size() != static_cast<size_t>(glyph_count) ||
    clusters.size() != static_cast<size_t>(glyph_count)
  ) {
    return moonbit_skia_make_empty_shaped_text_run();
  }
  for (int32_t i = 0; i < glyph_count; ++i) {
    size_t index = static_cast<size_t>(i);
    glyph_buffer[index] = static_cast<uint16_t>(glyphs[index]);
    MoonbitSkiaPoint* point = moonbit_skia_make_point(
      positions[index].x(),
      positions[index].y()
    );
    if (point == nullptr) {
      return moonbit_skia_make_empty_shaped_text_run();
    }
    position_buffer[index] = point;
    cluster_buffer[index] = clusters[index] >
      static_cast<uint32_t>(std::numeric_limits<int32_t>::max())
        ? std::numeric_limits<int32_t>::max()
        : static_cast<int32_t>(clusters[index]);
  }
  return moonbit_skia_make_shaped_text_run(
    glyph_count,
    handler.advance_x(),
    handler.advance_y(),
    moonbit_skia_make_glyph_id_array(glyph_count, glyph_buffer),
    moonbit_skia_make_point_array(glyph_count, position_buffer),
    moonbit_skia_make_int32_array(glyph_count, cluster_buffer)
  );
#else
  (void)left_to_right;
  return moonbit_skia_make_empty_shaped_text_run();
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shaped_text_run_is_null(MoonbitSkiaShapedTextRun* run) {
  bool invalid = (
    run == nullptr ||
    run->glyph_count <= 0 ||
    run->glyphs == nullptr ||
    run->positions == nullptr ||
    run->clusters == nullptr ||
    run->glyphs->buffer == nullptr ||
    run->positions->buffer == nullptr ||
    run->clusters->buffer == nullptr ||
    run->glyphs->length != run->glyph_count ||
    run->positions->length != run->glyph_count ||
    run->clusters->length != run->glyph_count ||
    Moonbit_array_length(run->glyphs->buffer) != run->glyph_count ||
    Moonbit_array_length(run->positions->buffer) != run->glyph_count ||
    Moonbit_array_length(run->clusters->buffer) != run->glyph_count
  );
  if (invalid) {
    return true;
  }
  for (int32_t i = 0; i < run->glyph_count; ++i) {
    if (run->positions->buffer[i] == nullptr) {
      return true;
    }
  }
  return false;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shaped_text_run_glyph_count(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return 0;
  }
  return run->glyph_count;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_shaped_text_run_advance_x(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return 0.0f;
  }
  return run->advance_x;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_shaped_text_run_advance_y(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return 0.0f;
  }
  return run->advance_y;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGlyphIdArray*
moonbit_skia_shaped_text_run_glyphs(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return moonbit_skia_make_glyph_id_array(
      0,
      moonbit_empty_int16_array
    );
  }
  return run->glyphs;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shaped_text_run_glyph_value(
  MoonbitSkiaShapedTextRun* run,
  int32_t index
) {
  if (
    moonbit_skia_shaped_text_run_is_null(run) ||
    index < 0 ||
    index >= run->glyph_count
  ) {
    return 0;
  }
  return static_cast<int32_t>(run->glyphs->buffer[index]);
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPointArray*
moonbit_skia_shaped_text_run_positions(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return moonbit_skia_make_point_array(
      0,
      reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
    );
  }
  return run->positions;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_shaped_text_run_position_x(
  MoonbitSkiaShapedTextRun* run,
  int32_t index
) {
  if (
    moonbit_skia_shaped_text_run_is_null(run) ||
    index < 0 ||
    index >= run->glyph_count ||
    run->positions->buffer[index] == nullptr
  ) {
    return 0.0f;
  }
  return run->positions->buffer[index]->x;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_shaped_text_run_position_y(
  MoonbitSkiaShapedTextRun* run,
  int32_t index
) {
  if (
    moonbit_skia_shaped_text_run_is_null(run) ||
    index < 0 ||
    index >= run->glyph_count ||
    run->positions->buffer[index] == nullptr
  ) {
    return 0.0f;
  }
  return run->positions->buffer[index]->y;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaInt32Array*
moonbit_skia_shaped_text_run_clusters(MoonbitSkiaShapedTextRun* run) {
  if (moonbit_skia_shaped_text_run_is_null(run)) {
    return moonbit_skia_make_int32_array(0, moonbit_empty_int32_array);
  }
  return run->clusters;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shaped_text_run_cluster_value(
  MoonbitSkiaShapedTextRun* run,
  int32_t index
) {
  if (
    moonbit_skia_shaped_text_run_is_null(run) ||
    index < 0 ||
    index >= run->glyph_count
  ) {
    return 0;
  }
  return run->clusters->buffer[index];
}

#if defined(MOUI_SKIA_HAS_SKIA)
static SkRect moonbit_skia_font_glyph_bounds_rect(
  MoonbitSkiaFont* wrapper,
  int32_t glyph
) {
  if (wrapper == nullptr || wrapper->font == nullptr || glyph < 0) {
    return SkRect::MakeEmpty();
  }
  return wrapper->font->getBounds(static_cast<SkGlyphID>(glyph), nullptr);
}
#endif

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_left(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).left();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_top(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).top();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_right(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).right();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_bottom(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).bottom();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaRectArray*
moonbit_skia_font_glyph_bounds_many(
  MoonbitSkiaFont* wrapper,
  MoonbitSkiaGlyphIdArray* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    glyphs == nullptr ||
    glyphs->length <= 0 ||
    glyphs->buffer == nullptr
  ) {
    return moonbit_skia_make_rect_array(
      0,
      reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    );
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  int32_t glyph_count = glyphs->length;
  std::vector<SkGlyphID> sk_glyphs(static_cast<size_t>(glyph_count));
  for (int32_t i = 0; i < glyph_count; ++i) {
    sk_glyphs[static_cast<size_t>(i)] = static_cast<SkGlyphID>(glyphs->buffer[i]);
  }

  std::vector<SkRect> sk_bounds(sk_glyphs.size());
  wrapper->font->getBounds(
    SkSpan<const SkGlyphID>(sk_glyphs.data(), sk_glyphs.size()),
    SkSpan<SkRect>(sk_bounds.data(), sk_bounds.size()),
    nullptr
  );

  MoonbitSkiaRect** buffer = moonbit_skia_make_rect_array_storage(glyph_count);
  for (size_t i = 0; i < sk_bounds.size(); ++i) {
    buffer[i] = moonbit_skia_make_rect(
      sk_bounds[i].left(),
      sk_bounds[i].top(),
      sk_bounds[i].right(),
      sk_bounds[i].bottom()
    );
  }
  return moonbit_skia_make_rect_array(glyph_count, buffer);
#else
  return moonbit_skia_make_rect_array(
    0,
    reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
  );
#endif
}

#if defined(MOUI_SKIA_HAS_SKIA)
static int32_t moonbit_skia_font_measure_text_bounds_utf8_rect(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  SkRect* bounds
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    bounds == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0;
  }
  wrapper->font->measureText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8,
    bounds
  );
  return 1;
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_measure_text_bounds_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  return moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds);
#else
  (void)wrapper;
  (void)text;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_left(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.left();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_top(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.top();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_right(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.right();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_bottom(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.bottom();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_metrics_value(MoonbitSkiaFont* wrapper, int32_t metric) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFontMetrics metrics = moonbit_skia_get_font_metrics(wrapper);
  switch (metric) {
    case 0: return metrics.fTop;
    case 1: return metrics.fAscent;
    case 2: return metrics.fDescent;
    case 3: return metrics.fBottom;
    case 4: return metrics.fLeading;
    case 5: return metrics.fAvgCharWidth;
    case 6: return metrics.fMaxCharWidth;
    case 7: return metrics.fXMin;
    case 8: return metrics.fXMax;
    case 9: return metrics.fXHeight;
    case 10: return metrics.fCapHeight;
    case 11: return metrics.fUnderlineThickness;
    case 12: return metrics.fUnderlinePosition;
    case 13: return metrics.fStrikeoutThickness;
    case 14: return metrics.fStrikeoutPosition;
    default: return 0.0f;
  }
#else
  (void)metric;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_metrics_has(MoonbitSkiaFont* wrapper, int32_t metric) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFontMetrics metrics = moonbit_skia_get_font_metrics(wrapper);
  SkScalar value = 0;
  switch (metric) {
    case 0:
    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
    case 6:
    case 7:
    case 8:
    case 9:
    case 10:
      return 1;
    case 11: return metrics.hasUnderlineThickness(&value);
    case 12: return metrics.hasUnderlinePosition(&value);
    case 13: return metrics.hasStrikeoutThickness(&value);
    case 14: return metrics.hasStrikeoutPosition(&value);
    case 15: return metrics.hasBounds();
    default: return 0;
  }
#else
  (void)metric;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_null(MoonbitSkiaTypeface* wrapper) {
  return wrapper == nullptr || wrapper->typeface == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_mgr_is_null(MoonbitSkiaFontMgr* wrapper) {
  return wrapper == nullptr || wrapper->font_mgr == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFontMgr*
moonbit_skia_font_mgr_default(void) {
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkFontMgr> font_mgr = moonbit_skia_default_font_mgr();
  if (!font_mgr) {
    return moonbit_skia_make_font_mgr_wrapper(nullptr);
  }
  return moonbit_skia_make_font_mgr_wrapper(font_mgr.release());
#else
  return moonbit_skia_make_font_mgr_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_mgr_count_families(MoonbitSkiaFontMgr* wrapper) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  int count = wrapper->font_mgr->countFamilies();
  return count < 0 ? 0 : count;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_font_mgr_family_name(MoonbitSkiaFontMgr* wrapper, int32_t index) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr || index < 0) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  int count = wrapper->font_mgr->countFamilies();
  if (index >= count) {
    return moonbit_make_bytes(0, 0);
  }
  SkString family_name;
  wrapper->font_mgr->getFamilyName(index, &family_name);
  return moonbit_skia_make_bytes_from_sk_string(family_name);
#else
  (void)index;
  return moonbit_make_bytes(0, 0);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_font_mgr_match_family_style(
  MoonbitSkiaFontMgr* wrapper,
  moonbit_bytes_t family_name,
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  std::string family_name_text = moonbit_skia_bytes_to_string(family_name);
  const char* family = family_name_text.empty()
    ? nullptr
    : family_name_text.c_str();
  sk_sp<SkTypeface> typeface = wrapper->font_mgr->matchFamilyStyle(
    family,
    moonbit_skia_font_style(weight, width, slant)
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)family_name;
  (void)weight;
  (void)width;
  (void)slant;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_font_mgr_match_family_style_character(
  MoonbitSkiaFontMgr* wrapper,
  moonbit_bytes_t family_name,
  moonbit_bytes_t language_tag,
  int32_t character,
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  if (
    wrapper == nullptr ||
    wrapper->font_mgr == nullptr ||
    character <= 0
  ) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  std::string family_name_text = moonbit_skia_bytes_to_string(family_name);
  const char* family = family_name_text.empty()
    ? nullptr
    : family_name_text.c_str();
  std::string language_tag_text = moonbit_skia_bytes_to_string(language_tag);
  const char* languages[1] = {nullptr};
  int language_count = 0;
  if (!language_tag_text.empty()) {
    languages[0] = language_tag_text.c_str();
    language_count = 1;
  }
  const char** language_data = language_count == 0 ? nullptr : languages;
  sk_sp<SkTypeface> typeface =
    wrapper->font_mgr->matchFamilyStyleCharacter(
      family,
      moonbit_skia_font_style(weight, width, slant),
      language_data,
      language_count,
      static_cast<SkUnichar>(character)
    );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)family_name;
  (void)language_tag;
  (void)weight;
  (void)width;
  (void)slant;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_default(void) {
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkTypeface> typeface = moonbit_skia_default_typeface();
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

#if defined(MOUI_SKIA_HAS_SKIA)
// Embedded-font registry: family name -> typeface. Populated by
// moonbit_skia_typeface_register_data and consulted by paragraph layout
// (skia_stub_paragraph.cpp) so app-registered font data resolves by name.
static std::map<std::string, sk_sp<SkTypeface>> g_moui_skia_embedded_typefaces;

sk_sp<SkTypeface> moonbit_skia_embedded_typeface_for_name(
  const std::string& name
) {
  auto it = g_moui_skia_embedded_typefaces.find(name);
  if (it == g_moui_skia_embedded_typefaces.end()) {
    return nullptr;
  }
  return it->second;
}
#endif

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_from_data(moonbit_bytes_t data, int32_t index) {
  if (data == nullptr || Moonbit_array_length(data) <= 0 || index < 0) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkFontMgr> font_mgr = moonbit_skia_default_font_mgr();
  if (!font_mgr) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  sk_sp<SkData> font_data = SkData::MakeWithCopy(
    static_cast<const void*>(data),
    static_cast<size_t>(Moonbit_array_length(data))
  );
  sk_sp<SkTypeface> typeface = font_mgr->makeFromData(font_data, index);
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)index;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_register_data(
  moonbit_bytes_t alias,
  moonbit_bytes_t data,
  int32_t index
) {
  if (
    alias == nullptr ||
    Moonbit_array_length(alias) <= 0 ||
    data == nullptr ||
    Moonbit_array_length(data) <= 0 ||
    index < 0
  ) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkFontMgr> font_mgr = moonbit_skia_default_font_mgr();
  if (!font_mgr) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  sk_sp<SkData> font_data = SkData::MakeWithCopy(
    static_cast<const void*>(data),
    static_cast<size_t>(Moonbit_array_length(data))
  );
  sk_sp<SkTypeface> typeface = font_mgr->makeFromData(font_data, index);
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  std::string alias_text = moonbit_skia_bytes_to_string(alias);
  SkString family_name;
  typeface->getFamilyName(&family_name);
  // Register under both the app-provided alias and the font's own family
  // name, so paragraph layout matches either spelling.
  g_moui_skia_embedded_typefaces[alias_text] = typeface;
  if (family_name.size() > 0) {
    g_moui_skia_embedded_typefaces[family_name.c_str()] = typeface;
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)index;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_clone_variation(
  MoonbitSkiaTypeface* wrapper,
  moonbit_bytes_t axis,
  float value
) {
  if (
    wrapper == nullptr ||
    wrapper->typeface == nullptr ||
    axis == nullptr ||
    Moonbit_array_length(axis) < 4
  ) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  // Read the current variation coordinates so clones compose.
  using SkVariationCoordinate =
    SkFontArguments::VariationPosition::Coordinate;
  std::vector<SkVariationCoordinate> coordinates;
  int existing_count = wrapper->typeface->getVariationDesignPosition(
    SkSpan<SkVariationCoordinate>(nullptr, 0)
  );
  if (existing_count > 0) {
    coordinates.resize(static_cast<size_t>(existing_count));
    int filled = wrapper->typeface->getVariationDesignPosition(
      SkSpan<SkVariationCoordinate>(coordinates.data(), coordinates.size())
    );
    if (filled < 0) {
      coordinates.clear();
    } else {
      coordinates.resize(static_cast<size_t>(filled));
    }
  }
  uint32_t tag = 0;
  for (int i = 0; i < 4; ++i) {
    tag = (tag << 8) | static_cast<uint8_t>(axis[i]);
  }
  // Replace an existing coordinate with the same tag, then append.
  bool replaced = false;
  for (auto& coordinate : coordinates) {
    if (coordinate.axis == tag) {
      coordinate.value = value;
      replaced = true;
      break;
    }
  }
  if (!replaced) {
    coordinates.push_back({tag, value});
  }
  SkFontArguments arguments;
  arguments.setVariationDesignPosition(
    {coordinates.data(), static_cast<int>(coordinates.size())}
  );
  sk_sp<SkTypeface> clone = wrapper->typeface->makeClone(arguments);
  if (!clone) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(clone.release());
#else
  (void)value;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_from_name(
  moonbit_bytes_t family_name,
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  if (family_name == nullptr || Moonbit_array_length(family_name) <= 0) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  std::string family_name_text = moonbit_skia_bytes_to_string(family_name);
  sk_sp<SkTypeface> typeface = moonbit_skia_typeface_from_family(
    family_name_text.c_str(),
    moonbit_skia_font_style(weight, width, slant)
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)weight;
  (void)width;
  (void)slant;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_from_file(moonbit_bytes_t path, int32_t index) {
  if (path == nullptr || Moonbit_array_length(path) <= 0 || index < 0) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkFontMgr> font_mgr = moonbit_skia_default_font_mgr();
  if (!font_mgr) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  std::string path_text = moonbit_skia_bytes_to_string(path);
  sk_sp<SkTypeface> typeface = font_mgr->makeFromFile(
    path_text.c_str(),
    index
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)index;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_bold(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->typeface->isBold();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_italic(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->typeface->isItalic();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_fixed_pitch(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->typeface->isFixedPitch();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_typeface_family_name(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkString family_name;
  wrapper->typeface->getFamilyName(&family_name);
  return moonbit_skia_make_bytes_from_sk_string(family_name);
#else
  return moonbit_make_bytes(0, 0);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_has_color_glyphs(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return (wrapper->typeface->getTableSize(SkSetFourByteTag('C','O','L','R')) > 0 ||
          wrapper->typeface->getTableSize(SkSetFourByteTag('s','b','i','x')) > 0 ||
          wrapper->typeface->getTableSize(SkSetFourByteTag('C','B','D','T')) > 0 ||
          wrapper->typeface->getTableSize(SkSetFourByteTag('S','V','G',' ')) > 0)
         ? 1 : 0;
#else
  return 0;
#endif
}
