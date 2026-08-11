#include "skia_stub_common.h"

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
#if __has_include("modules/skparagraph/include/TypefaceFontProvider.h")
#include "modules/skparagraph/include/TypefaceFontProvider.h"
#define MOUI_SKIA_HAS_TYPEFACE_FONT_PROVIDER 1
#endif
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

#if defined(MOUI_SKIA_HAS_TYPEFACE_FONT_PROVIDER)
// If `family` names an app-registered embedded font, register it on a
// TypefaceFontProvider and use it as the asset font manager so paragraph
// layout resolves the family from the embedded data.
static sk_sp<FontCollection> moonbit_skia_paragraph_font_collection(
  const std::string& family
) {
  sk_sp<FontCollection> font_collection = sk_make_sp<FontCollection>();
  sk_sp<SkTypeface> embedded = moonbit_skia_embedded_typeface_for_name(family);
  if (embedded) {
    sk_sp<skia::textlayout::TypefaceFontProvider> provider =
      sk_make_sp<skia::textlayout::TypefaceFontProvider>();
    SkString family_name;
    embedded->getFamilyName(&family_name);
    if (family_name.size() > 0) {
      provider->registerTypeface(embedded, family_name);
    }
    provider->registerTypeface(embedded, SkString(family.data(), family.size()));
    font_collection->setAssetFontManager(provider);
  }
  font_collection->setDefaultFontManager(moonbit_skia_default_font_mgr());
  return font_collection;
}
#endif

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
  std::string family;
  if (moonbit_skia_paragraph_has_family(family_name)) {
    family = moonbit_skia_bytes_to_string(family_name);
  }
  sk_sp<FontCollection> font_collection =
    moonbit_skia_paragraph_font_collection(family);

  TextStyle text_style;
  text_style.setFontSize(size);
  text_style.setColor(SK_ColorBLACK);
  text_style.setFontStyle(SkFontStyle(
    std::max(1, std::min(1000, weight)),
    std::max(1, std::min(9, width)),
    moonbit_skia_paragraph_slant(slant)
  ));
#if !defined(__linux__)
  if (moonbit_skia_paragraph_has_family(family_name)) {
    std::string family = moonbit_skia_bytes_to_string(family_name);
    std::vector<SkString> families;
    families.emplace_back(family.data(), family.size());
    text_style.setFontFamilies(families);
  }
#else
  (void)family_name;
#endif

  ParagraphStyle paragraph_style;
  paragraph_style.setTextDirection(
    moonbit_skia_paragraph_direction(left_to_right)
  );
  paragraph_style.setMaxLines(std::numeric_limits<size_t>::max());
  paragraph_style.setEllipsis(SkString());
  paragraph_style.setTextStyle(text_style);

  sk_sp<SkUnicode> unicode = moonbit_skia_shared_icu_unicode();
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

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
static std::vector<TextBox> moonbit_skia_paragraph_text_boxes_utf8_collect(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end
) {
  if (wrapper == nullptr || wrapper->paragraph == nullptr) {
    return {};
  }
  if (start < 0 || end <= start) {
    return {};
  }
  return wrapper->paragraph->getRectsForRange(
    static_cast<unsigned>(start),
    static_cast<unsigned>(end),
    RectHeightStyle::kMax,
    RectWidthStyle::kTight
  );
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_text_boxes_utf8_count(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (boxes.size() > static_cast<size_t>(INT32_MAX)) {
    return 0;
  }
  return static_cast<int32_t>(boxes.size());
#else
  (void)wrapper;
  (void)start;
  (void)end;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_text_boxes_utf8_at_left(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (index < 0 || static_cast<size_t>(index) >= boxes.size()) {
    return 0.0f;
  }
  return boxes[static_cast<size_t>(index)].rect.left();
#else
  (void)wrapper;
  (void)start;
  (void)end;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_text_boxes_utf8_at_top(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (index < 0 || static_cast<size_t>(index) >= boxes.size()) {
    return 0.0f;
  }
  return boxes[static_cast<size_t>(index)].rect.top();
#else
  (void)wrapper;
  (void)start;
  (void)end;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_text_boxes_utf8_at_right(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (index < 0 || static_cast<size_t>(index) >= boxes.size()) {
    return 0.0f;
  }
  return boxes[static_cast<size_t>(index)].rect.right();
#else
  (void)wrapper;
  (void)start;
  (void)end;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_paragraph_text_boxes_utf8_at_bottom(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (index < 0 || static_cast<size_t>(index) >= boxes.size()) {
    return 0.0f;
  }
  return boxes[static_cast<size_t>(index)].rect.bottom();
#else
  (void)wrapper;
  (void)start;
  (void)end;
  (void)index;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_text_box_directions_utf8_count(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (boxes.size() > static_cast<size_t>(INT32_MAX)) {
    return 0;
  }
  return static_cast<int32_t>(boxes.size());
#else
  (void)wrapper;
  (void)start;
  (void)end;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_paragraph_text_box_directions_utf8_at(
  MoonbitSkiaParagraph* wrapper,
  int32_t start,
  int32_t end,
  int32_t index
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  std::vector<TextBox> boxes = moonbit_skia_paragraph_text_boxes_utf8_collect(
    wrapper,
    start,
    end
  );
  if (index < 0 || static_cast<size_t>(index) >= boxes.size()) {
    return 1;
  }
  return boxes[static_cast<size_t>(index)].direction == TextDirection::kRtl ? 0 : 1;
#else
  (void)wrapper;
  (void)start;
  (void)end;
  (void)index;
  return 1;
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

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_draw_paragraph(
  MoonbitSkiaCanvas* canvas_wrapper,
  MoonbitSkiaParagraph* paragraph_wrapper,
  float x,
  float y
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  if (
    canvas_wrapper == nullptr ||
    canvas_wrapper->canvas == nullptr ||
    paragraph_wrapper == nullptr ||
    paragraph_wrapper->paragraph == nullptr
  ) {
    return 0;
  }
  paragraph_wrapper->paragraph->paint(canvas_wrapper->canvas, x, y);
  return 1;
#else
  (void)canvas_wrapper;
  (void)paragraph_wrapper;
  (void)x;
  (void)y;
  return 0;
#endif
}
