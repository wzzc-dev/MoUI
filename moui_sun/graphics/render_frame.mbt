///|
/// A frame-sized drawing target with a z-ordered layer tree and a dirty-present
/// policy. This is the small unit an event loop can submit to a Surface.
pub struct RenderFrame {
  mut canvas : Canvas
  layer_tree : LayerTree
  mut dirty_rect_limit : Int
} derive(Debug)

///|
/// Strategy-aware dry-run plan for submitting a RenderFrame to a Surface.
pub struct RenderFrameSubmitPlan {
  dirty_submit_plan : DirtySubmitPlan
  strategy : DirtyPresentStrategy
  present_bounds : PixelRect?
  present_rect_count : Int
  present_pixel_count : Int
  present_byte_count : Int
} derive(Debug)

///|
/// Result of submitting a RenderFrame through the strategy-aware scheduler.
pub struct RenderFrameSubmitResult {
  submit_plan : RenderFrameSubmitPlan
  presented_rect_count : Int
} derive(Debug)

///|
/// Event-loop-facing action selected from a dry-run RenderFrame submit plan.
pub(all) enum RenderFrameScheduleAction {
  Skip
  SubmitWithoutPresent
  Present
} derive(Eq, Debug)

///|
/// Event-loop-facing submit policy for choosing between dirty-only work,
/// cached repaint requests, and unconditional full redraws.
pub(all) enum RenderFrameSubmitPolicy {
  DirtyOnly
  CachedRedraw
  FullRedraw
} derive(Eq, Debug)

///|
/// Dry-run scheduling decision for submitting a RenderFrame to a Surface.
pub struct RenderFrameSchedule {
  submit_plan : RenderFrameSubmitPlan
  action : RenderFrameScheduleAction
} derive(Debug)

///|
/// Policy intent paired with the dry-run schedule selected for one frame
/// submit. Event loops can inspect this request, then execute the same
/// precomputed decision without recomputing scheduling state.
pub struct RenderFrameSubmitRequest {
  policy : RenderFrameSubmitPolicy
  schedule : RenderFrameSchedule
} derive(Debug)

///|
/// Request to resize one frame-owned layer cache and clear it to a color.
pub struct RenderFrameLayerClearRequest {
  layer_index : Int
  color : Color
} derive(Eq, Debug)

///|
/// Request to replace one frame-owned layer cache.
pub struct RenderFrameLayerReplacementRequest {
  layer_index : Int
  layer : Layer
} derive(Debug)

///|
/// Create a layer clear request for a RenderFrame resize lifecycle operation.
pub fn RenderFrameLayerClearRequest::new(
  layer_index : Int,
  color : Color,
) -> RenderFrameLayerClearRequest {
  { layer_index, color }
}

///|
/// Return the target layer index.
pub fn RenderFrameLayerClearRequest::get_layer_index(
  self : RenderFrameLayerClearRequest,
) -> Int {
  self.layer_index
}

///|
/// Return the clear color for the target layer.
pub fn RenderFrameLayerClearRequest::get_color(
  self : RenderFrameLayerClearRequest,
) -> Color {
  self.color
}

///|
/// Create a layer replacement request for a RenderFrame lifecycle operation.
pub fn RenderFrameLayerReplacementRequest::new(
  layer_index : Int,
  layer : Layer,
) -> RenderFrameLayerReplacementRequest {
  { layer_index, layer }
}

///|
/// Return the target layer index.
pub fn RenderFrameLayerReplacementRequest::get_layer_index(
  self : RenderFrameLayerReplacementRequest,
) -> Int {
  self.layer_index
}

///|
/// Return the replacement layer.
pub fn RenderFrameLayerReplacementRequest::get_layer(
  self : RenderFrameLayerReplacementRequest,
) -> Layer {
  self.layer
}

///|
pub fn RenderFrameSubmitPlan::get_dirty_submit_plan(
  self : RenderFrameSubmitPlan,
) -> DirtySubmitPlan {
  self.dirty_submit_plan
}

///|
pub fn RenderFrameSubmitPlan::get_present_strategy(
  self : RenderFrameSubmitPlan,
) -> DirtyPresentStrategy {
  self.strategy
}

///|
pub fn RenderFrameSubmitPlan::get_state(
  self : RenderFrameSubmitPlan,
) -> DirtySubmitState {
  self.dirty_submit_plan.get_state()
}

