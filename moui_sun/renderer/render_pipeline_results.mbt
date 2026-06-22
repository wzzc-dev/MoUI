///|
/// Return the number of commands replayed.
pub fn RenderPipelineReplayResult::get_command_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.command_count
}

///|
/// Return the number of clear commands replayed.
pub fn RenderPipelineReplayResult::get_clear_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.clear_count
}

///|
/// Return the number of fill commands replayed.
pub fn RenderPipelineReplayResult::get_fill_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.fill_count
}

///|
/// Return the number of stroke commands replayed.
pub fn RenderPipelineReplayResult::get_stroke_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.stroke_count
}

///|
/// Return the number of image commands replayed.
pub fn RenderPipelineReplayResult::get_image_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.image_count
}

///|
/// Return the number of text commands replayed.
pub fn RenderPipelineReplayResult::get_text_count(
  self : RenderPipelineReplayResult,
) -> Int {
  self.text_count
}

///|
/// Return the base command replay telemetry.
pub fn RenderPipelineResourceReplayResult::get_replay_result(
  self : RenderPipelineResourceReplayResult,
) -> RenderPipelineReplayResult {
  self.replay_result
}

///|
/// Return the number of commands replayed.
pub fn RenderPipelineResourceReplayResult::get_command_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_command_count()
}

///|
/// Return the number of clear commands replayed.
pub fn RenderPipelineResourceReplayResult::get_clear_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_clear_count()
}

///|
/// Return the number of fill commands replayed.
pub fn RenderPipelineResourceReplayResult::get_fill_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_fill_count()
}

///|
/// Return the number of stroke commands replayed.
pub fn RenderPipelineResourceReplayResult::get_stroke_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_stroke_count()
}

///|
/// Return the number of image commands replayed.
pub fn RenderPipelineResourceReplayResult::get_image_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_image_count()
}

///|
/// Return the number of text commands replayed.
pub fn RenderPipelineResourceReplayResult::get_text_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.replay_result.get_text_count()
}

///|
/// Return the number of keyed font commands replayed through the font cache.
pub fn RenderPipelineResourceReplayResult::get_keyed_font_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.keyed_font_count
}

///|
/// Return the number of keyed image commands replayed through the image cache.
pub fn RenderPipelineResourceReplayResult::get_keyed_image_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.keyed_image_count
}

///|
/// Return the number of keyed text commands replayed through the text cache.
pub fn RenderPipelineResourceReplayResult::get_keyed_text_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.keyed_text_count
}

///|
/// Return the number of keyed atlas text commands replayed through glyph resources.
pub fn RenderPipelineResourceReplayResult::get_keyed_atlas_text_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.keyed_atlas_text_count
}

///|
/// Return the number of keyed commands replayed through resource caches.
pub fn RenderPipelineResourceReplayResult::get_keyed_resource_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.keyed_font_count +
  self.keyed_image_count +
  self.keyed_text_count +
  self.keyed_atlas_text_count
}

///|
/// Return the number of keyed font commands that reused a cached font face.
pub fn RenderPipelineResourceReplayResult::get_font_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.font_cache_hit_count
}

///|
/// Return the number of keyed font commands that parsed or loaded a new face.
pub fn RenderPipelineResourceReplayResult::get_font_parse_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.font_parse_count
}

///|
/// Return the number of keyed image commands that reused a cached pixmap.
pub fn RenderPipelineResourceReplayResult::get_image_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.image_cache_hit_count
}

///|
/// Return the number of keyed image commands that inserted a pixmap cache entry.
pub fn RenderPipelineResourceReplayResult::get_image_cache_insert_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.image_cache_insert_count
}

///|
/// Return the number of keyed text commands that reused a cached text mask.
pub fn RenderPipelineResourceReplayResult::get_text_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.text_cache_hit_count
}

///|
/// Return the number of keyed text commands that rendered a new text mask.
pub fn RenderPipelineResourceReplayResult::get_text_mask_render_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.text_mask_render_count
}

///|
/// Return the number of atlas text glyph masks reused from the glyph cache.
pub fn RenderPipelineResourceReplayResult::get_glyph_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.glyph_cache_hit_count
}

///|
/// Return the number of atlas text glyph masks rasterized into the glyph cache.
pub fn RenderPipelineResourceReplayResult::get_glyph_mask_render_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.glyph_mask_render_count
}

///|
/// Return the number of atlas glyph placements reused from the atlas.
pub fn RenderPipelineResourceReplayResult::get_atlas_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.atlas_cache_hit_count
}

