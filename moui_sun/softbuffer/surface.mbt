///|
/// A present target backed by a native window handle from another windowing
/// package.
pub struct NativeSurface {
  handle : UInt64
  mut width : Int
  mut height : Int
  mut pre_present_hook : (() -> Unit)?
}

///|
fn normalize_native_surface_dimension(value : Int) -> Int {
  value.max(0)
}

///|
/// Create a surface around a native window handle and an explicit pixel size.
pub fn NativeSurface::new(
  handle : UInt64,
  width : Int,
  height : Int,
) -> NativeSurface {
  {
    handle,
    width: normalize_native_surface_dimension(width),
    height: normalize_native_surface_dimension(height),
    pre_present_hook: None,
  }
}

///|
pub fn NativeSurface::from_frame(
  handle : UInt64,
  frame : @graphics.RenderFrame,
) -> NativeSurface {
  NativeSurface::new(handle, frame.get_width(), frame.get_height())
}

///|
pub fn NativeSurface::get_width(self : NativeSurface) -> Int {
  self.width
}

///|
pub fn NativeSurface::get_height(self : NativeSurface) -> Int {
  self.height
}

///|
pub fn NativeSurface::handle(self : NativeSurface) -> UInt64 {
  self.handle
}

///|
pub fn NativeSurface::resize(
  self : NativeSurface,
  width : Int,
  height : Int,
) -> Unit {
  self.width = normalize_native_surface_dimension(width)
  self.height = normalize_native_surface_dimension(height)
}