///|
pub fn RenderFrameSubmitPlan::get_dirty_bounds(
  self : RenderFrameSubmitPlan,
) -> PixelRect? {
  self.dirty_submit_plan.get_dirty_bounds()
}

///|
pub fn RenderFrameSubmitPlan::has_dirty(self : RenderFrameSubmitPlan) -> Bool {
  self.dirty_submit_plan.has_dirty()
}

///|
pub fn RenderFrameSubmitPlan::needs_present(
  self : RenderFrameSubmitPlan,
) -> Bool {
  self.strategy != DirtyPresentStrategy::Skip && self.present_rect_count > 0
}

///|
pub fn RenderFrameSubmitPlan::was_clipped_away(
  self : RenderFrameSubmitPlan,
) -> Bool {
  self.get_state() == DirtySubmitState::DirtyClippedAway
}

///|
pub fn RenderFrameSubmitPlan::uses_bounds_fallback(
  self : RenderFrameSubmitPlan,
) -> Bool {
  self.dirty_submit_plan.uses_bounds_fallback()
}

///|
pub fn RenderFrameSubmitPlan::get_present_bounds(
  self : RenderFrameSubmitPlan,
) -> PixelRect? {
  self.present_bounds
}

///|
pub fn RenderFrameSubmitPlan::get_present_rect_count(
  self : RenderFrameSubmitPlan,
) -> Int {
  self.present_rect_count
}

///|
pub fn RenderFrameSubmitPlan::get_present_pixel_count(
  self : RenderFrameSubmitPlan,
) -> Int {
  self.present_pixel_count
}

///|
pub fn RenderFrameSubmitPlan::get_present_byte_count(
  self : RenderFrameSubmitPlan,
) -> Int {
  self.present_byte_count
}

///|
pub fn RenderFrameSubmitPlan::saves_full_present_pixels(
  self : RenderFrameSubmitPlan,
) -> Bool {
  self.strategy == DirtyPresentStrategy::Partial
}

///|
pub fn RenderFrameSubmitResult::get_submit_plan(
  self : RenderFrameSubmitResult,
) -> RenderFrameSubmitPlan {
  self.submit_plan
}

///|
pub fn RenderFrameSubmitResult::get_present_strategy(
  self : RenderFrameSubmitResult,
) -> DirtyPresentStrategy {
  self.submit_plan.get_present_strategy()
}

///|
pub fn RenderFrameSubmitResult::get_present_rect_count(
  self : RenderFrameSubmitResult,
) -> Int {
  self.submit_plan.get_present_rect_count()
}

///|
pub fn RenderFrameSubmitResult::get_presented_rect_count(
  self : RenderFrameSubmitResult,
) -> Int {
  self.presented_rect_count
}

///|
pub fn RenderFrameSubmitResult::get_state(
  self : RenderFrameSubmitResult,
) -> DirtySubmitState {
  self.submit_plan.get_state()
}

///|
pub fn RenderFrameSubmitResult::get_dirty_bounds(
  self : RenderFrameSubmitResult,
) -> PixelRect? {
  self.submit_plan.get_dirty_bounds()
}

///|
pub fn RenderFrameSubmitResult::has_dirty(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.submit_plan.has_dirty()
}

///|
pub fn RenderFrameSubmitResult::needs_present(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.submit_plan.needs_present()
}

///|
pub fn RenderFrameSubmitResult::was_clipped_away(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.submit_plan.was_clipped_away()
}

///|
pub fn RenderFrameSubmitResult::uses_bounds_fallback(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.submit_plan.uses_bounds_fallback()
}

///|
pub fn RenderFrameSubmitResult::get_present_bounds(
  self : RenderFrameSubmitResult,
) -> PixelRect? {
  self.submit_plan.get_present_bounds()
}

///|
pub fn RenderFrameSubmitResult::did_present(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.presented_rect_count > 0
}

///|
pub fn RenderFrameSubmitResult::get_present_pixel_count(
  self : RenderFrameSubmitResult,
) -> Int {
  self.submit_plan.get_present_pixel_count()
}

///|
pub fn RenderFrameSubmitResult::get_present_byte_count(
  self : RenderFrameSubmitResult,
) -> Int {
  self.submit_plan.get_present_byte_count()
}