///|
/// Return the number of atlas glyph placements inserted into the atlas.
pub fn RenderPipelineResourceReplayResult::get_atlas_insert_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.atlas_insert_count
}

///|
/// Return the number of atlas draws that cleared the atlas while replaying.
pub fn RenderPipelineResourceReplayResult::get_atlas_clear_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.atlas_clear_count
}

///|
/// Return the number of keyed resource commands that hit a cache.
pub fn RenderPipelineResourceReplayResult::get_resource_cache_hit_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.font_cache_hit_count +
  self.image_cache_hit_count +
  self.text_cache_hit_count +
  self.glyph_cache_hit_count +
  self.atlas_cache_hit_count
}

///|
/// Return the number of keyed resource commands that populated a cache.
pub fn RenderPipelineResourceReplayResult::get_resource_cache_miss_count(
  self : RenderPipelineResourceReplayResult,
) -> Int {
  self.font_parse_count +
  self.image_cache_insert_count +
  self.text_mask_render_count +
  self.glyph_mask_render_count +
  self.atlas_insert_count
}

///|
/// Return the number of commands analyzed.
pub fn RenderPipelineAnalysis::get_command_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.command_count
}

///|
/// Return the number of clear commands analyzed.
pub fn RenderPipelineAnalysis::get_clear_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.clear_count
}

///|
/// Return the number of fill commands analyzed.
pub fn RenderPipelineAnalysis::get_fill_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.fill_count
}

///|
/// Return the number of stroke commands analyzed.
pub fn RenderPipelineAnalysis::get_stroke_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.stroke_count
}

///|
/// Return the number of image commands analyzed.
pub fn RenderPipelineAnalysis::get_image_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.image_count
}

///|
/// Return the number of text commands analyzed.
pub fn RenderPipelineAnalysis::get_text_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.text_count
}

///|
/// Return the conservative dirty region estimated for this pipeline.
pub fn RenderPipelineAnalysis::get_dirty_region(
  self : RenderPipelineAnalysis,
) -> @graphics.DirtyRegion {
  copy_render_pipeline_dirty_region(self.dirty_region)
}

///|
/// Return whether analysis found any pixel area that may need presenting.
pub fn RenderPipelineAnalysis::has_dirty(self : RenderPipelineAnalysis) -> Bool {
  !self.dirty_region.is_empty()
}

///|
/// Return the number of conservative dirty rectangles estimated.
pub fn RenderPipelineAnalysis::get_dirty_rect_count(
  self : RenderPipelineAnalysis,
) -> Int {
  self.dirty_region.get_rect_count()
}

///|
/// Return the conservative dirty bounds estimated for this pipeline.
pub fn RenderPipelineAnalysis::get_dirty_bounds(
  self : RenderPipelineAnalysis,
) -> @graphics.PixelRect? {
  self.dirty_region.bounds()
}

///|
/// Build a present plan from the estimated dirty region.
pub fn RenderPipelineAnalysis::get_present_plan(
  self : RenderPipelineAnalysis,
  width : Int,
  height : Int,
  max_rects : Int,
) -> @graphics.DirtyPresentPlan {
  self.dirty_region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width~, height~),
    max_rects,
  )
}

///|
/// Return the number of commands in the previous display list.
pub fn RenderPipelineDiffResult::get_previous_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.previous_command_count
}

///|
/// Return the number of commands in the next display list.
pub fn RenderPipelineDiffResult::get_next_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.next_command_count
}

///|
/// Return the number of commands retained without dirtying their bounds.
pub fn RenderPipelineDiffResult::get_retained_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.retained_command_count
}

///|
/// Return the number of paired commands whose value changed.
pub fn RenderPipelineDiffResult::get_changed_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.changed_command_count
}

///|
/// Return the number of commands inserted in the next display list.
pub fn RenderPipelineDiffResult::get_inserted_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.inserted_command_count
}

///|
/// Return the number of commands removed from the previous display list.
pub fn RenderPipelineDiffResult::get_removed_command_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.removed_command_count
}

///|
/// Return whether the retained display list changed structurally or by value.
pub fn RenderPipelineDiffResult::has_changes(
  self : RenderPipelineDiffResult,
) -> Bool {
  self.changed_command_count > 0 ||
  self.inserted_command_count > 0 ||
  self.removed_command_count > 0
}

///|
/// Return the conservative dirty region caused by this display-list diff.
pub fn RenderPipelineDiffResult::get_dirty_region(
  self : RenderPipelineDiffResult,
) -> @graphics.DirtyRegion {
  copy_render_pipeline_dirty_region(self.dirty_region)
}

