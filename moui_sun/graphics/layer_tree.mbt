///|
/// Ordered collection of cached layers. Layers added later are composited above
/// earlier layers.
pub struct LayerTree {
  layers : Array[Layer]
  invalidation : DirtyRegion
} derive(Debug)

///|
pub fn LayerTree::new() -> LayerTree {
  { layers: [], invalidation: DirtyRegion::new() }
}

///|
pub fn LayerTree::add_layer(self : LayerTree, layer : Layer) -> Int {
  let index = self.layers.length()
  self.layers.push(layer)
  if layer_is_compositable(layer) {
    self.invalidate_rect(layer_target_bounds(layer))
  }
  index
}

///|
pub fn LayerTree::remove_layer(self : LayerTree, index : Int) -> Layer? {
  guard is_valid_layer_index(self, index) else { return None }
  let layer = self.layers.remove(index)
  if layer_is_compositable(layer) {
    self.invalidate_rect(layer_target_bounds(layer))
  }
  Some(layer)
}

///|
pub fn LayerTree::replace_layer(
  self : LayerTree,
  index : Int,
  layer : Layer,
) -> Layer? {
  guard is_valid_layer_index(self, index) else { return None }
  let old_layer = self.layers.remove(index)
  insert_layer_at(self.layers, index, layer)
  invalidate_layer_swap(self, old_layer, layer)
  Some(old_layer)
}

///|
pub fn LayerTree::reorder_layer(
  self : LayerTree,
  from_index : Int,
  to_index : Int,
) -> Bool {
  guard is_valid_layer_index(self, from_index) &&
    is_valid_layer_index(self, to_index) else {
    return false
  }
  guard from_index != to_index else { return true }
  let layer = self.layers.remove(from_index)
  insert_layer_at(self.layers, to_index, layer)
  if layer_is_compositable(layer) {
    self.invalidate_rect(layer_target_bounds(layer))
  }
  true
}

///|
pub fn LayerTree::get_layer_count(self : LayerTree) -> Int {
  self.layers.length()
}

///|
pub fn LayerTree::get_compositable_layer_count(self : LayerTree) -> Int {
  let mut count = 0
  for layer in self.layers {
    if layer.is_compositable() {
      count = count + 1
    }
  }
  count
}

///|
pub fn LayerTree::get_layer(self : LayerTree, index : Int) -> Layer? {
  guard is_valid_layer_index(self, index) else { return None }
  Some(self.layers[index])
}

///|
pub fn LayerTree::clear_dirty_regions(self : LayerTree) -> Unit {
  self.invalidation.clear()
  for layer in self.layers {
    layer.clear_dirty_region()
  }
}

///|
pub fn LayerTree::invalidate_rect(self : LayerTree, rect : PixelRect) -> Unit {
  self.invalidation.add_rect(rect)
}