///|
pub fn RenderFrameSubmitResult::saves_full_present_pixels(
  self : RenderFrameSubmitResult,
) -> Bool {
  self.submit_plan.saves_full_present_pixels()
}

///|
pub fn RenderFrameSchedule::get_submit_plan(
  self : RenderFrameSchedule,
) -> RenderFrameSubmitPlan {
  self.submit_plan
}

///|
pub fn RenderFrameSchedule::get_action(
  self : RenderFrameSchedule,
) -> RenderFrameScheduleAction {
  self.action
}

///|
pub fn RenderFrameSchedule::get_present_strategy(
  self : RenderFrameSchedule,
) -> DirtyPresentStrategy {
  self.submit_plan.get_present_strategy()
}

///|
pub fn RenderFrameSchedule::get_state(
  self : RenderFrameSchedule,
) -> DirtySubmitState {
  self.submit_plan.get_state()
}

///|
pub fn RenderFrameSchedule::get_dirty_bounds(
  self : RenderFrameSchedule,
) -> PixelRect? {
  self.submit_plan.get_dirty_bounds()
}

///|
pub fn RenderFrameSchedule::has_dirty(self : RenderFrameSchedule) -> Bool {
  self.submit_plan.has_dirty()
}

///|
pub fn RenderFrameSchedule::needs_present(self : RenderFrameSchedule) -> Bool {
  self.action == RenderFrameScheduleAction::Present
}

///|
pub fn RenderFrameSchedule::should_submit(self : RenderFrameSchedule) -> Bool {
  self.action != RenderFrameScheduleAction::Skip
}

///|
pub fn RenderFrameSchedule::was_clipped_away(
  self : RenderFrameSchedule,
) -> Bool {
  self.submit_plan.was_clipped_away()
}

///|
pub fn RenderFrameSchedule::uses_bounds_fallback(
  self : RenderFrameSchedule,
) -> Bool {
  self.submit_plan.uses_bounds_fallback()
}

///|
pub fn RenderFrameSchedule::get_present_bounds(
  self : RenderFrameSchedule,
) -> PixelRect? {
  self.submit_plan.get_present_bounds()
}

///|
pub fn RenderFrameSchedule::get_present_rect_count(
  self : RenderFrameSchedule,
) -> Int {
  self.submit_plan.get_present_rect_count()
}

///|
pub fn RenderFrameSchedule::get_present_pixel_count(
  self : RenderFrameSchedule,
) -> Int {
  self.submit_plan.get_present_pixel_count()
}

///|
pub fn RenderFrameSchedule::get_present_byte_count(
  self : RenderFrameSchedule,
) -> Int {
  self.submit_plan.get_present_byte_count()
}

///|
pub fn RenderFrameSchedule::saves_full_present_pixels(
  self : RenderFrameSchedule,
) -> Bool {
  self.submit_plan.saves_full_present_pixels()
}

///|
pub fn RenderFrameSubmitRequest::get_policy(
  self : RenderFrameSubmitRequest,
) -> RenderFrameSubmitPolicy {
  self.policy
}

///|
pub fn RenderFrameSubmitRequest::new(
  policy : RenderFrameSubmitPolicy,
  schedule : RenderFrameSchedule,
) -> RenderFrameSubmitRequest {
  { policy, schedule }
}

///|
pub fn RenderFrameSubmitRequest::get_schedule(
  self : RenderFrameSubmitRequest,
) -> RenderFrameSchedule {
  self.schedule
}

///|
pub fn RenderFrameSubmitRequest::get_submit_plan(
  self : RenderFrameSubmitRequest,
) -> RenderFrameSubmitPlan {
  self.schedule.get_submit_plan()
}

///|
pub fn RenderFrameSubmitRequest::get_action(
  self : RenderFrameSubmitRequest,
) -> RenderFrameScheduleAction {
  self.schedule.get_action()
}

///|
pub fn RenderFrameSubmitRequest::get_present_strategy(
  self : RenderFrameSubmitRequest,
) -> DirtyPresentStrategy {
  self.schedule.get_present_strategy()
}

///|
pub fn RenderFrameSubmitRequest::get_state(
  self : RenderFrameSubmitRequest,
) -> DirtySubmitState {
  self.schedule.get_state()
}

