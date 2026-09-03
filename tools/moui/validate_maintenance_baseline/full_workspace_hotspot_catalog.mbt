///|
fn full_workspace_file_budgets() -> Array[FileBudget] {
  [
    { path: "tools/moui/validate_api_surface/main.mbt", max_lines: 2100 },
    { path: "moui_richtext/rich_text_editor.mbt", max_lines: 250 },
    {
      path: "moui_richtext/rich_text_markdown_session_editor.mbt",
      max_lines: 725,
    },
    { path: "moui_richtext/rich_text_editor_paint.mbt", max_lines: 675 },
    { path: "moui_richtext/rich_text_editor_event.mbt", max_lines: 850 },
    { path: "moui_richtext/rich_text_editor_caret_hit.mbt", max_lines: 1560 },
    { path: "moui_skia/moui_skia_test.mbt", max_lines: 240 },
    { path: "moui_skia/moui_skia_surface_test.mbt", max_lines: 430 },
    { path: "moui_skia/moui_skia_resource_test.mbt", max_lines: 510 },
    { path: "moui_skia/moui_skia_render_test.mbt", max_lines: 1350 },
    { path: "moui_skia/moui_skia_text_test.mbt", max_lines: 660 },
    { path: "moui_skia/moui_skia_value_path_test.mbt", max_lines: 810 },
    { path: "moui/runtime/view_runtime_test.mbt", max_lines: 1390 },
    { path: "moui_skia/native/skia_native_test.mbt", max_lines: 2747 },
    { path: "moui_skia/native/canvas_native.mbt", max_lines: 2548 },
    { path: "moui_sun/softbuffer/surface_test.mbt", max_lines: 235 },
    {
      path: "moui_sun/softbuffer/surface_dirty_layer_batches_test.mbt",
      max_lines: 945,
    },
    {
      path: "moui_sun/softbuffer/surface_dirty_style_invalidation_test.mbt",
      max_lines: 910,
    },
    {
      path: "moui_sun/softbuffer/surface_submit_batches_test.mbt",
      max_lines: 790,
    },
    {
      path: "moui_sun/softbuffer/surface_schedule_submit_test.mbt",
      max_lines: 935,
    },
    { path: "moui_sun/text/text_system_test.mbt", max_lines: 3499 },
    { path: "moui_sun/graphics/render_frame_test.mbt", max_lines: 3129 },
    { path: "moui_sun/graphics/layer_tree_test.mbt", max_lines: 3040 },
    { path: "moui_sun/graphics/canvas_shape_test.mbt", max_lines: 2908 },
    {
      path: "moui_sun/renderer/render_pipeline_resource_replay.mbt",
      max_lines: 2284,
    },
    { path: "moui_sun/graphics/path.mbt", max_lines: 1945 },
    { path: "moui_sun/graphics/pixmap.mbt", max_lines: 1877 },
    { path: "moui_theme/audit/design_system_golden.mbt", max_lines: 2705 },
    {
      path: "moui_theme/audit/design_system_official_tokens.mbt",
      max_lines: 2424,
    },
    { path: "moui_theme/common/design_system_tokens.mbt", max_lines: 2220 },
  ]
}