///|
pub fn LayerTree::invalidate_layer(self : LayerTree, index : Int) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      self.invalidate_rect(layer_target_bounds(layer))
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::set_layer_position(
  self : LayerTree,
  index : Int,
  x : Int,
  y : Int,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      guard layer.get_x() != x || layer.get_y() != y else { return true }
      let old_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_position(x, y))
      if was_compositable {
        self.invalidate_rect(old_bounds)
        self.invalidate_rect(layer_target_bounds(layer))
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::set_layer_visible(
  self : LayerTree,
  index : Int,
  visible : Bool,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      let old_visible = layer.is_visible()
      guard old_visible != visible else { return true }
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_visible(visible))
      if was_compositable || layer_is_compositable(layer) {
        self.invalidate_rect(affected_bounds)
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::set_layer_opacity(
  self : LayerTree,
  index : Int,
  opacity : Double,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      let old_opacity = layer.get_opacity()
      let new_opacity = normalize_opacity(opacity)
      guard old_opacity != new_opacity else { return true }
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_opacity(new_opacity))
      if was_compositable || layer_is_compositable(layer) {
        self.invalidate_rect(affected_bounds)
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::set_layer_blend_mode(
  self : LayerTree,
  index : Int,
  blend_mode : BlendMode,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      guard layer.get_blend_mode() != blend_mode else { return true }
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_blend_mode(blend_mode))
      if was_compositable || layer_is_compositable(layer) {
        self.invalidate_rect(affected_bounds)
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::set_layer_filter(
  self : LayerTree,
  index : Int,
  filter : PaintFilter,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      let previous_filter = layer.get_filter()
      let next_filter = Some(filter)
      guard previous_filter != next_filter else { return true }
      let filter_changes_output = !paint_filter_options_are_visually_equivalent(
        previous_filter, next_filter,
      )
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_filter(filter))
      if filter_changes_output {
        invalidate_layer_style_change(
          self, layer, was_compositable, affected_bounds,
        )
      }
      true
    }
    None => false
  }
}

///|
/// Set the shader used when compositing a layer. The shader is sampled in the
/// layer's local coordinates so layer movement does not shift the pattern.
pub fn LayerTree::set_layer_shader(
  self : LayerTree,
  index : Int,
  shader : PaintShader,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      guard layer.get_shader() != Some(shader) else { return true }
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.set_shader(shader))
      invalidate_layer_style_change(
        self, layer, was_compositable, affected_bounds,
      )
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::clear_layer_shader(self : LayerTree, index : Int) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      guard layer.get_shader() is Some(_) else { return true }
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.clear_shader())
      invalidate_layer_style_change(
        self, layer, was_compositable, affected_bounds,
      )
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::clear_layer_filter(self : LayerTree, index : Int) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      let previous_filter = layer.get_filter()
      guard previous_filter is Some(_) else { return true }
      let filter_changes_output = !paint_filter_options_are_visually_equivalent(
        previous_filter,
        None,
      )
      let affected_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.clear_filter())
      if filter_changes_output {
        invalidate_layer_style_change(
          self, layer, was_compositable, affected_bounds,
        )
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::resize_layer(
  self : LayerTree,
  index : Int,
  width : Int,
  height : Int,
) -> Bool {
  match self.get_layer(index) {
    Some(layer) => {
      let safe_width = width.max(0)
      let safe_height = height.max(0)
      guard safe_width != layer.get_width() || safe_height != layer.get_height() else {
        return true
      }
      let old_bounds = layer_target_bounds(layer)
      let was_compositable = layer_is_compositable(layer)
      ignore(layer.resize(safe_width, safe_height))
      if was_compositable {
        self.invalidate_rect(old_bounds)
        self.invalidate_rect(layer_target_bounds(layer))
      }
      true
    }
    None => false
  }
}

///|
pub fn LayerTree::dirty_bounds(self : LayerTree) -> PixelRect? {
  self.collect_dirty_region().bounds()
}

///|
pub fn LayerTree::dirty_rects(
  self : LayerTree,
  max_rects : Int,
) -> Array[PixelRect] {
  let region = self.collect_dirty_region()
  match region.bounds() {
    Some(bounds) => region.present_rects(bounds, max_rects)
    None => []
  }
}

///|
pub fn[S : Surface] LayerTree::dirty_present_plan(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> DirtyPresentPlan {
  let region = self.combined_dirty_region(target)
  dirty_present_plan_for_region(region, target, surface, max_rects)
}

///|
pub fn[S : Surface] LayerTree::dirty_submit_plan(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> DirtySubmitPlan {
  let region = self.combined_dirty_region(target)
  {
    dirty_bounds: region.bounds(),
    present_plan: dirty_present_plan_for_region(
      region, target, surface, max_rects,
    ),
  }
}

///|
pub fn[S : Surface] LayerTree::submit_by_strategy_plan(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> RenderFrameSubmitPlan {
  let dirty_plan = self.dirty_submit_plan(target, surface, max_rects)
  let strategy = dirty_plan.get_present_strategy(
    surface.get_width(),
    surface.get_height(),
  )
  match strategy {
    DirtyPresentStrategy::Full =>
      render_frame_full_present_plan(
        dirty_plan,
        target.get_pixmap().get_width(),
        target.get_pixmap().get_height(),
        surface.get_width(),
        surface.get_height(),
      )
    _ =>
      render_frame_submit_plan(
        dirty_plan,
        strategy,
        dirty_plan.get_present_bounds(),
        dirty_plan.get_present_rect_count(),
        dirty_plan.get_present_pixel_count(),
        dirty_plan.get_present_byte_count(),
      )
  }
}

///|
pub fn[S : Surface] LayerTree::submit_schedule(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> RenderFrameSchedule {
  render_frame_schedule(
    self.submit_by_strategy_plan(target, surface, max_rects),
  )
}

///|
pub fn[S : Surface] LayerTree::redraw_schedule(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> RenderFrameSchedule {
  self.submit_schedule_by_policy(
    target,
    surface,
    max_rects,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
}

///|
pub fn[S : Surface] LayerTree::submit_schedule_by_policy(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  policy : RenderFrameSubmitPolicy,
) -> RenderFrameSchedule {
  match policy {
    RenderFrameSubmitPolicy::DirtyOnly =>
      self.submit_schedule(target, surface, max_rects)
    RenderFrameSubmitPolicy::CachedRedraw => {
      let schedule = self.submit_schedule(target, surface, max_rects)
      guard schedule.get_action() == RenderFrameScheduleAction::Skip else {
        return schedule
      }
      guard !schedule.has_dirty() else { return schedule }
      layer_tree_full_present_schedule(
        target,
        surface,
        schedule.get_submit_plan().get_dirty_submit_plan(),
      )
    }
    RenderFrameSubmitPolicy::FullRedraw => {
      let dirty_plan = self.dirty_submit_plan(target, surface, max_rects)
      layer_tree_full_present_schedule(target, surface, dirty_plan)
    }
  }
}

///|
pub fn[S : Surface] LayerTree::submit_request_by_policy(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  policy : RenderFrameSubmitPolicy,
) -> RenderFrameSubmitRequest {
  render_frame_submit_request(
    policy,
    self.submit_schedule_by_policy(target, surface, max_rects, policy),
  )
}

///|
fn[S : Surface] layer_tree_full_present_schedule(
  target : Canvas,
  surface : S,
  dirty_plan : DirtySubmitPlan,
) -> RenderFrameSchedule {
  render_frame_full_present_schedule(
    dirty_plan,
    target.get_pixmap().get_width(),
    target.get_pixmap().get_height(),
    surface.get_width(),
    surface.get_height(),
  )
}

///|
fn[S : Surface] dirty_present_plan_for_region(
  region : DirtyRegion,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> DirtyPresentPlan {
  let target_bounds = PixelRect::new(
    x=0,
    y=0,
    width=target.get_pixmap().get_width(),
    height=target.get_pixmap().get_height(),
  )
  let surface_bounds = PixelRect::new(
    x=0,
    y=0,
    width=surface.get_width(),
    height=surface.get_height(),
  )
  match target_bounds.intersection(surface_bounds) {
    Some(bounds) => region.present_plan(bounds, max_rects)
    None => { mode: DirtyPresentPlanMode::Empty, rects: [] }
  }
}

///|
pub fn LayerTree::composite_to(self : LayerTree, target : Canvas) -> Int {
  let mut count = 0
  for layer in self.layers {
    count = count + layer.composite_to(target)
  }
  count
}

///|
pub fn LayerTree::composite_dirty_to(
  self : LayerTree,
  target : Canvas,
  max_rects : Int,
) -> Int {
  let rects = self.dirty_rects(max_rects)
  guard rects.length() > 0 else { return 0 }
  let target_bounds = PixelRect::new(
    x=0,
    y=0,
    width=target.get_pixmap().get_width(),
    height=target.get_pixmap().get_height(),
  )
  let mut draw_count = 0
  for rect in rects {
    match rect.clip_to(target_bounds) {
      Some(clipped_rect) =>
        for layer in self.layers {
          if layer_is_compositable(layer) {
            draw_count = draw_count +
              composite_layer_rect(layer, target, clipped_rect)
          }
        }
      None => ()
    }
  }
  for layer in self.layers {
    if layer_is_compositable(layer) {
      layer.clear_dirty_region()
    }
  }
  self.invalidation.clear()
  draw_count
}

///|
pub fn[S : Surface] LayerTree::present_dirty_to(
  self : LayerTree,
  target : Canvas,
  surface : S,
) -> Result[Int, PresentError] {
  self.present_dirty_to_with_limit(
    target, surface, default_dirty_present_rect_limit,
  )
}

///|
pub fn[S : Surface] LayerTree::present_all_to(
  self : LayerTree,
  target : Canvas,
  surface : S,
) -> Result[Int, PresentError] {
  self.present_all_to_with_limit(
    target, surface, default_dirty_present_rect_limit,
  )
}

///|
pub fn[S : Surface] LayerTree::present_all_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[Int, PresentError] {
  target
  .get_dirty_region()
  .add_all(target.get_pixmap().get_width(), target.get_pixmap().get_height())
  self.present_dirty_to_with_limit(target, surface, max_rects)
}

///|
pub fn[S : Surface] LayerTree::submit_dirty_to(
  self : LayerTree,
  target : Canvas,
  surface : S,
) -> Result[DirtySubmitResult, PresentError] {
  self.submit_dirty_to_with_limit(
    target, surface, default_dirty_present_rect_limit,
  )
}

///|
pub fn[S : Surface] LayerTree::submit_dirty_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[DirtySubmitResult, PresentError] {
  let submit_plan = self.dirty_submit_plan(target, surface, max_rects)
  match self.present_dirty_to_with_limit(target, surface, max_rects) {
    Ok(presented) => Ok({ submit_plan, presented_rect_count: presented })
    Err(error) => Err(error)
  }
}

///|
pub fn[S : Surface] LayerTree::submit_scheduled_to(
  self : LayerTree,
  target : Canvas,
  surface : S,
  schedule : RenderFrameSchedule,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_scheduled_to_with_limit(
    target, surface, default_dirty_present_rect_limit, schedule,
  )
}

///|
pub fn[S : Surface] LayerTree::submit_scheduled_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  schedule : RenderFrameSchedule,
) -> Result[RenderFrameSubmitResult, PresentError] {
  let current_schedule = self.current_submit_schedule_for_schedule(
    target, surface, max_rects, schedule,
  )
  self.submit_current_schedule_to_with_limit(
    target, surface, max_rects, current_schedule,
  )
}

///|
fn[S : Surface] LayerTree::current_submit_schedule_for_schedule(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  schedule : RenderFrameSchedule,
) -> RenderFrameSchedule {
  match schedule.get_action() {
    RenderFrameScheduleAction::Skip =>
      self.submit_schedule(target, surface, max_rects)
    RenderFrameScheduleAction::SubmitWithoutPresent =>
      self.submit_schedule(target, surface, max_rects)
    RenderFrameScheduleAction::Present =>
      match schedule.get_present_strategy() {
        DirtyPresentStrategy::Full =>
          layer_tree_full_present_schedule(
            target,
            surface,
            self.dirty_submit_plan(target, surface, max_rects),
          )
        DirtyPresentStrategy::Partial =>
          self.submit_schedule(target, surface, max_rects)
        DirtyPresentStrategy::Skip => schedule
      }
  }
}

///|
fn[S : Surface] LayerTree::submit_current_schedule_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  current_schedule : RenderFrameSchedule,
) -> Result[RenderFrameSubmitResult, PresentError] {
  match current_schedule.get_action() {
    RenderFrameScheduleAction::Skip =>
      Ok(render_frame_submit_result(current_schedule.get_submit_plan(), 0))
    RenderFrameScheduleAction::SubmitWithoutPresent =>
      match self.submit_dirty_to_with_limit(target, surface, max_rects) {
        Ok(result) =>
          Ok(
            render_frame_submit_result(
              current_schedule.get_submit_plan(),
              result.get_presented_rect_count(),
            ),
          )
        Err(error) => Err(error)
      }
    RenderFrameScheduleAction::Present =>
      match current_schedule.get_present_strategy() {
        DirtyPresentStrategy::Full => {
          let present_result = if current_schedule.get_state() ==
            DirtySubmitState::Clean &&
            !current_schedule.has_dirty() {
            present_cached_target_all_to_with_limit(target, surface, max_rects)
          } else {
            self.present_all_to_with_limit(target, surface, max_rects)
          }
          match present_result {
            Ok(presented) =>
              Ok(
                render_frame_submit_result(
                  current_schedule.get_submit_plan(),
                  presented,
                ),
              )
            Err(error) => Err(error)
          }
        }
        DirtyPresentStrategy::Partial =>
          match self.submit_dirty_to_with_limit(target, surface, max_rects) {
            Ok(result) =>
              Ok(
                render_frame_submit_result(
                  current_schedule.get_submit_plan(),
                  result.get_presented_rect_count(),
                ),
              )
            Err(error) => Err(error)
          }
        DirtyPresentStrategy::Skip =>
          Ok(render_frame_submit_result(current_schedule.get_submit_plan(), 0))
      }
  }
}

///|
fn[S : Surface] present_cached_target_all_to_with_limit(
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[Int, PresentError] {
  let dirty_region = target.get_dirty_region()
  let previous_dirty_rects = dirty_region.get_rects()
  dirty_region.add_all(
    target.get_pixmap().get_width(),
    target.get_pixmap().get_height(),
  )
  match target.present_dirty_to_with_limit(surface, max_rects) {
    Ok(presented) => Ok(presented)
    Err(error) => {
      restore_dirty_region(dirty_region, previous_dirty_rects)
      Err(error)
    }
  }
}

///|
fn restore_dirty_region(
  dirty_region : DirtyRegion,
  rects : Array[PixelRect],
) -> Unit {
  dirty_region.clear()
  for rect in rects {
    dirty_region.add_rect(rect)
  }
}

///|
pub fn[S : Surface] LayerTree::submit_to_by_policy(
  self : LayerTree,
  target : Canvas,
  surface : S,
  policy : RenderFrameSubmitPolicy,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_to_by_policy_with_limit(
    target, surface, default_dirty_present_rect_limit, policy,
  )
}

///|
pub fn[S : Surface] LayerTree::submit_to_by_policy_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  policy : RenderFrameSubmitPolicy,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_scheduled_to_with_limit(
    target,
    surface,
    max_rects,
    self.submit_schedule_by_policy(target, surface, max_rects, policy),
  )
}

///|
pub fn[S : Surface] LayerTree::submit_request_to(
  self : LayerTree,
  target : Canvas,
  surface : S,
  request : RenderFrameSubmitRequest,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_request_to_with_limit(
    target, surface, default_dirty_present_rect_limit, request,
  )
}

///|
pub fn[S : Surface] LayerTree::submit_request_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  request : RenderFrameSubmitRequest,
) -> Result[RenderFrameSubmitResult, PresentError] {
  let current_schedule = self.current_submit_schedule_for_request(
    target, surface, max_rects, request,
  )
  self.submit_current_schedule_to_with_limit(
    target, surface, max_rects, current_schedule,
  )
}

///|
fn[S : Surface] LayerTree::current_submit_schedule_for_request(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
  request : RenderFrameSubmitRequest,
) -> RenderFrameSchedule {
  let schedule = request.get_schedule()
  match schedule.get_action() {
    RenderFrameScheduleAction::Skip =>
      self.submit_schedule_by_policy(
        target,
        surface,
        max_rects,
        request.get_policy(),
      )
    RenderFrameScheduleAction::SubmitWithoutPresent =>
      self.submit_schedule_by_policy(
        target,
        surface,
        max_rects,
        request.get_policy(),
      )
    RenderFrameScheduleAction::Present =>
      self.current_submit_schedule_for_schedule(
        target, surface, max_rects, schedule,
      )
  }
}

///|
pub fn[S : Surface] LayerTree::present_dirty_to_with_limit(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[Int, PresentError] {
  let rects = self.combined_dirty_target_rects(target, max_rects)
  guard rects.length() > 0 else {
    return target.present_dirty_to_with_limit(surface, max_rects)
  }
  let submit_plan = self.dirty_submit_plan(target, surface, max_rects)
  let plan = submit_plan.get_present_plan()
  let dirty_snapshot = snapshot_canvas_dirty_region(target)
  let pixel_snapshot = snapshot_canvas_pixels(target, rects)
  ignore(self.composite_rects_to(target, rects))
  guard !plan.is_empty() else {
    target.clear_dirty_region()
    self.clear_dirty_regions()
    return Ok(0)
  }
  match target.present_dirty_plan_to(surface, plan) {
    Ok(presented) => {
      target.clear_dirty_region()
      self.clear_composited_dirty_regions()
      Ok(presented)
    }
    Err(error) => {
      restore_canvas_pixels(target, rects, pixel_snapshot)
      restore_canvas_dirty_region(target, dirty_snapshot)
      Err(error)
    }
  }
}

///|
pub fn[S : Surface] LayerTree::dirty_present_batch(
  self : LayerTree,
  target : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[PresentBatch, PresentError] {
  let rects = self.combined_dirty_target_rects(target, max_rects)
  guard rects.length() > 0 else {
    return target.dirty_present_batch(surface, max_rects)
  }
  let submit_plan = self.dirty_submit_plan(target, surface, max_rects)
  let plan = submit_plan.get_present_plan()
  let dirty_snapshot = snapshot_canvas_dirty_region(target)
  let pixel_snapshot = snapshot_canvas_pixels(target, rects)
  ignore(self.composite_rects_to(target, rects))
  let result = target.get_pixmap().present_batch(plan)
  restore_canvas_pixels(target, rects, pixel_snapshot)
  restore_canvas_dirty_region(target, dirty_snapshot)
  result
}

///|
fn LayerTree::combined_dirty_region(
  self : LayerTree,
  target : Canvas,
) -> DirtyRegion {
  let region = DirtyRegion::new()
  for rect in target.get_dirty_region().get_rects() {
    region.add_rect(rect)
  }
  for rect in self.collect_dirty_region().get_rects() {
    region.add_rect(rect)
  }
  region
}

///|
fn LayerTree::collect_dirty_region(self : LayerTree) -> DirtyRegion {
  let region = DirtyRegion::new()
  for rect in self.invalidation.get_rects() {
    region.add_rect(rect)
  }
  for layer in self.layers {
    if layer_is_compositable(layer) {
      for rect in layer.translated_dirty_rects(0) {
        region.add_rect(rect)
      }
    }
  }
  region
}

///|
fn LayerTree::combined_dirty_target_rects(
  self : LayerTree,
  target : Canvas,
  max_rects : Int,
) -> Array[PixelRect] {
  dirty_rects_for_region(self.combined_dirty_region(target), target, max_rects)
}

///|
fn dirty_rects_for_region(
  region : DirtyRegion,
  target : Canvas,
  max_rects : Int,
) -> Array[PixelRect] {
  let target_bounds = PixelRect::new(
    x=0,
    y=0,
    width=target.get_pixmap().get_width(),
    height=target.get_pixmap().get_height(),
  )
  let rects = []
  match region.bounds() {
    Some(bounds) =>
      for rect in region.present_rects(bounds, max_rects) {
        match rect.clip_to(target_bounds) {
          Some(clipped_rect) => rects.push(clipped_rect)
          None => ()
        }
      }
    None => ()
  }
  rects
}

///|
fn LayerTree::composite_rects_to(
  self : LayerTree,
  target : Canvas,
  rects : Array[PixelRect],
) -> Int {
  let draw_state = snapshot_canvas_draw_state(target)
  clear_canvas_draw_state(target)
  let mut draw_count = 0
  for rect in rects {
    for layer in self.layers {
      if layer_is_compositable(layer) {
        draw_count = draw_count + composite_layer_rect(layer, target, rect)
      }
    }
  }
  restore_canvas_draw_state(target, draw_state)
  draw_count
}

///|
fn snapshot_canvas_draw_state(target : Canvas) -> CanvasState {
  { transform: target.get_transform(), clip_rect: target.get_clip_rect() }
}

///|
fn clear_canvas_draw_state(target : Canvas) -> Unit {
  target.reset_transform()
  target.clear_clip()
}

///|
fn restore_canvas_draw_state(target : Canvas, state : CanvasState) -> Unit {
  target.set_transform(state.transform)
  match state.clip_rect {
    Some(rect) => target.set_clip_rect(rect)
    None => target.clear_clip()
  }
}

///|
fn LayerTree::clear_composited_dirty_regions(self : LayerTree) -> Unit {
  for layer in self.layers {
    if layer_is_compositable(layer) {
      layer.clear_dirty_region()
    }
  }
  self.invalidation.clear()
}

///|
fn snapshot_canvas_dirty_region(target : Canvas) -> Array[PixelRect] {
  let rects = []
  for rect in target.get_dirty_region().get_rects() {
    rects.push(rect)
  }
  rects
}

///|
fn restore_canvas_dirty_region(
  target : Canvas,
  rects : Array[PixelRect],
) -> Unit {
  let dirty_region = target.get_dirty_region()
  dirty_region.clear()
  for rect in rects {
    dirty_region.add_rect(rect)
  }
}

///|
fn snapshot_canvas_pixels(
  target : Canvas,
  rects : Array[PixelRect],
) -> Array[FixedArray[Byte]] {
  let snapshots = []
  let pixmap = target.get_pixmap()
  for rect in rects {
    let row_bytes = rect.width * 4
    let pixels : FixedArray[Byte] = FixedArray::make(row_bytes * rect.height, 0)
    for row in 0..<rect.height {
      for column in 0..<rect.width {
        let color = pixmap.get_pixel(rect.x + column, rect.y + row)
        write_snapshot_color(pixels, row * row_bytes + column * 4, color)
      }
    }
    snapshots.push(pixels)
  }
  snapshots
}

///|
fn restore_canvas_pixels(
  target : Canvas,
  rects : Array[PixelRect],
  snapshots : Array[FixedArray[Byte]],
) -> Unit {
  let pixmap = target.get_pixmap()
  let count = rects.length().min(snapshots.length())
  for i in 0..<count {
    let rect = rects[i]
    let snapshot = snapshots[i]
    let row_bytes = rect.width * 4
    for row in 0..<rect.height {
      for column in 0..<rect.width {
        let offset = row * row_bytes + column * 4
        pixmap.set_pixel(
          rect.x + column,
          rect.y + row,
          Color::new(
            r=snapshot[offset],
            g=snapshot[offset + 1],
            b=snapshot[offset + 2],
            a=snapshot[offset + 3],
          ),
        )
      }
    }
  }
}

///|
fn write_snapshot_color(
  pixels : FixedArray[Byte],
  offset : Int,
  color : Color,
) -> Unit {
  pixels[offset] = color.r
  pixels[offset + 1] = color.g
  pixels[offset + 2] = color.b
  pixels[offset + 3] = color.a
}

///|
fn is_valid_layer_index(tree : LayerTree, index : Int) -> Bool {
  index >= 0 && index < tree.layers.length()
}

///|
fn insert_layer_at(layers : Array[Layer], index : Int, layer : Layer) -> Unit {
  let tail = []
  while layers.length() > index {
    tail.push(layers.remove(index))
  }
  layers.push(layer)
  for item in tail {
    layers.push(item)
  }
}

///|
fn invalidate_layer_swap(
  tree : LayerTree,
  old_layer : Layer,
  new_layer : Layer,
) -> Unit {
  if layer_is_compositable(old_layer) {
    tree.invalidate_rect(layer_target_bounds(old_layer))
  }
  if layer_is_compositable(new_layer) {
    tree.invalidate_rect(layer_target_bounds(new_layer))
  }
}

///|
fn invalidate_layer_style_change(
  tree : LayerTree,
  layer : Layer,
  was_compositable : Bool,
  affected_bounds : PixelRect,
) -> Unit {
  if was_compositable && layer.has_dirty() {
    tree.invalidate_rect(affected_bounds)
  }
}

///|
fn layer_is_compositable(layer : Layer) -> Bool {
  layer.is_compositable()
}

///|
fn layer_target_bounds(layer : Layer) -> PixelRect {
  layer.translated_bounds()
}

///|
fn composite_layer_rect(
  layer : Layer,
  target : Canvas,
  target_rect : PixelRect,
) -> Int {
  match layer_target_bounds(layer).intersection(target_rect) {
    Some(intersection) => {
      let src_rect = PixelRect::new(
        x=intersection.x - layer.get_x(),
        y=intersection.y - layer.get_y(),
        width=intersection.width,
        height=intersection.height,
      )
      target.draw_layer_pixmap_rect(
        layer.get_pixmap(),
        src_rect,
        intersection.x,
        intersection.y,
        layer.composite_paint(),
      )
      1
    }
    None => 0
  }
}