///|
pub fn RenderFrameSubmitRequest::get_dirty_bounds(
  self : RenderFrameSubmitRequest,
) -> PixelRect? {
  self.schedule.get_dirty_bounds()
}

///|
pub fn RenderFrameSubmitRequest::has_dirty(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.has_dirty()
}

///|
pub fn RenderFrameSubmitRequest::needs_present(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.needs_present()
}

///|
pub fn RenderFrameSubmitRequest::should_submit(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.should_submit()
}

///|
pub fn RenderFrameSubmitRequest::was_clipped_away(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.was_clipped_away()
}

///|
pub fn RenderFrameSubmitRequest::uses_bounds_fallback(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.uses_bounds_fallback()
}

///|
pub fn RenderFrameSubmitRequest::get_present_bounds(
  self : RenderFrameSubmitRequest,
) -> PixelRect? {
  self.schedule.get_present_bounds()
}

///|
pub fn RenderFrameSubmitRequest::get_present_rect_count(
  self : RenderFrameSubmitRequest,
) -> Int {
  self.schedule.get_present_rect_count()
}

///|
pub fn RenderFrameSubmitRequest::get_present_pixel_count(
  self : RenderFrameSubmitRequest,
) -> Int {
  self.schedule.get_present_pixel_count()
}

///|
pub fn RenderFrameSubmitRequest::get_present_byte_count(
  self : RenderFrameSubmitRequest,
) -> Int {
  self.schedule.get_present_byte_count()
}

///|
pub fn RenderFrameSubmitRequest::saves_full_present_pixels(
  self : RenderFrameSubmitRequest,
) -> Bool {
  self.schedule.saves_full_present_pixels()
}

///|
fn render_frame_submit_plan(
  dirty_submit_plan : DirtySubmitPlan,
  strategy : DirtyPresentStrategy,
  present_bounds : PixelRect?,
  present_rect_count : Int,
  present_pixel_count : Int,
  present_byte_count : Int,
) -> RenderFrameSubmitPlan {
  {
    dirty_submit_plan,
    strategy,
    present_bounds,
    present_rect_count,
    present_pixel_count,
    present_byte_count,
  }
}

///|
fn render_frame_submit_result(
  submit_plan : RenderFrameSubmitPlan,
  presented_rect_count : Int,
) -> RenderFrameSubmitResult {
  { submit_plan, presented_rect_count }
}

///|
fn render_frame_schedule(
  submit_plan : RenderFrameSubmitPlan,
) -> RenderFrameSchedule {
  let action = match submit_plan.get_state() {
    DirtySubmitState::Clean => RenderFrameScheduleAction::Skip
    DirtySubmitState::DirtyClippedAway =>
      RenderFrameScheduleAction::SubmitWithoutPresent
    DirtySubmitState::Present => RenderFrameScheduleAction::Present
  }
  render_frame_schedule_with_action(submit_plan, action)
}

///|
fn render_frame_schedule_with_action(
  submit_plan : RenderFrameSubmitPlan,
  action : RenderFrameScheduleAction,
) -> RenderFrameSchedule {
  { submit_plan, action }
}

///|
fn render_frame_submit_request(
  policy : RenderFrameSubmitPolicy,
  schedule : RenderFrameSchedule,
) -> RenderFrameSubmitRequest {
  RenderFrameSubmitRequest::new(policy, schedule)
}

///|
fn render_frame_full_present_plan(
  dirty_submit_plan : DirtySubmitPlan,
  frame_width : Int,
  frame_height : Int,
  surface_width : Int,
  surface_height : Int,
) -> RenderFrameSubmitPlan {
  let present_bounds = render_frame_full_present_bounds(
    frame_width, frame_height, surface_width, surface_height,
  )
  let present_pixels = match present_bounds {
    Some(bounds) => bounds.area()
    None => 0
  }
  let present_rect_count = if present_pixels > 0 { 1 } else { 0 }
  render_frame_submit_plan(
    dirty_submit_plan,
    DirtyPresentStrategy::Full,
    present_bounds,
    present_rect_count,
    present_pixels,
    present_pixels * 4,
  )
}