///|
/// Return whether this surface currently matches a frame's pixel dimensions.
pub fn NativeSurface::matches_frame(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Bool {
  self.width == frame.get_width() && self.height == frame.get_height()
}

///|
/// Sync this surface to a frame's pixel dimensions.
///
/// Returns true when the stored dimensions changed.
pub fn NativeSurface::sync_frame_size(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Bool {
  let width = frame.get_width()
  let height = frame.get_height()
  let changed = self.width != width || self.height != height
  self.width = width
  self.height = height
  changed
}

///|
/// Install a hook called immediately before a validated native present.
pub fn NativeSurface::with_pre_present_hook(
  self : NativeSurface,
  hook : () -> Unit,
) -> NativeSurface {
  self.pre_present_hook = Some(hook)
  self
}

///|
pub fn NativeSurface::clear_pre_present_hook(
  self : NativeSurface,
) -> NativeSurface {
  self.pre_present_hook = None
  self
}

///|
pub fn NativeSurface::present(
  self : NativeSurface,
  pixels : FixedArray[Byte],
) -> Result[Unit, @graphics.PresentError] {
  self.present_pixels(self.width, self.height, self.width * 4, pixels)
}

///|
/// Present an RGBA byte buffer from a Bytes value (preferred for FFI).
pub fn NativeSurface::present_bytes(
  self : NativeSurface,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
) -> Result[Unit, @graphics.PresentError] {
  guard width > 0 && height > 0 else {
    return Err(@graphics.PresentError::InvalidDimensions(width, height))
  }
  guard width == self.width && height == self.height else {
    return Err(
      @graphics.PresentError::SizeMismatch(
        self.width,
        self.height,
        width,
        height,
      ),
    )
  }
  present_bytes_to_handle(
    self.handle,
    self.width,
    self.height,
    0,
    0,
    width,
    height,
    row_bytes,
    pixels,
    pre_present_hook=self.pre_present_hook,
  )
}

///|
pub fn NativeSurface::present_pixels(
  self : NativeSurface,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, @graphics.PresentError] {
  guard width > 0 && height > 0 else {
    return Err(@graphics.PresentError::InvalidDimensions(width, height))
  }
  guard width == self.width && height == self.height else {
    return Err(
      @graphics.PresentError::SizeMismatch(
        self.width,
        self.height,
        width,
        height,
      ),
    )
  }
  present_rect_to_handle(
    self.handle,
    self.width,
    self.height,
    0,
    0,
    width,
    height,
    row_bytes,
    pixels,
    pre_present_hook=self.pre_present_hook,
  )
}

///|
pub fn NativeSurface::present_pixels_rect(
  self : NativeSurface,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, @graphics.PresentError] {
  present_rect_to_handle(
    self.handle,
    self.width,
    self.height,
    x,
    y,
    width,
    height,
    row_bytes,
    pixels,
    pre_present_hook=self.pre_present_hook,
  )
}

///|
pub fn NativeSurface::present_frame_dirty(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[Int, @graphics.PresentError] {
  frame.present_dirty_to(self)
}

///|
pub fn NativeSurface::submit_frame_dirty(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[@graphics.DirtySubmitResult, @graphics.PresentError] {
  frame.submit_dirty_to(self)
}

///|
pub fn NativeSurface::dirty_frame_submit_plan(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> @graphics.DirtySubmitPlan {
  frame.dirty_submit_plan(self)
}

///|
pub fn NativeSurface::dirty_frame_present_batch(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[@graphics.PresentBatch, @graphics.PresentError] {
  frame.dirty_present_batch(self)
}

///|
/// Build a validated dry-run submit plan for a materialized present batch.
pub fn NativeSurface::submit_present_batch_plan(
  self : NativeSurface,
  batch : @graphics.PresentBatch,
) -> Result[@graphics.PresentBatchSubmitPlan, @graphics.PresentError] {
  batch.submit_plan_for(self)
}

///|
/// Submit a materialized present batch and return lifecycle telemetry.
pub fn NativeSurface::submit_present_batch(
  self : NativeSurface,
  batch : @graphics.PresentBatch,
) -> Result[@graphics.PresentBatchSubmitResult, @graphics.PresentError] {
  batch.submit_to_result(self)
}

///|
pub fn NativeSurface::dirty_frame_present_strategy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> @graphics.DirtyPresentStrategy {
  self
  .dirty_frame_submit_plan(frame)
  .get_present_strategy(self.get_width(), self.get_height())
}

///|
pub fn NativeSurface::dirty_frame_submit_by_strategy_plan(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> @graphics.RenderFrameSubmitPlan {
  frame.submit_by_strategy_plan(self)
}

///|
pub fn NativeSurface::frame_schedule(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> @graphics.RenderFrameSchedule {
  frame.submit_schedule(self)
}

///|
pub fn NativeSurface::frame_redraw_schedule(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> @graphics.RenderFrameSchedule {
  frame.redraw_schedule(self)
}

///|
pub fn NativeSurface::frame_schedule_by_policy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  policy : @graphics.RenderFrameSubmitPolicy,
) -> @graphics.RenderFrameSchedule {
  frame.submit_schedule_by_policy(self, policy)
}

///|
pub fn NativeSurface::frame_submit_request_by_policy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  policy : @graphics.RenderFrameSubmitPolicy,
) -> @graphics.RenderFrameSubmitRequest {
  frame.submit_request_by_policy(self, policy)
}

///|
/// Sync this surface to the frame size, then build a submit request.
pub fn NativeSurface::sync_frame_submit_request_by_policy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  policy : @graphics.RenderFrameSubmitPolicy,
) -> @graphics.RenderFrameSubmitRequest {
  ignore(self.sync_frame_size(frame))
  self.frame_submit_request_by_policy(frame, policy)
}

///|
pub fn NativeSurface::submit_frame_schedule(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  schedule : @graphics.RenderFrameSchedule,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  frame.submit_scheduled_to(self, schedule)
}

///|
pub fn NativeSurface::submit_frame_redraw(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  frame.submit_redraw_to(self)
}

///|
pub fn NativeSurface::submit_frame_by_policy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  policy : @graphics.RenderFrameSubmitPolicy,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  frame.submit_to_by_policy(self, policy)
}

///|
/// Sync this surface to the frame size, then submit with an explicit policy.
pub fn NativeSurface::submit_synced_frame_by_policy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  policy : @graphics.RenderFrameSubmitPolicy,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  ignore(self.sync_frame_size(frame))
  self.submit_frame_by_policy(frame, policy)
}

///|
pub fn NativeSurface::submit_frame_request(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
  request : @graphics.RenderFrameSubmitRequest,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  frame.submit_request_to(self, request)
}

///|
pub fn NativeSurface::submit_frame_by_strategy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  frame.submit_by_strategy_to(self)
}

///|
/// Sync this surface to the frame size, then submit by dirty-present strategy.
pub fn NativeSurface::submit_synced_frame_by_strategy(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[@graphics.RenderFrameSubmitResult, @graphics.PresentError] {
  ignore(self.sync_frame_size(frame))
  self.submit_frame_by_strategy(frame)
}

///|
pub fn NativeSurface::present_frame_all(
  self : NativeSurface,
  frame : @graphics.RenderFrame,
) -> Result[Int, @graphics.PresentError] {
  frame.present_all_to(self)
}

///|
pub impl @graphics.Surface for NativeSurface with fn get_width(self) {
  self.get_width()
}

///|
pub impl @graphics.Surface for NativeSurface with fn get_height(self) {
  self.get_height()
}

///|
pub impl @graphics.Surface for NativeSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_pixels(width, height, row_bytes, pixels)
}

///|
pub impl @graphics.Surface for NativeSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_pixels_rect(x, y, width, height, row_bytes, pixels)
}

///|
fn present_rect_to_handle(
  handle : UInt64,
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
  pre_present_hook? : (() -> Unit)? = None,
) -> Result[Unit, @graphics.PresentError] {
  match
    @graphics.validate_present_rect(
      surface_width, surface_height, x, y, width, height, row_bytes, pixels,
    ) {
    Err(error) => Err(error)
    Ok(info) => {
      notify_pre_present(pre_present_hook)
      if row_bytes == info.required_row_bytes() {
        display_pixels_rect(
          handle, pixels, surface_width, surface_height, x, y, width, height,
        )
      } else {
        display_pixels_rect(
          handle,
          copy_tightly_packed_rows(
            height,
            row_bytes,
            info.required_row_bytes(),
            pixels,
          ),
          surface_width,
          surface_height,
          x,
          y,
          width,
          height,
        )
      }
      Ok(())
    }
  }
}

///|
///|
fn present_bytes_to_handle(
  handle : UInt64,
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pre_present_hook? : (() -> Unit)? = None,
) -> Result[Unit, @graphics.PresentError] {
  guard width > 0 && height > 0 else {
    return Err(@graphics.PresentError::InvalidDimensions(width, height))
  }
  guard row_bytes >= width * 4 else {
    return Err(
      @graphics.PresentError::InvalidRowBytes(row_bytes, width * 4),
    )
  }
  notify_pre_present(pre_present_hook)
  display_bytes_rect(
    handle, pixels, surface_width, surface_height, x, y, width, height,
  )
  Ok(())
}

///|
fn notify_pre_present(hook : (() -> Unit)?) -> Unit {
  match hook {
    Some(callback) => callback()
    None => ()
  }
}

///|
fn copy_tightly_packed_rows(
  height : Int,
  row_bytes : Int,
  packed_row_bytes : Int,
  pixels : FixedArray[Byte],
) -> FixedArray[Byte] {
  let packed : FixedArray[Byte] = FixedArray::make(
    packed_row_bytes * height,
    0b0,
  )
  for y in 0..<height {
    let src_row = y * row_bytes
    let dst_row = y * packed_row_bytes
    for x in 0..<packed_row_bytes {
      packed[dst_row + x] = pixels[src_row + x]
    }
  }
  packed
}
