#include "skia_stub_common.h"

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PATH_BUILDER)
template <typename Mutate>
static void moonbit_skia_path_mutate(
  MoonbitSkiaPath* wrapper,
  Mutate mutate
) {
  SkPathBuilder builder(*wrapper->path);
  mutate(builder);
  *wrapper->path = builder.snapshot();
}
#endif
extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPath* moonbit_skia_path_new(void) {
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_make_path_wrapper(new SkPath());
#else
  return moonbit_skia_make_path_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_null(MoonbitSkiaPath* wrapper) {
  return wrapper == nullptr || wrapper->path == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_reset(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  *wrapper->path = SkPath();
#else
  wrapper->path->reset();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_rewind(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  *wrapper->path = SkPath();
#else
  wrapper->path->rewind();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_set_fill_type(
  MoonbitSkiaPath* wrapper,
  int32_t fill_type
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeFillType(
    static_cast<SkPathFillType>(fill_type)
  );
#else
  wrapper->path->setFillType(static_cast<SkPathFillType>(fill_type));
#endif
#else
  (void)fill_type;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_fill_type(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return static_cast<int32_t>(wrapper->path->getFillType());
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_inverse_fill_type(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->isInverseFillType();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_move_to(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.moveTo(x, y);
  });
#else
  wrapper->path->moveTo(x, y);
#endif
#else
  (void)x;
  (void)y;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_line_to(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.lineTo(x, y);
  });
#else
  wrapper->path->lineTo(x, y);
#endif
#else
  (void)x;
  (void)y;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_quad_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.quadTo(x1, y1, x2, y2);
  });
#else
  wrapper->path->quadTo(x1, y1, x2, y2);
#endif
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_conic_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2,
  float weight
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.conicTo(x1, y1, x2, y2, weight);
  });
#else
  wrapper->path->conicTo(x1, y1, x2, y2, weight);
#endif
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
  (void)weight;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_cubic_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2,
  float x3,
  float y3
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.cubicTo(x1, y1, x2, y2, x3, y3);
  });
#else
  wrapper->path->cubicTo(x1, y1, x2, y2, x3, y3);
#endif
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
  (void)x3;
  (void)y3;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_close(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [](SkPathBuilder& builder) {
    builder.close();
  });
#else
  wrapper->path->close();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_rect(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRect(
      SkRect::MakeLTRB(left, top, right, bottom),
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_oval(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addOval(
      SkRect::MakeLTRB(left, top, right, bottom),
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addOval(
    SkRect::MakeLTRB(left, top, right, bottom),
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_circle(
  MoonbitSkiaPath* wrapper,
  float x,
  float y,
  float radius,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addCircle(
      x,
      y,
      radius,
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addCircle(
    x,
    y,
    radius,
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)x;
  (void)y;
  (void)radius;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_round_rect(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float rx,
  float ry,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  SkRRect rrect = SkRRect::MakeRectXY(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry
  );
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRRect(rrect, static_cast<SkPathDirection>(direction));
  });
#else
  wrapper->path->addRoundRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry,
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)rx;
  (void)ry;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_rrect(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float upper_left_width,
  float upper_left_height,
  float upper_right_width,
  float upper_right_height,
  float lower_right_width,
  float lower_right_height,
  float lower_left_width,
  float lower_left_height,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRRect rrect = moonbit_skia_make_rrect(
    left,
    top,
    right,
    bottom,
    upper_left_width,
    upper_left_height,
    upper_right_width,
    upper_right_height,
    lower_right_width,
    lower_right_height,
    lower_left_width,
    lower_left_height
  );
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRRect(rrect, static_cast<SkPathDirection>(direction));
  });
#else
  wrapper->path->addRRect(rrect, static_cast<SkPathDirection>(direction));
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)upper_left_width;
  (void)upper_left_height;
  (void)upper_right_width;
  (void)upper_right_height;
  (void)lower_right_width;
  (void)lower_right_height;
  (void)lower_left_width;
  (void)lower_left_height;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_transform(
  MoonbitSkiaPath* wrapper,
  float scale_x,
  float skew_x,
  float trans_x,
  float skew_y,
  float scale_y,
  float trans_y,
  float persp_0,
  float persp_1,
  float persp_2
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkMatrix matrix;
  matrix.setAll(
    scale_x,
    skew_x,
    trans_x,
    skew_y,
    scale_y,
    trans_y,
    persp_0,
    persp_1,
    persp_2
  );
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeTransform(matrix);
#else
  wrapper->path->transform(matrix);
#endif
#else
  (void)scale_x;
  (void)skew_x;
  (void)trans_x;
  (void)skew_y;
  (void)scale_y;
  (void)trans_y;
  (void)persp_0;
  (void)persp_1;
  (void)persp_2;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_offset(
  MoonbitSkiaPath* wrapper,
  float dx,
  float dy
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(MOUI_SKIA_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeOffset(dx, dy);
#else
  wrapper->path->offset(dx, dy);
#endif
#else
  (void)dx;
  (void)dy;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_path_contains(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->contains(x, y);
#else
  (void)x;
  (void)y;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_empty(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 1;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->isEmpty();
#else
  return 1;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_finite(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 1;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->isFinite();
#else
  return 1;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_count_points(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->countPoints();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_count_verbs(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->countVerbs();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_segment_masks(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->getSegmentMasks();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_last_contour_closed(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->isLastContourClosed();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_has_last_point(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint point;
  return wrapper->path->getLastPt(&point);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_last_point_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint point;
  if (wrapper->path->getLastPt(&point)) {
    return point.x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_last_point_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint point;
  if (wrapper->path->getLastPt(&point)) {
    return point.y();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_line(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2];
  return wrapper->path->isLine(points);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_start_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[0].x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_start_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[0].y();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_end_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[1].x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_end_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[1].y();
  }
#endif
  return 0.0f;
}

#if defined(MOUI_SKIA_HAS_SKIA)
static int moonbit_skia_path_get_rect(
  MoonbitSkiaPath* wrapper,
  SkRect* rect,
  bool* is_closed,
  SkPathDirection* direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
  return wrapper->path->isRect(rect, is_closed, direction);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_rect(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  return moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction);
#else
  (void)wrapper;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_left(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.left();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_top(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.top();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_right(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.right();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_bottom(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.bottom();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_rect_is_closed(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return is_closed;
  }
#else
  (void)wrapper;
#endif
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_rect_direction(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return static_cast<int32_t>(direction);
  }
#else
  (void)wrapper;
#endif
  return 0;
}

#if defined(MOUI_SKIA_HAS_SKIA)
static int moonbit_skia_path_get_oval(MoonbitSkiaPath* wrapper, SkRect* bounds) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
  return wrapper->path->isOval(bounds);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_oval(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  return moonbit_skia_path_get_oval(wrapper, &bounds);
#else
  (void)wrapper;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_left(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.left();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_top(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.top();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_right(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.right();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_bottom(MoonbitSkiaPath* wrapper) {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.bottom();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_left(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->getBounds().left();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_top(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->getBounds().top();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_right(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->getBounds().right();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_bottom(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->getBounds().bottom();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_left(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->computeTightBounds().left();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_top(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->computeTightBounds().top();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_right(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->computeTightBounds().right();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_bottom(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->path->computeTightBounds().bottom();
#else
  return 0.0f;
#endif
}