///|
fn render_frame_full_present_bounds(
  frame_width : Int,
  frame_height : Int,
  surface_width : Int,
  surface_height : Int,
) -> PixelRect? {
  let frame_bounds = PixelRect::new(
    x=0,
    y=0,
    width=frame_width.max(0),
    height=frame_height.max(0),
  )
  let surface_bounds = PixelRect::new(
    x=0,
    y=0,
    width=surface_width.max(0),
    height=surface_height.max(0),
  )
  frame_bounds.intersection(surface_bounds)
}

///|
fn render_frame_full_present_schedule(
  dirty_submit_plan : DirtySubmitPlan,
  frame_width : Int,
  frame_height : Int,
  surface_width : Int,
  surface_height : Int,
) -> RenderFrameSchedule {
  let submit_plan = render_frame_full_present_plan(
    dirty_submit_plan, frame_width, frame_height, surface_width, surface_height,
  )
  if submit_plan.get_present_rect_count() > 0 {
    render_frame_schedule_with_action(
      submit_plan,
      RenderFrameScheduleAction::Present,
    )
  } else {
    render_frame_schedule(submit_plan)
  }
}

///|
pub fn RenderFrame::new(width : Int, height : Int) -> RenderFrame {
  {
    canvas: Canvas::new(width, height),
    layer_tree: LayerTree::new(),
    dirty_rect_limit: default_dirty_present_rect_limit,
  }
}

///|
pub fn RenderFrame::get_canvas(self : RenderFrame) -> Canvas {
  self.canvas
}

///|
pub fn RenderFrame::get_layer_tree(self : RenderFrame) -> LayerTree {
  self.layer_tree
}

///|
pub fn RenderFrame::get_width(self : RenderFrame) -> Int {
  self.canvas.get_pixmap().get_width()
}

///|
pub fn RenderFrame::get_height(self : RenderFrame) -> Int {
  self.canvas.get_pixmap().get_height()
}

///|
pub fn RenderFrame::resize(
  self : RenderFrame,
  width : Int,
  height : Int,
) -> RenderFrame {
  let safe_width = width.max(0)
  let safe_height = height.max(0)
  guard safe_width != self.get_width() || safe_height != self.get_height() else {
    return self
  }
  let old_pixmap = self.canvas.get_pixmap()
  let new_canvas = Canvas::new(safe_width, safe_height)
  let copy_width = old_pixmap.get_width().min(safe_width)
  let copy_height = old_pixmap.get_height().min(safe_height)
  if copy_width > 0 && copy_height > 0 {
    new_canvas.draw_pixmap_rect(
      old_pixmap,
      PixelRect::new(x=0, y=0, width=copy_width, height=copy_height),
      0,
      0,
      Paint::new(),
    )
  }
  new_canvas.get_dirty_region().add_all(safe_width, safe_height)
  self.canvas = new_canvas
  self
}

///|
/// Resize the frame and a layer-sized background cache, then clear that layer.
/// Intended for GUI resize handlers that keep a full-frame background layer at
/// a stable index while other layers are replaced or redrawn separately.
pub fn RenderFrame::resize_and_clear_layer(
  self : RenderFrame,
  layer_index : Int,
  width : Int,
  height : Int,
  color : Color,
) -> Bool {
  self.resize_and_clear_layers(width, height, [
    RenderFrameLayerClearRequest::new(layer_index, color),
  ])
}

///|
/// Resize the frame and multiple layer-sized caches, then clear each layer.
/// This validates all requested layers before mutating frame or layer state.
pub fn RenderFrame::resize_and_clear_layers(
  self : RenderFrame,
  width : Int,
  height : Int,
  requests : Array[RenderFrameLayerClearRequest],
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard requests.length() > 0 else { return false }
  guard self.can_clear_layers(requests) else { return false }
  ignore(self.resize(width, height))
  self.clear_resized_layers(width, height, requests)
}

///|
/// Resize the frame, clear frame-sized layer caches, and replace redrawn layers.
/// This validates every requested layer before mutating frame or layer state.
pub fn RenderFrame::resize_clear_and_replace_layers(
  self : RenderFrame,
  width : Int,
  height : Int,
  clear_requests : Array[RenderFrameLayerClearRequest],
  replacement_requests : Array[RenderFrameLayerReplacementRequest],
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard clear_requests.length() > 0 || replacement_requests.length() > 0 else {
    return false
  }
  guard self.can_clear_layers(clear_requests) else { return false }
  guard self.can_replace_layers(replacement_requests) else { return false }
  ignore(self.resize(width, height))
  guard self.clear_resized_layers(width, height, clear_requests) else {
    return false
  }
  self.apply_layer_replacements(replacement_requests)
}