///|
/// Return whether this display-list diff has dirty pixels to submit.
pub fn RenderPipelineDiffResult::has_dirty(
  self : RenderPipelineDiffResult,
) -> Bool {
  !self.dirty_region.is_empty()
}

///|
/// Return the number of conservative dirty rectangles in this diff.
pub fn RenderPipelineDiffResult::get_dirty_rect_count(
  self : RenderPipelineDiffResult,
) -> Int {
  self.dirty_region.get_rect_count()
}

///|
/// Return the conservative dirty bounds for this display-list diff.
pub fn RenderPipelineDiffResult::get_dirty_bounds(
  self : RenderPipelineDiffResult,
) -> @graphics.PixelRect? {
  self.dirty_region.bounds()
}

///|
/// Build a present plan from this diff's estimated dirty region.
pub fn RenderPipelineDiffResult::get_present_plan(
  self : RenderPipelineDiffResult,
  width : Int,
  height : Int,
  max_rects : Int,
) -> @graphics.DirtyPresentPlan {
  self.dirty_region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width~, height~),
    max_rects,
  )
}

///|
/// Return this batch's scheduling category.
pub fn RenderPipelineBatch::get_kind(
  self : RenderPipelineBatch,
) -> RenderPipelineBatchKind {
  self.kind
}

///|
/// Return the first command index covered by this batch.
pub fn RenderPipelineBatch::get_start_index(self : RenderPipelineBatch) -> Int {
  self.start_index
}

///|
/// Return the number of commands covered by this batch.
pub fn RenderPipelineBatch::get_command_count(
  self : RenderPipelineBatch,
) -> Int {
  self.command_count
}

///|
/// Return the conservative dirty region for this batch.
pub fn RenderPipelineBatch::get_dirty_region(
  self : RenderPipelineBatch,
) -> @graphics.DirtyRegion {
  copy_render_pipeline_dirty_region(self.dirty_region)
}

///|
/// Return whether this batch may dirty pixels.
pub fn RenderPipelineBatch::has_dirty(self : RenderPipelineBatch) -> Bool {
  !self.dirty_region.is_empty()
}

///|
/// Return the number of dirty rects estimated for this batch.
pub fn RenderPipelineBatch::get_dirty_rect_count(
  self : RenderPipelineBatch,
) -> Int {
  self.dirty_region.get_rect_count()
}

///|
/// Return the conservative dirty bounds for this batch.
pub fn RenderPipelineBatch::get_dirty_bounds(
  self : RenderPipelineBatch,
) -> @graphics.PixelRect? {
  self.dirty_region.bounds()
}

///|
/// Build a present plan from this batch's estimated dirty region.
pub fn RenderPipelineBatch::get_present_plan(
  self : RenderPipelineBatch,
  width : Int,
  height : Int,
  max_rects : Int,
) -> @graphics.DirtyPresentPlan {
  self.dirty_region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width~, height~),
    max_rects,
  )
}

///|
/// Return the number of commands covered by this plan.
pub fn RenderPipelineBatchPlan::get_command_count(
  self : RenderPipelineBatchPlan,
) -> Int {
  self.command_count
}

///|
/// Return the number of contiguous command batches.
pub fn RenderPipelineBatchPlan::get_batch_count(
  self : RenderPipelineBatchPlan,
) -> Int {
  self.batches.length()
}

///|
/// Return the scheduler-facing contiguous command batches.
pub fn RenderPipelineBatchPlan::get_batches(
  self : RenderPipelineBatchPlan,
) -> Array[RenderPipelineBatch] {
  copy_render_pipeline_batches(self.batches)
}

///|
/// Return the conservative dirty region for all batches.
pub fn RenderPipelineBatchPlan::get_dirty_region(
  self : RenderPipelineBatchPlan,
) -> @graphics.DirtyRegion {
  copy_render_pipeline_dirty_region(self.dirty_region)
}

///|
/// Return whether any batch may dirty pixels.
pub fn RenderPipelineBatchPlan::has_dirty(
  self : RenderPipelineBatchPlan,
) -> Bool {
  !self.dirty_region.is_empty()
}

///|
/// Return the conservative dirty bounds for all batches.
pub fn RenderPipelineBatchPlan::get_dirty_bounds(
  self : RenderPipelineBatchPlan,
) -> @graphics.PixelRect? {
  self.dirty_region.bounds()
}

///|
/// Build a present plan from the batch plan's estimated dirty region.
pub fn RenderPipelineBatchPlan::get_present_plan(
  self : RenderPipelineBatchPlan,
  width : Int,
  height : Int,
  max_rects : Int,
) -> @graphics.DirtyPresentPlan {
  self.dirty_region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width~, height~),
    max_rects,
  )
}

