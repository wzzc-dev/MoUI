#include "skia_stub_common.h"

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
using skia::textlayout::Affinity;
using skia::textlayout::FontCollection;
using skia::textlayout::LineMetrics;
using skia::textlayout::Paragraph;
using skia::textlayout::ParagraphBuilder;
using skia::textlayout::ParagraphStyle;
using skia::textlayout::PositionWithAffinity;
using skia::textlayout::RectHeightStyle;
using skia::textlayout::RectWidthStyle;
using skia::textlayout::TextBox;
using skia::textlayout::TextDirection;
using skia::textlayout::TextStyle;

static int32_t moonbit_skia_clamp_text_index(size_t value) {
  if (value > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
    return std::numeric_limits<int32_t>::max();
  }
  return static_cast<int32_t>(value);
}

static bool moonbit_skia_paragraph_line_metrics(
  MoonbitSkiaParagraph* wrapper,
  int32_t index,
  LineMetrics* metric
) {
  if (wrapper == nullptr || wrapper->paragraph == nullptr || metric == nullptr || index < 0) {
    return false;
  }
  return wrapper->paragraph->getLineMetricsAt(index, metric);
}

static TextDirection moonbit_skia_paragraph_direction(int32_t left_to_right) {
  return left_to_right != 0 ? TextDirection::kLtr : TextDirection::kRtl;
}

static SkFontStyle::Slant moonbit_skia_paragraph_slant(int32_t slant) {
  switch (slant) {
    case 1:
      return SkFontStyle::kItalic_Slant;
    case 2:
      return SkFontStyle::kOblique_Slant;
    default:
      return SkFontStyle::kUpright_Slant;
  }
}