///|
fn RenderFrame::can_clear_layers(
  self : RenderFrame,
  requests : Array[RenderFrameLayerClearRequest],
) -> Bool {
  for request in requests {
    guard self.layer_tree.get_layer(request.get_layer_index()) is Some(_) else {
      return false
    }
  }
  true
}

///|
fn RenderFrame::clear_resized_layers(
  self : RenderFrame,
  width : Int,
  height : Int,
  requests : Array[RenderFrameLayerClearRequest],
) -> Bool {
  for request in requests {
    let layer_index = request.get_layer_index()
    ignore(self.layer_tree.resize_layer(layer_index, width, height))
    match self.layer_tree.get_layer(layer_index) {
      Some(layer) => layer.clear(request.get_color())
      None => return false
    }
  }
  true
}

///|
/// Replace one frame-owned layer and invalidate the old and new layer bounds.
pub fn RenderFrame::replace_layer(
  self : RenderFrame,
  layer_index : Int,
  layer : Layer,
) -> Layer? {
  self.layer_tree.replace_layer(layer_index, layer)
}

///|
/// Replace multiple frame-owned layers after validating every target index.
pub fn RenderFrame::replace_layers(
  self : RenderFrame,
  requests : Array[RenderFrameLayerReplacementRequest],
) -> Bool {
  guard requests.length() > 0 else { return false }
  guard self.can_replace_layers(requests) else { return false }
  self.apply_layer_replacements(requests)
}

///|
fn RenderFrame::can_replace_layers(
  self : RenderFrame,
  requests : Array[RenderFrameLayerReplacementRequest],
) -> Bool {
  for request in requests {
    guard self.layer_tree.get_layer(request.get_layer_index()) is Some(_) else {
      return false
    }
  }
  true
}

///|
fn RenderFrame::apply_layer_replacements(
  self : RenderFrame,
  requests : Array[RenderFrameLayerReplacementRequest],
) -> Bool {
  for request in requests {
    ignore(
      self.layer_tree.replace_layer(
        request.get_layer_index(),
        request.get_layer(),
      ),
    )
  }
  true
}

///|
pub fn RenderFrame::get_dirty_rect_limit(self : RenderFrame) -> Int {
  self.dirty_rect_limit
}

///|
pub fn RenderFrame::set_dirty_rect_limit(
  self : RenderFrame,
  limit : Int,
) -> RenderFrame {
  self.dirty_rect_limit = limit
  self
}

///|
pub fn RenderFrame::mark_dirty_rect(
  self : RenderFrame,
  rect : PixelRect,
) -> Unit {
  self.canvas.get_dirty_region().add_rect(rect)
}

///|
pub fn RenderFrame::mark_all_dirty(self : RenderFrame) -> Unit {
  self.canvas.get_dirty_region().add_all(self.get_width(), self.get_height())
}

///|
pub fn RenderFrame::dirty_bounds(self : RenderFrame) -> PixelRect? {
  match self.canvas.get_dirty_region().bounds() {
    Some(canvas_bounds) =>
      match self.layer_tree.dirty_bounds() {
        Some(layer_bounds) => Some(canvas_bounds.union(layer_bounds))
        None => Some(canvas_bounds)
      }
    None => self.layer_tree.dirty_bounds()
  }
}

///|
pub fn RenderFrame::has_dirty(self : RenderFrame) -> Bool {
  match self.dirty_bounds() {
    Some(_) => true
    None => false
  }
}

///|
pub fn RenderFrame::clear_dirty_regions(self : RenderFrame) -> Unit {
  self.canvas.clear_dirty_region()
  self.layer_tree.clear_dirty_regions()
}

///|
pub fn[S : Surface] RenderFrame::dirty_present_plan(
  self : RenderFrame,
  surface : S,
) -> DirtyPresentPlan {
  self.dirty_submit_plan(surface).get_present_plan()
}

///|
pub fn[S : Surface] RenderFrame::dirty_submit_plan(
  self : RenderFrame,
  surface : S,
) -> DirtySubmitPlan {
  self.layer_tree.dirty_submit_plan(self.canvas, surface, self.dirty_rect_limit)
}