///|
/// Return the command index that owns this image dependency.
pub fn RenderPipelineImageDependency::get_command_index(
  self : RenderPipelineImageDependency,
) -> Int {
  self.command_index
}

///|
/// Return the stable resource key for this image dependency when provided.
pub fn RenderPipelineImageDependency::get_resource_key(
  self : RenderPipelineImageDependency,
) -> String? {
  self.resource_key
}

///|
/// Return whether this image dependency has a stable resource key.
pub fn RenderPipelineImageDependency::has_resource_key(
  self : RenderPipelineImageDependency,
) -> Bool {
  self.resource_key is Some(_)
}

///|
/// Return the clipped source width read from the image resource.
pub fn RenderPipelineImageDependency::get_source_width(
  self : RenderPipelineImageDependency,
) -> Int {
  self.source_width
}

///|
/// Return the clipped source height read from the image resource.
pub fn RenderPipelineImageDependency::get_source_height(
  self : RenderPipelineImageDependency,
) -> Int {
  self.source_height
}

///|
/// Return the clipped source pixel count read from the image resource.
pub fn RenderPipelineImageDependency::get_source_pixel_count(
  self : RenderPipelineImageDependency,
) -> Int {
  self.source_pixel_count
}

///|
/// Return the command index that owns this text dependency.
pub fn RenderPipelineTextDependency::get_command_index(
  self : RenderPipelineTextDependency,
) -> Int {
  self.command_index
}

///|
/// Return the stable resource key for this text dependency when provided.
pub fn RenderPipelineTextDependency::get_resource_key(
  self : RenderPipelineTextDependency,
) -> String? {
  self.resource_key
}

///|
/// Return whether this text dependency has a stable resource key.
pub fn RenderPipelineTextDependency::has_resource_key(
  self : RenderPipelineTextDependency,
) -> Bool {
  self.resource_key is Some(_)
}

///|
/// Return the number of bytes in the queued text string.
pub fn RenderPipelineTextDependency::get_text_byte_count(
  self : RenderPipelineTextDependency,
) -> Int {
  self.text_byte_count
}

///|
/// Return the number of layout runs precomputed for this text command.
pub fn RenderPipelineTextDependency::get_run_count(
  self : RenderPipelineTextDependency,
) -> Int {
  self.run_count
}

///|
/// Return the number of positioned glyphs precomputed for this text command.
pub fn RenderPipelineTextDependency::get_glyph_count(
  self : RenderPipelineTextDependency,
) -> Int {
  self.glyph_count
}

///|
/// Return the precomputed text layout width.
pub fn RenderPipelineTextDependency::get_layout_width(
  self : RenderPipelineTextDependency,
) -> Double {
  self.layout_width
}

///|
/// Return the precomputed text layout height.
pub fn RenderPipelineTextDependency::get_layout_height(
  self : RenderPipelineTextDependency,
) -> Double {
  self.layout_height
}

///|
/// Return the command index for this font dependency.
pub fn RenderPipelineFontDependency::get_command_index(
  self : RenderPipelineFontDependency,
) -> Int {
  self.command_index
}

///|
/// Return the stable font resource key for this dependency.
pub fn RenderPipelineFontDependency::get_font_key(
  self : RenderPipelineFontDependency,
) -> String {
  self.font_key
}

///|
/// Return the number of bytes in the queued font data.
pub fn RenderPipelineFontDependency::get_font_byte_count(
  self : RenderPipelineFontDependency,
) -> Int {
  self.font_byte_count
}

///|
/// Return the number of commands scanned for resources.
pub fn RenderPipelineResourcePlan::get_command_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.command_count
}

///|
/// Return the number of discovered font-byte resource uses.
pub fn RenderPipelineResourcePlan::get_font_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.font_dependencies.length()
}

///|
/// Return the number of font-byte resource uses with stable keys.
pub fn RenderPipelineResourcePlan::get_keyed_font_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.font_dependencies.length()
}

///|
/// Return the number of discovered image resource uses.
pub fn RenderPipelineResourcePlan::get_image_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.image_dependencies.length()
}

///|
/// Return the number of image resource uses with stable keys.
pub fn RenderPipelineResourcePlan::get_keyed_image_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.image_dependencies {
    if dependency.has_resource_key() {
      count += 1
    }
  }
  count
}

///|
/// Return the number of discovered text resource uses.
pub fn RenderPipelineResourcePlan::get_text_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.text_dependencies.length()
}