static bool moonbit_skia_paragraph_has_family(moonbit_bytes_t family_name) {
  return family_name != nullptr && Moonbit_array_length(family_name) > 0;
}
#endif

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaParagraph*
moonbit_skia_paragraph_layout_utf8(
  moonbit_bytes_t text,
  moonbit_bytes_t family_name,
  float size,
  int32_t weight,
  int32_t width,
  int32_t slant,
  float max_width,
  int32_t left_to_right
) {
  if (
    text == nullptr ||
    Moonbit_array_length(text) <= 0 ||
    size <= 0.0f ||
    max_width <= 0.0f
  ) {
    return moonbit_skia_make_paragraph_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  sk_sp<FontCollection> font_collection = sk_make_sp<FontCollection>();
  font_collection->setDefaultFontManager(moonbit_skia_default_font_mgr());

  ParagraphStyle paragraph_style;
  paragraph_style.setTextDirection(
    moonbit_skia_paragraph_direction(left_to_right)
  );

  TextStyle text_style;
  text_style.setFontSize(size);
  text_style.setFontStyle(SkFontStyle(
    std::max(1, std::min(1000, weight)),
    std::max(1, std::min(9, width)),
    moonbit_skia_paragraph_slant(slant)
  ));
  if (moonbit_skia_paragraph_has_family(family_name)) {
    std::vector<SkString> families;
    families.emplace_back(reinterpret_cast<const char*>(family_name));
    text_style.setFontFamilies(families);
  }

  sk_sp<SkUnicode> unicode = SkUnicodes::ICU::Make();
  if (unicode == nullptr) {
    return moonbit_skia_make_paragraph_wrapper(nullptr);
  }
  std::unique_ptr<ParagraphBuilder> builder = ParagraphBuilder::make(
    paragraph_style,
    font_collection,
    std::move(unicode)
  );
  if (builder == nullptr) {
    return moonbit_skia_make_paragraph_wrapper(nullptr);
  }
  builder->pushStyle(text_style);
  builder->addText(
    reinterpret_cast<const char*>(text),
    static_cast<size_t>(Moonbit_array_length(text))
  );
  std::unique_ptr<Paragraph> paragraph = builder->Build();
  if (paragraph == nullptr) {
    return moonbit_skia_make_paragraph_wrapper(nullptr);
  }
  paragraph->layout(max_width);
  return moonbit_skia_make_paragraph_wrapper(paragraph.release());
#else
  (void)family_name;
  (void)weight;
  (void)width;
  (void)slant;
  (void)left_to_right;
  return moonbit_skia_make_paragraph_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_is_null(MoonbitSkiaParagraph* wrapper) {
  return wrapper == nullptr || wrapper->paragraph == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_width(MoonbitSkiaParagraph* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return 0.0f;
  }
  return wrapper->paragraph->getLongestLine();
#else
  (void)wrapper;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_height(MoonbitSkiaParagraph* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return 0.0f;
  }
  return wrapper->paragraph->getHeight();
#else
  (void)wrapper;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_count(MoonbitSkiaParagraph* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return 0;
  }
  std::vector<LineMetrics> metrics;
  wrapper->paragraph->getLineMetrics(metrics);
  return moonbit_skia_clamp_text_index(metrics.size());
#else
  (void)wrapper;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_start(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? moonbit_skia_clamp_text_index(metric.fStartIndex)
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_end(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? moonbit_skia_clamp_text_index(metric.fEndIndex)
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_end_excluding_whitespace(
  MoonbitSkiaParagraph* wrapper,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? moonbit_skia_clamp_text_index(metric.fEndExcludingWhitespaces)
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_end_including_newline(
  MoonbitSkiaParagraph* wrapper,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? moonbit_skia_clamp_text_index(metric.fEndIncludingNewline)
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_number(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fLineNumber
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_line_hard_break(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? static_cast<int32_t>(metric.fHardBreak)
    : 0;
#else
  (void)wrapper;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_left(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fLeft
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_width(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fWidth
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_baseline(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fBaseline
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_ascent(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fAscent
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_descent(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fDescent
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_line_height(MoonbitSkiaParagraph* wrapper, int32_t index) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  LineMetrics metric;
  return moonbit_skia_paragraph_line_metrics(wrapper, index, &metric)
    ? metric.fHeight
    : 0.0f;
#else
  (void)wrapper;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaRectArray*
moonbit_skia_paragraph_text_boxes_utf8(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end
) {
  if (start < 0 || end <= start) {
    return moonbit_skia_make_rect_array(
      0,
      reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    );
  }
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return moonbit_skia_make_rect_array(
      0,
      reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    );
  }
  std::vector<TextBox> boxes = wrapper->paragraph->getRectsForRange(
    static_cast<unsigned>(start),
    static_cast<unsigned>(end),
    RectHeightStyle::kMax,
    RectWidthStyle::kTight
  );
  if (boxes.empty() || boxes.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_rect_array(
      0,
      reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    );
  }
  MoonbitSkiaRect** buffer = moonbit_skia_make_rect_array_storage(
    static_cast<int32_t>(boxes.size())
  );
  for (size_t i = 0; i < boxes.size(); ++i) {
    const SkRect& rect = boxes[i].rect;
    buffer[i] = moonbit_skia_make_rect(
      rect.left(),
      rect.top(),
      rect.right(),
      rect.bottom()
    );
  }
  return moonbit_skia_make_rect_array(static_cast<int32_t>(boxes.size()), buffer);
#else
  (void)wrapper;
  return moonbit_skia_make_rect_array(
    0,
    reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
  );
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaInt32Array*
moonbit_skia_paragraph_text_box_directions_utf8(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end
) {
  if (start < 0 || end <= start) {
    return moonbit_skia_make_int32_array(0, moonbit_empty_int32_array);
  }
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return moonbit_skia_make_int32_array(0, moonbit_empty_int32_array);
  }
  std::vector<TextBox> boxes = wrapper->paragraph->getRectsForRange(
    static_cast<unsigned>(start),
    static_cast<unsigned>(end),
    RectHeightStyle::kMax,
    RectWidthStyle::kTight
  );
  if (boxes.empty() || boxes.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_int32_array(0, moonbit_empty_int32_array);
  }
  int32_t* buffer = moonbit_make_int32_array_raw(
    static_cast<int32_t>(boxes.size())
  );
  for (size_t i = 0; i < boxes.size(); ++i) {
    buffer[i] = boxes[i].direction == TextDirection::kRtl ? 0 : 1;
  }
  return moonbit_skia_make_int32_array(
    static_cast<int32_t>(boxes.size()),
    buffer
  );
#else
  (void)wrapper;
  return moonbit_skia_make_int32_array(0, moonbit_empty_int32_array);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_hit_test_utf8_offset(
  MoonbitSkiaParagraph* wrapper,
  float x,
  float y
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return 0;
  }
  PositionWithAffinity position = wrapper->paragraph->getGlyphPositionAtCoordinate(x, y);
  return moonbit_skia_clamp_text_index(position.position);
#else
  (void)wrapper;
  (void)x;
  (void)y;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_hit_test_utf8_downstream(
  MoonbitSkiaParagraph* wrapper,
  float x,
  float y
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return 1;
  }
  PositionWithAffinity position = wrapper->paragraph->getGlyphPositionAtCoordinate(x, y);
  return position.affinity == Affinity::kDownstream ? 1 : 0;
#else
  (void)wrapper;
  (void)x;
  (void)y;
  return 1;
#endif
}