///|
pub fn[S : Surface] RenderFrame::dirty_present_batch(
  self : RenderFrame,
  surface : S,
) -> Result[PresentBatch, PresentError] {
  self.layer_tree.dirty_present_batch(
    self.canvas,
    surface,
    self.dirty_rect_limit,
  )
}

///|
pub fn[S : Surface] RenderFrame::present_strategy(
  self : RenderFrame,
  surface : S,
) -> DirtyPresentStrategy {
  self
  .dirty_submit_plan(surface)
  .get_present_strategy(surface.get_width(), surface.get_height())
}

///|
pub fn[S : Surface] RenderFrame::submit_by_strategy_plan(
  self : RenderFrame,
  surface : S,
) -> RenderFrameSubmitPlan {
  self.layer_tree.submit_by_strategy_plan(
    self.canvas,
    surface,
    self.dirty_rect_limit,
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_schedule(
  self : RenderFrame,
  surface : S,
) -> RenderFrameSchedule {
  self.layer_tree.submit_schedule(self.canvas, surface, self.dirty_rect_limit)
}

///|
/// Dry-run a window redraw submission. Dirty frames reuse the regular schedule;
/// clean frames are promoted to a full cached present so OS redraw requests can
/// repaint without each event loop reimplementing that policy.
pub fn[S : Surface] RenderFrame::redraw_schedule(
  self : RenderFrame,
  surface : S,
) -> RenderFrameSchedule {
  self.submit_schedule_by_policy(surface, RenderFrameSubmitPolicy::CachedRedraw)
}

///|
pub fn[S : Surface] RenderFrame::submit_schedule_by_policy(
  self : RenderFrame,
  surface : S,
  policy : RenderFrameSubmitPolicy,
) -> RenderFrameSchedule {
  self.layer_tree.submit_schedule_by_policy(
    self.canvas,
    surface,
    self.dirty_rect_limit,
    policy,
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_request_by_policy(
  self : RenderFrame,
  surface : S,
  policy : RenderFrameSubmitPolicy,
) -> RenderFrameSubmitRequest {
  render_frame_submit_request(
    policy,
    self.submit_schedule_by_policy(surface, policy),
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_scheduled_to(
  self : RenderFrame,
  surface : S,
  schedule : RenderFrameSchedule,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.layer_tree.submit_scheduled_to_with_limit(
    self.canvas,
    surface,
    self.dirty_rect_limit,
    schedule,
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_redraw_to(
  self : RenderFrame,
  surface : S,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_to_by_policy(surface, RenderFrameSubmitPolicy::CachedRedraw)
}

///|
pub fn[S : Surface] RenderFrame::submit_to_by_policy(
  self : RenderFrame,
  surface : S,
  policy : RenderFrameSubmitPolicy,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_scheduled_to(
    surface,
    self.submit_schedule_by_policy(surface, policy),
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_request_to(
  self : RenderFrame,
  surface : S,
  request : RenderFrameSubmitRequest,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.layer_tree.submit_request_to_with_limit(
    self.canvas,
    surface,
    self.dirty_rect_limit,
    request,
  )
}

///|
pub fn[S : Surface] RenderFrame::present_dirty_to(
  self : RenderFrame,
  surface : S,
) -> Result[Int, PresentError] {
  self.layer_tree.present_dirty_to_with_limit(
    self.canvas,
    surface,
    self.dirty_rect_limit,
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_dirty_to(
  self : RenderFrame,
  surface : S,
) -> Result[DirtySubmitResult, PresentError] {
  self.layer_tree.submit_dirty_to_with_limit(
    self.canvas,
    surface,
    self.dirty_rect_limit,
  )
}

///|
pub fn[S : Surface] RenderFrame::submit_by_strategy_to(
  self : RenderFrame,
  surface : S,
) -> Result[RenderFrameSubmitResult, PresentError] {
  self.submit_scheduled_to(surface, self.submit_schedule(surface))
}

///|
pub fn[S : Surface] RenderFrame::present_all_to(
  self : RenderFrame,
  surface : S,
) -> Result[Int, PresentError] {
  self.layer_tree.present_all_to_with_limit(
    self.canvas,
    surface,
    self.dirty_rect_limit,
  )
}