///|
/// Return the number of text resource uses with stable keys.
pub fn RenderPipelineResourcePlan::get_keyed_text_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.text_dependencies {
    if dependency.has_resource_key() {
      count += 1
    }
  }
  count
}

///|
/// Return the number of discovered resource uses.
pub fn RenderPipelineResourcePlan::get_resource_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.get_font_count() + self.get_image_count() + self.get_text_count()
}

///|
/// Return the number of discovered resource uses with stable keys.
pub fn RenderPipelineResourcePlan::get_keyed_resource_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  self.get_keyed_font_count() +
  self.get_keyed_image_count() +
  self.get_keyed_text_count()
}

///|
/// Return whether the plan discovered at least one resource use.
pub fn RenderPipelineResourcePlan::has_resources(
  self : RenderPipelineResourcePlan,
) -> Bool {
  self.get_resource_count() > 0
}

///|
/// Return pre-resolved font-byte resource uses.
pub fn RenderPipelineResourcePlan::get_font_dependencies(
  self : RenderPipelineResourcePlan,
) -> Array[RenderPipelineFontDependency] {
  copy_render_pipeline_font_dependencies(self.font_dependencies)
}

///|
/// Return pre-resolved image resource uses.
pub fn RenderPipelineResourcePlan::get_image_dependencies(
  self : RenderPipelineResourcePlan,
) -> Array[RenderPipelineImageDependency] {
  copy_render_pipeline_image_dependencies(self.image_dependencies)
}

///|
/// Return pre-resolved text resource uses.
pub fn RenderPipelineResourcePlan::get_text_dependencies(
  self : RenderPipelineResourcePlan,
) -> Array[RenderPipelineTextDependency] {
  copy_render_pipeline_text_dependencies(self.text_dependencies)
}

///|
/// Return the total clipped source pixels read by image commands.
pub fn RenderPipelineResourcePlan::get_image_source_pixel_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.image_dependencies {
    count += dependency.source_pixel_count
  }
  count
}

///|
/// Return the total queued font byte count.
pub fn RenderPipelineResourcePlan::get_font_byte_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.font_dependencies {
    count += dependency.font_byte_count
  }
  count
}

///|
/// Return the total queued text byte count.
pub fn RenderPipelineResourcePlan::get_text_byte_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.text_dependencies {
    count += dependency.text_byte_count
  }
  count
}

///|
/// Return the total precomputed text layout run count.
pub fn RenderPipelineResourcePlan::get_text_run_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.text_dependencies {
    count += dependency.run_count
  }
  count
}

///|
/// Return the total precomputed positioned glyph count.
pub fn RenderPipelineResourcePlan::get_text_glyph_count(
  self : RenderPipelineResourcePlan,
) -> Int {
  let mut count = 0
  for dependency in self.text_dependencies {
    count += dependency.glyph_count
  }
  count
}

///|
fn copy_render_pipeline_dirty_region(
  region : @graphics.DirtyRegion,
) -> @graphics.DirtyRegion {
  let copied = @graphics.DirtyRegion::new()
  for rect in region.get_rects() {
    copied.add_rect(rect)
  }
  copied
}

///|
fn copy_render_pipeline_batch(
  batch : RenderPipelineBatch,
) -> RenderPipelineBatch {
  {
    kind: batch.kind,
    start_index: batch.start_index,
    command_count: batch.command_count,
    dirty_region: copy_render_pipeline_dirty_region(batch.dirty_region),
  }
}

///|
fn copy_render_pipeline_batches(
  batches : Array[RenderPipelineBatch],
) -> Array[RenderPipelineBatch] {
  let copied = []
  for batch in batches {
    copied.push(copy_render_pipeline_batch(batch))
  }
  copied
}

///|
fn copy_render_pipeline_font_dependencies(
  dependencies : Array[RenderPipelineFontDependency],
) -> Array[RenderPipelineFontDependency] {
  let copied = []
  for dependency in dependencies {
    copied.push(dependency)
  }
  copied
}

///|
fn copy_render_pipeline_image_dependencies(
  dependencies : Array[RenderPipelineImageDependency],
) -> Array[RenderPipelineImageDependency] {
  let copied = []
  for dependency in dependencies {
    copied.push(dependency)
  }
  copied
}

///|
fn copy_render_pipeline_text_dependencies(
  dependencies : Array[RenderPipelineTextDependency],
) -> Array[RenderPipelineTextDependency] {
  let copied = []
  for dependency in dependencies {
    copied.push(dependency)
  }
  copied
}
