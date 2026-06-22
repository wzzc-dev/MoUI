///|
/// Error returned when presenting RGBA pixels to a surface fails.
pub(all) enum PresentError {
  InvalidDimensions(Int, Int)
  SizeMismatch(Int, Int, Int, Int)
  RectOutOfBounds(Int, Int, Int, Int, Int, Int)
  InvalidRowBytes(Int, Int)
  PixelBufferTooSmall(Int, Int)
} derive(Eq, Debug)

///|
/// Validated geometry for a rectangle present call. Backends can use this to
/// share row-stride and buffer-size checks with the reference MemorySurface.
pub(all) struct PresentRectInfo {
  required_row_bytes : Int
  required_len : Int
} derive(Eq, Debug)

///|
/// Packed source pixels for one rectangle present operation.
pub struct PresentRectPayload {
  rect : PixelRect
  row_bytes : Int
  pixels : FixedArray[Byte]
} derive(Debug)

///|
/// A materialized batch of packed rectangle present payloads.
pub struct PresentBatch {
  payloads : Array[PresentRectPayload]
  present_pixel_count : Int
  present_byte_count : Int
} derive(Debug)

///|
/// Validated dry-run plan for submitting a materialized present batch to a
/// concrete surface.
pub struct PresentBatchSubmitPlan {
  batch : PresentBatch
  surface_width : Int
  surface_height : Int
} derive(Debug)

///|
/// Result of submitting a materialized present batch to a concrete surface.
pub struct PresentBatchSubmitResult {
  submit_plan : PresentBatchSubmitPlan
  presented_rect_count : Int
} derive(Debug)

///|
/// One validated present operation recorded by MemorySurface.
pub struct MemoryPresentRecord {
  rect : PixelRect
  row_bytes : Int
} derive(Eq, Debug)

///|
pub fn PresentRectInfo::required_row_bytes(self : PresentRectInfo) -> Int {
  self.required_row_bytes
}

///|
pub fn PresentRectInfo::required_len(self : PresentRectInfo) -> Int {
  self.required_len
}

///|
/// Build a validated rectangle present payload from caller-provided RGBA rows.
pub fn PresentRectPayload::new(
  rect : PixelRect,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[PresentRectPayload, PresentError] {
  match
    validate_present_rect(
      rect.x + rect.width,
      rect.y + rect.height,
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      row_bytes,
      pixels,
    ) {
    Ok(_) => Ok({ rect, row_bytes, pixels: copy_byte_pixels(pixels) })
    Err(error) => Err(error)
  }
}

///|
pub fn PresentRectPayload::get_rect(self : PresentRectPayload) -> PixelRect {
  self.rect
}

///|
pub fn PresentRectPayload::get_row_bytes(self : PresentRectPayload) -> Int {
  self.row_bytes
}

///|
pub fn PresentRectPayload::get_pixels(
  self : PresentRectPayload,
) -> FixedArray[Byte] {
  copy_byte_pixels(self.pixels)
}

///|
pub fn PresentRectPayload::get_present_pixel_count(
  self : PresentRectPayload,
) -> Int {
  self.rect.area()
}

///|
pub fn PresentRectPayload::get_present_byte_count(
  self : PresentRectPayload,
) -> Int {
  self.get_present_pixel_count() * 4
}

///|
pub fn PresentRectPayload::get_source_byte_count(
  self : PresentRectPayload,
) -> Int {
  self.row_bytes * self.rect.height
}

///|
pub fn PresentRectPayload::get_source_padding_byte_count(
  self : PresentRectPayload,
) -> Int {
  (self.get_source_byte_count() - self.get_present_byte_count()).max(0)
}

///|
pub fn[S : Surface] PresentRectPayload::submit_to(
  self : PresentRectPayload,
  surface : S,
) -> Result[Unit, PresentError] {
  surface.present_pixels_rect(
    self.rect.x,
    self.rect.y,
    self.rect.width,
    self.rect.height,
    self.row_bytes,
    copy_byte_pixels(self.pixels),
  )
}

///|
pub fn PresentBatch::get_payloads(
  self : PresentBatch,
) -> Array[PresentRectPayload] {
  copy_present_payloads(self.payloads)
}

///|
pub fn PresentBatch::get_rect_count(self : PresentBatch) -> Int {
  self.payloads.length()
}

///|
pub fn PresentBatch::get_present_bounds(self : PresentBatch) -> PixelRect? {
  let rects = []
  for payload in self.payloads {
    rects.push(payload.get_rect())
  }
  pixel_rect_array_bounds(rects)
}

///|
pub fn PresentBatch::is_empty(self : PresentBatch) -> Bool {
  self.payloads.length() == 0
}

///|
pub fn PresentBatch::get_present_pixel_count(self : PresentBatch) -> Int {
  self.present_pixel_count
}

///|
pub fn PresentBatch::get_present_byte_count(self : PresentBatch) -> Int {
  self.present_byte_count
}

///|
pub fn PresentBatch::saves_full_present_pixels(
  self : PresentBatch,
  width : Int,
  height : Int,
) -> Bool {
  self.get_full_present_pixel_savings(width, height) > 0
}

///|
/// Return how many pixels this batch avoids compared with presenting the full
/// target surface. Empty batches report no savings because they represent skip,
/// not a partial present.
pub fn PresentBatch::get_full_present_pixel_savings(
  self : PresentBatch,
  width : Int,
  height : Int,
) -> Int {
  guard !self.is_empty() else { return 0 }
  let full_pixels = PixelRect::new(x=0, y=0, width~, height~).area()
  guard full_pixels > 0 else { return 0 }
  (full_pixels - self.present_pixel_count).max(0)
}

///|
/// Return how many packed RGBA bytes this batch avoids compared with presenting
/// the full target surface.
pub fn PresentBatch::get_full_present_byte_savings(
  self : PresentBatch,
  width : Int,
  height : Int,
) -> Int {
  self.get_full_present_pixel_savings(width, height) * 4
}

///|
pub fn PresentBatch::get_present_strategy(
  self : PresentBatch,
  width : Int,
  height : Int,
) -> DirtyPresentStrategy {
  guard !self.is_empty() else { return DirtyPresentStrategy::Skip }
  if self.saves_full_present_pixels(width, height) {
    DirtyPresentStrategy::Partial
  } else {
    DirtyPresentStrategy::Full
  }
}

///|
pub fn PresentBatch::get_source_byte_count(self : PresentBatch) -> Int {
  let mut bytes = 0
  for payload in self.payloads {
    bytes = bytes + payload.get_source_byte_count()
  }
  bytes
}

///|
pub fn PresentBatch::get_source_padding_byte_count(self : PresentBatch) -> Int {
  let mut bytes = 0
  for payload in self.payloads {
    bytes = bytes + payload.get_source_padding_byte_count()
  }
  bytes
}

///|
pub fn PresentBatchSubmitPlan::get_batch(
  self : PresentBatchSubmitPlan,
) -> PresentBatch {
  copy_present_batch(self.batch)
}

///|
pub fn PresentBatchSubmitPlan::get_surface_width(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.surface_width
}

///|
pub fn PresentBatchSubmitPlan::get_surface_height(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.surface_height
}

///|
pub fn PresentBatchSubmitPlan::get_present_strategy(
  self : PresentBatchSubmitPlan,
) -> DirtyPresentStrategy {
  self.batch.get_present_strategy(self.surface_width, self.surface_height)
}

///|
pub fn PresentBatchSubmitPlan::get_rect_count(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_rect_count()
}

///|
pub fn PresentBatchSubmitPlan::needs_present(
  self : PresentBatchSubmitPlan,
) -> Bool {
  !self.batch.is_empty()
}

///|
pub fn PresentBatchSubmitPlan::get_present_bounds(
  self : PresentBatchSubmitPlan,
) -> PixelRect? {
  self.batch.get_present_bounds()
}

///|
pub fn PresentBatchSubmitPlan::get_present_pixel_count(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_present_pixel_count()
}

///|
pub fn PresentBatchSubmitPlan::get_present_byte_count(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_present_byte_count()
}

///|
pub fn PresentBatchSubmitPlan::get_source_byte_count(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_source_byte_count()
}

///|
pub fn PresentBatchSubmitPlan::get_source_padding_byte_count(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_source_padding_byte_count()
}

///|
pub fn PresentBatchSubmitPlan::saves_full_present_pixels(
  self : PresentBatchSubmitPlan,
) -> Bool {
  self.batch.saves_full_present_pixels(self.surface_width, self.surface_height)
}

///|
pub fn PresentBatchSubmitPlan::get_full_present_pixel_savings(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_full_present_pixel_savings(
    self.surface_width,
    self.surface_height,
  )
}

///|
pub fn PresentBatchSubmitPlan::get_full_present_byte_savings(
  self : PresentBatchSubmitPlan,
) -> Int {
  self.batch.get_full_present_byte_savings(
    self.surface_width,
    self.surface_height,
  )
}

///|
pub fn PresentBatchSubmitResult::get_submit_plan(
  self : PresentBatchSubmitResult,
) -> PresentBatchSubmitPlan {
  copy_present_batch_submit_plan(self.submit_plan)
}

///|
pub fn PresentBatchSubmitResult::get_batch(
  self : PresentBatchSubmitResult,
) -> PresentBatch {
  self.submit_plan.get_batch()
}

///|
fn copy_byte_pixels(src : FixedArray[Byte]) -> FixedArray[Byte] {
  let dst : FixedArray[Byte] = FixedArray::make(src.length(), 0)
  for i in 0..<src.length() {
    dst[i] = src[i]
  }
  dst
}

///|
fn copy_present_payload(payload : PresentRectPayload) -> PresentRectPayload {
  {
    rect: payload.rect,
    row_bytes: payload.row_bytes,
    pixels: copy_byte_pixels(payload.pixels),
  }
}

///|
fn copy_present_payloads(
  payloads : Array[PresentRectPayload],
) -> Array[PresentRectPayload] {
  let copied = []
  for payload in payloads {
    copied.push(copy_present_payload(payload))
  }
  copied
}

///|
fn copy_present_batch(batch : PresentBatch) -> PresentBatch {
  {
    payloads: copy_present_payloads(batch.payloads),
    present_pixel_count: batch.present_pixel_count,
    present_byte_count: batch.present_byte_count,
  }
}

///|
fn copy_present_batch_submit_plan(
  plan : PresentBatchSubmitPlan,
) -> PresentBatchSubmitPlan {
  {
    batch: copy_present_batch(plan.batch),
    surface_width: plan.surface_width,
    surface_height: plan.surface_height,
  }
}

///|
pub fn PresentBatchSubmitResult::get_surface_width(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_surface_width()
}

///|
pub fn PresentBatchSubmitResult::get_surface_height(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_surface_height()
}

///|
pub fn PresentBatchSubmitResult::get_present_strategy(
  self : PresentBatchSubmitResult,
) -> DirtyPresentStrategy {
  self.submit_plan.get_present_strategy()
}

///|
pub fn PresentBatchSubmitResult::get_rect_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_rect_count()
}

///|
pub fn PresentBatchSubmitResult::get_presented_rect_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.presented_rect_count
}

///|
pub fn PresentBatchSubmitResult::did_present(
  self : PresentBatchSubmitResult,
) -> Bool {
  self.presented_rect_count > 0
}

///|
pub fn PresentBatchSubmitResult::needs_present(
  self : PresentBatchSubmitResult,
) -> Bool {
  self.submit_plan.needs_present()
}

///|
pub fn PresentBatchSubmitResult::get_present_bounds(
  self : PresentBatchSubmitResult,
) -> PixelRect? {
  self.submit_plan.get_present_bounds()
}

///|
pub fn PresentBatchSubmitResult::get_present_pixel_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_present_pixel_count()
}

///|
pub fn PresentBatchSubmitResult::get_present_byte_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_present_byte_count()
}

///|
pub fn PresentBatchSubmitResult::get_source_byte_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_source_byte_count()
}

///|
pub fn PresentBatchSubmitResult::get_source_padding_byte_count(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_source_padding_byte_count()
}

///|
pub fn PresentBatchSubmitResult::saves_full_present_pixels(
  self : PresentBatchSubmitResult,
) -> Bool {
  self.submit_plan.saves_full_present_pixels()
}

///|
pub fn PresentBatchSubmitResult::get_full_present_pixel_savings(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_full_present_pixel_savings()
}

///|
pub fn PresentBatchSubmitResult::get_full_present_byte_savings(
  self : PresentBatchSubmitResult,
) -> Int {
  self.submit_plan.get_full_present_byte_savings()
}

///|
pub fn MemoryPresentRecord::get_rect(self : MemoryPresentRecord) -> PixelRect {
  self.rect
}

///|
pub fn MemoryPresentRecord::get_row_bytes(self : MemoryPresentRecord) -> Int {
  self.row_bytes
}

///|
pub fn MemoryPresentRecord::get_present_pixel_count(
  self : MemoryPresentRecord,
) -> Int {
  self.rect.area()
}

///|
pub fn MemoryPresentRecord::get_present_byte_count(
  self : MemoryPresentRecord,
) -> Int {
  self.get_present_pixel_count() * 4
}

///|
pub fn MemoryPresentRecord::get_source_byte_count(
  self : MemoryPresentRecord,
) -> Int {
  self.row_bytes * self.rect.height
}

///|
pub fn MemoryPresentRecord::get_source_padding_byte_count(
  self : MemoryPresentRecord,
) -> Int {
  (self.get_source_byte_count() - self.get_present_byte_count()).max(0)
}

///|
/// Validate every payload in this batch against a target surface before any
/// present call mutates backend state.
pub fn[S : Surface] PresentBatch::validate_for(
  self : PresentBatch,
  surface : S,
) -> Result[Unit, PresentError] {
  for payload in self.payloads {
    match
      validate_present_rect(
        surface.get_width(),
        surface.get_height(),
        payload.rect.x,
        payload.rect.y,
        payload.rect.width,
        payload.rect.height,
        payload.row_bytes,
        payload.pixels,
      ) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(())
}

///|
/// Build a validated dry-run submit plan for this packed batch without
/// presenting any payloads to the surface.
pub fn[S : Surface] PresentBatch::submit_plan_for(
  self : PresentBatch,
  surface : S,
) -> Result[PresentBatchSubmitPlan, PresentError] {
  let surface_width = surface.get_width()
  let surface_height = surface.get_height()
  match self.validate_for(surface) {
    Ok(_) => Ok({ batch: self, surface_width, surface_height })
    Err(error) => Err(error)
  }
}

///|
pub fn[S : Surface] PresentBatch::submit_to(
  self : PresentBatch,
  surface : S,
) -> Result[Int, PresentError] {
  match self.submit_to_result(surface) {
    Ok(result) => Ok(result.get_presented_rect_count())
    Err(error) => Err(error)
  }
}

///|
pub fn[S : Surface] PresentBatch::submit_to_result(
  self : PresentBatch,
  surface : S,
) -> Result[PresentBatchSubmitResult, PresentError] {
  let submit_plan = match self.submit_plan_for(surface) {
    Ok(plan) => plan
    Err(error) => return Err(error)
  }
  submit_plan.submit_to_result(surface)
}

///|
/// Submit this prevalidated plan to a surface with the same dimensions.
pub fn[S : Surface] PresentBatchSubmitPlan::submit_to(
  self : PresentBatchSubmitPlan,
  surface : S,
) -> Result[Int, PresentError] {
  match self.submit_to_result(surface) {
    Ok(result) => Ok(result.get_presented_rect_count())
    Err(error) => Err(error)
  }
}

///|
/// Submit this prevalidated plan and return lifecycle telemetry.
///
/// The target surface must still match the dimensions captured by the dry-run
/// plan, so stale resize-era plans fail before any backend present call.
pub fn[S : Surface] PresentBatchSubmitPlan::submit_to_result(
  self : PresentBatchSubmitPlan,
  surface : S,
) -> Result[PresentBatchSubmitResult, PresentError] {
  let surface_width = surface.get_width()
  let surface_height = surface.get_height()
  guard surface_width == self.surface_width &&
    surface_height == self.surface_height else {
    return Err(
      PresentError::SizeMismatch(
        self.surface_width,
        self.surface_height,
        surface_width,
        surface_height,
      ),
    )
  }
  match self.batch.validate_for(surface) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let mut presented = 0
  for payload in self.batch.payloads {
    match payload.submit_to(surface) {
      Ok(_) => presented = presented + 1
      Err(error) => return Err(error)
    }
  }
  Ok({ submit_plan: self, presented_rect_count: presented })
}

///|
/// Destination for CPU-rendered RGBA pixels.
pub(open) trait Surface {
  fn get_width(Self) -> Int
  fn get_height(Self) -> Int
  fn present_pixels(
    Self,
    width : Int,
    height : Int,
    row_bytes : Int,
    pixels : FixedArray[Byte],
  ) -> Result[Unit, PresentError]
  fn present_pixels_rect(
    Self,
    x : Int,
    y : Int,
    width : Int,
    height : Int,
    row_bytes : Int,
    pixels : FixedArray[Byte],
  ) -> Result[Unit, PresentError]
}

///|
/// In-memory surface used as the reference backend for tests and headless tools.
pub struct MemorySurface {
  width : Int
  height : Int
  pixels : FixedArray[Byte]
  mut present_count : Int
  present_records : Array[MemoryPresentRecord]
} derive(Debug)

///|
pub fn MemorySurface::new(width : Int, height : Int) -> MemorySurface {
  let safe_width = width.max(0)
  let safe_height = height.max(0)
  {
    width: safe_width,
    height: safe_height,
    pixels: FixedArray::make(safe_width * safe_height * 4, 0),
    present_count: 0,
    present_records: [],
  }
}

///|
pub fn MemorySurface::get_width(self : MemorySurface) -> Int {
  self.width
}

///|
pub fn MemorySurface::get_height(self : MemorySurface) -> Int {
  self.height
}

///|
/// Return a copied snapshot of the surface's RGBA pixels.
pub fn MemorySurface::get_pixels(self : MemorySurface) -> FixedArray[Byte] {
  copy_byte_pixels(self.pixels)
}

///|
pub fn MemorySurface::get_present_count(self : MemorySurface) -> Int {
  self.present_count
}

///|
pub fn MemorySurface::get_present_pixel_count(self : MemorySurface) -> Int {
  let mut pixels = 0
  for record in self.present_records {
    pixels = pixels + record.get_present_pixel_count()
  }
  pixels
}

///|
pub fn MemorySurface::get_present_byte_count(self : MemorySurface) -> Int {
  let mut bytes = 0
  for record in self.present_records {
    bytes = bytes + record.get_present_byte_count()
  }
  bytes
}

///|
pub fn MemorySurface::get_present_source_byte_count(
  self : MemorySurface,
) -> Int {
  let mut bytes = 0
  for record in self.present_records {
    bytes = bytes + record.get_source_byte_count()
  }
  bytes
}

///|
pub fn MemorySurface::get_present_source_padding_byte_count(
  self : MemorySurface,
) -> Int {
  let mut bytes = 0
  for record in self.present_records {
    bytes = bytes + record.get_source_padding_byte_count()
  }
  bytes
}

///|
pub fn MemorySurface::get_present_records(
  self : MemorySurface,
) -> Array[MemoryPresentRecord] {
  copy_memory_present_records(self.present_records)
}

///|
pub fn MemorySurface::get_present_bounds(self : MemorySurface) -> PixelRect? {
  let rects = []
  for record in self.present_records {
    rects.push(record.get_rect())
  }
  pixel_rect_array_bounds(rects)
}

///|
pub fn MemorySurface::get_last_present_record(
  self : MemorySurface,
) -> MemoryPresentRecord? {
  guard self.present_records.length() > 0 else { return None }
  Some(self.present_records[self.present_records.length() - 1])
}

///|
fn copy_memory_present_records(
  records : Array[MemoryPresentRecord],
) -> Array[MemoryPresentRecord] {
  let copied = []
  for record in records {
    copied.push(record)
  }
  copied
}

///|
/// Clear accumulated present telemetry while preserving surface pixels.
pub fn MemorySurface::reset_present_telemetry(self : MemorySurface) -> Unit {
  self.present_count = 0
  while self.present_records.length() > 0 {
    ignore(self.present_records.remove(self.present_records.length() - 1))
  }
}

///|
pub fn MemorySurface::get_pixel(
  self : MemorySurface,
  x : Int,
  y : Int,
) -> Color {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else {
    return Color::transparent()
  }
  let idx = (y * self.width + x) * 4
  Color::new(
    r=self.pixels[idx],
    g=self.pixels[idx + 1],
    b=self.pixels[idx + 2],
    a=self.pixels[idx + 3],
  )
}

///|
/// Snapshot this in-memory surface into an isolated pixmap.
pub fn MemorySurface::to_pixmap(self : MemorySurface) -> Pixmap {
  let pixmap = Pixmap::new(self.width, self.height)
  let dst = pixmap.get_pixels()
  for i in 0..<self.pixels.length() {
    dst[i] = self.pixels[i]
  }
  pixmap
}

///|
/// Encode the current surface pixels as deterministic binary PPM(P6) bytes.
pub fn MemorySurface::to_ppm_bytes(self : MemorySurface) -> Bytes {
  self.to_pixmap().to_ppm_bytes()
}

///|
/// Encode the current surface pixels as deterministic 32-bit BMP(BGRA) bytes.
pub fn MemorySurface::to_bmp_bytes(self : MemorySurface) -> Bytes {
  self.to_pixmap().to_bmp_bytes()
}

///|
/// Encode the current surface pixels as deterministic 8-bit RGBA PNG bytes.
pub fn MemorySurface::to_png_bytes(
  self : MemorySurface,
) -> Result[Bytes, PixmapEncodeError] {
  self.to_pixmap().to_png_bytes()
}

///|
/// Return an isolated copy of the current surface RGBA pixel bytes.
pub fn MemorySurface::to_rgba_bytes(self : MemorySurface) -> Bytes {
  rgba_bytes_from_pixels(self.pixels)
}

///|
/// Return a deterministic lightweight checksum of the current surface pixels.
pub fn MemorySurface::checksum(self : MemorySurface) -> Int {
  checksum_rgba_bytes(self.pixels)
}

///|
/// Snapshot a rectangle of this in-memory surface into an isolated pixmap.
pub fn MemorySurface::to_pixmap_rect(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Pixmap, PresentError] {
  match validate_pixel_rect_bounds(self.width, self.height, rect) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(
        pixmap_from_packed_rgba(
          rect.width,
          rect.height,
          copy_rgba_rect(self.pixels, self.width, rect),
        ),
      )
  }
}

///|
/// Encode a rectangle of this surface as deterministic binary PPM(P6) bytes.
pub fn MemorySurface::to_ppm_rect_bytes(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.to_pixmap_rect(rect) {
    Ok(pixmap) => Ok(pixmap.to_ppm_bytes())
    Err(error) => Err(error)
  }
}

///|
/// Encode a rectangle of this surface as deterministic 32-bit BMP(BGRA) bytes.
pub fn MemorySurface::to_bmp_rect_bytes(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.to_pixmap_rect(rect) {
    Ok(pixmap) => Ok(pixmap.to_bmp_bytes())
    Err(error) => Err(error)
  }
}

///|
/// Encode a rectangle of this surface as deterministic 8-bit RGBA PNG bytes.
pub fn MemorySurface::to_png_rect_bytes(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.to_pixmap_rect(rect) {
    Ok(pixmap) =>
      match pixmap.to_png_bytes() {
        Ok(bytes) => Ok(bytes)
        Err(_) => Err(PresentError::InvalidDimensions(rect.width, rect.height))
      }
    Err(error) => Err(error)
  }
}

///|
/// Return packed RGBA bytes for a surface rectangle in row-major order.
pub fn MemorySurface::to_rgba_rect_bytes(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match validate_pixel_rect_bounds(self.width, self.height, rect) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(rgba_bytes_from_pixels(copy_rgba_rect(self.pixels, self.width, rect)))
  }
}

///|
/// Return a deterministic lightweight checksum of a surface rectangle.
pub fn MemorySurface::checksum_rect(
  self : MemorySurface,
  rect : PixelRect,
) -> Result[Int, PresentError] {
  match validate_pixel_rect_bounds(self.width, self.height, rect) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(checksum_rgba_bytes(copy_rgba_rect(self.pixels, self.width, rect)))
  }
}

///|
pub fn MemorySurface::present_pixels(
  self : MemorySurface,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, PresentError] {
  guard width > 0 && height > 0 else {
    return Err(PresentError::InvalidDimensions(width, height))
  }
  guard width == self.width && height == self.height else {
    return Err(
      PresentError::SizeMismatch(self.width, self.height, width, height),
    )
  }
  self.present_pixels_rect(0, 0, width, height, row_bytes, pixels)
}

///|
pub fn MemorySurface::present_pixels_rect(
  self : MemorySurface,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, PresentError] {
  match
    validate_present_rect(
      self.width,
      self.height,
      x,
      y,
      width,
      height,
      row_bytes,
      pixels,
    ) {
    Err(error) => return Err(error)
    Ok(info) => {
      for row in 0..<height {
        let src_row = row * row_bytes
        let dst_row = ((y + row) * self.width + x) * 4
        for column in 0..<info.required_row_bytes() {
          self.pixels[dst_row + column] = pixels[src_row + column]
        }
      }
      self.present_count = self.present_count + 1
      self.present_records.push({
        rect: PixelRect::new(x~, y~, width~, height~),
        row_bytes,
      })
      Ok(())
    }
  }
}

///|
pub fn validate_present_rect(
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[PresentRectInfo, PresentError] {
  guard width > 0 && height > 0 else {
    return Err(PresentError::InvalidDimensions(width, height))
  }
  guard x >= 0 &&
    y >= 0 &&
    width <= surface_width - x &&
    height <= surface_height - y else {
    return Err(
      PresentError::RectOutOfBounds(
        x, y, width, height, surface_width, surface_height,
      ),
    )
  }
  let required_row_bytes = width * 4
  guard row_bytes >= required_row_bytes else {
    return Err(PresentError::InvalidRowBytes(row_bytes, required_row_bytes))
  }
  let required_len = row_bytes * (height - 1) + required_row_bytes
  guard pixels.length() >= required_len else {
    return Err(PresentError::PixelBufferTooSmall(pixels.length(), required_len))
  }
  Ok({ required_row_bytes, required_len })
}

///|
pub impl Surface for MemorySurface with fn get_width(self) {
  self.get_width()
}

///|
pub impl Surface for MemorySurface with fn get_height(self) {
  self.get_height()
}

///|
pub impl Surface for MemorySurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_pixels(width, height, row_bytes, pixels)
}

///|
pub impl Surface for MemorySurface with fn present_pixels_rect(
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
pub fn[S : Surface] present_pixels(
  surface : S,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, PresentError] {
  surface.present_pixels(width, height, row_bytes, pixels)
}

///|
pub fn[S : Surface] present_pixels_rect(
  surface : S,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, PresentError] {
  surface.present_pixels_rect(x, y, width, height, row_bytes, pixels)
}

///|
pub fn[S : Surface] Pixmap::present_to(
  self : Pixmap,
  surface : S,
) -> Result[Unit, PresentError] {
  surface.present_pixels(
    self.get_width(),
    self.get_height(),
    self.get_width() * 4,
    self.get_pixels(),
  )
}

///|
pub fn[S : Surface] Pixmap::present_rect_to(
  self : Pixmap,
  surface : S,
  rect : PixelRect,
) -> Result[Unit, PresentError] {
  match self.present_rect_payload(rect) {
    Ok(payload) => payload.submit_to(surface)
    Err(error) => Err(error)
  }
}

///|
pub fn Pixmap::present_rect_payload(
  self : Pixmap,
  rect : PixelRect,
) -> Result[PresentRectPayload, PresentError] {
  match validate_pixmap_present_rect(self, rect) {
    Err(error) => Err(error)
    Ok(_) => {
      let row_bytes = rect.width * 4
      Ok({ rect, row_bytes, pixels: copy_pixmap_rect(self, rect) })
    }
  }
}

///|
/// Snapshot a rectangle of this pixmap into an isolated pixmap.
pub fn Pixmap::copy_rect(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Pixmap, PresentError] {
  match validate_pixmap_present_rect(self, rect) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(
        pixmap_from_packed_rgba(
          rect.width,
          rect.height,
          copy_pixmap_rect(self, rect),
        ),
      )
  }
}

///|
/// Return a deterministic lightweight checksum of a pixmap rectangle.
pub fn Pixmap::checksum_rect(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Int, PresentError] {
  match validate_pixmap_present_rect(self, rect) {
    Err(error) => Err(error)
    Ok(_) => Ok(checksum_rgba_bytes(copy_pixmap_rect(self, rect)))
  }
}

///|
/// Return packed RGBA bytes for a pixmap rectangle in row-major order.
pub fn Pixmap::to_rgba_rect_bytes(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match validate_pixmap_present_rect(self, rect) {
    Err(error) => Err(error)
    Ok(_) => Ok(rgba_bytes_from_pixels(copy_pixmap_rect(self, rect)))
  }
}

///|
/// Encode a rectangle of this pixmap as deterministic binary PPM(P6) bytes.
pub fn Pixmap::to_ppm_rect_bytes(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.copy_rect(rect) {
    Ok(pixmap) => Ok(pixmap.to_ppm_bytes())
    Err(error) => Err(error)
  }
}

///|
/// Encode a rectangle of this pixmap as deterministic 32-bit BMP(BGRA) bytes.
pub fn Pixmap::to_bmp_rect_bytes(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.copy_rect(rect) {
    Ok(pixmap) => Ok(pixmap.to_bmp_bytes())
    Err(error) => Err(error)
  }
}

///|
/// Encode a rectangle of this pixmap as deterministic 8-bit RGBA PNG bytes.
pub fn Pixmap::to_png_rect_bytes(
  self : Pixmap,
  rect : PixelRect,
) -> Result[Bytes, PresentError] {
  match self.copy_rect(rect) {
    Ok(pixmap) =>
      match pixmap.to_png_bytes() {
        Ok(bytes) => Ok(bytes)
        Err(_) => Err(PresentError::InvalidDimensions(rect.width, rect.height))
      }
    Err(error) => Err(error)
  }
}

///|
pub fn Pixmap::present_batch(
  self : Pixmap,
  plan : DirtyPresentPlan,
) -> Result[PresentBatch, PresentError] {
  let payloads = []
  let mut present_pixel_count = 0
  let mut present_byte_count = 0
  for rect in plan.get_rects() {
    match self.present_rect_payload(rect) {
      Ok(payload) => {
        present_pixel_count = present_pixel_count +
          payload.get_present_pixel_count()
        present_byte_count = present_byte_count +
          payload.get_present_byte_count()
        payloads.push(payload)
      }
      Err(error) => return Err(error)
    }
  }
  Ok({ payloads, present_pixel_count, present_byte_count })
}

///|
pub fn[S : Surface] Canvas::present_to(
  self : Canvas,
  surface : S,
) -> Result[Unit, PresentError] {
  self.get_pixmap().present_to(surface)
}

///|
pub fn[S : Surface] Canvas::present_dirty_to(
  self : Canvas,
  surface : S,
) -> Result[Int, PresentError] {
  self.present_dirty_to_with_limit(surface, default_dirty_present_rect_limit)
}

///|
pub fn[S : Surface] Canvas::dirty_present_plan(
  self : Canvas,
  surface : S,
  max_rects : Int,
) -> DirtyPresentPlan {
  let dirty_region = self.get_dirty_region()
  guard !dirty_region.is_empty() else {
    return { mode: DirtyPresentPlanMode::Empty, rects: [] }
  }
  let surface_bounds = PixelRect::new(
    x=0,
    y=0,
    width=surface.get_width(),
    height=surface.get_height(),
  )
  let pixmap_bounds = PixelRect::new(
    x=0,
    y=0,
    width=self.get_pixmap().get_width(),
    height=self.get_pixmap().get_height(),
  )
  match surface_bounds.intersection(pixmap_bounds) {
    Some(present_bounds) => dirty_region.present_plan(present_bounds, max_rects)
    None => { mode: DirtyPresentPlanMode::Empty, rects: [] }
  }
}

///|
pub fn[S : Surface] Canvas::dirty_present_batch(
  self : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[PresentBatch, PresentError] {
  self.get_pixmap().present_batch(self.dirty_present_plan(surface, max_rects))
}

///|
pub fn[S : Surface] Canvas::present_dirty_to_with_limit(
  self : Canvas,
  surface : S,
  max_rects : Int,
) -> Result[Int, PresentError] {
  let dirty_region = self.get_dirty_region()
  guard !dirty_region.is_empty() else { return Ok(0) }
  let plan = self.dirty_present_plan(surface, max_rects)
  guard !plan.is_empty() else {
    self.clear_dirty_region()
    return Ok(0)
  }
  match self.present_dirty_plan_to(surface, plan) {
    Ok(presented) => {
      self.clear_dirty_region()
      Ok(presented)
    }
    Err(error) => Err(error)
  }
}

///|
fn[S : Surface] Canvas::present_dirty_plan_to(
  self : Canvas,
  surface : S,
  plan : DirtyPresentPlan,
) -> Result[Int, PresentError] {
  guard !plan.is_empty() else { return Ok(0) }
  match self.get_pixmap().present_batch(plan) {
    Ok(batch) => batch.submit_to(surface)
    Err(error) => Err(error)
  }
}

///|
let default_dirty_present_rect_limit = 32

///|
fn validate_pixmap_present_rect(
  pixmap : Pixmap,
  rect : PixelRect,
) -> Result[Unit, PresentError] {
  validate_pixel_rect_bounds(pixmap.get_width(), pixmap.get_height(), rect)
}

///|
fn validate_pixel_rect_bounds(
  width : Int,
  height : Int,
  rect : PixelRect,
) -> Result[Unit, PresentError] {
  guard !rect.is_empty() else {
    return Err(PresentError::InvalidDimensions(rect.width, rect.height))
  }
  guard rect.x >= 0 &&
    rect.y >= 0 &&
    rect.width <= width - rect.x &&
    rect.height <= height - rect.y else {
    return Err(
      PresentError::RectOutOfBounds(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        width,
        height,
      ),
    )
  }
  Ok(())
}

///|
fn copy_pixmap_rect(pixmap : Pixmap, rect : PixelRect) -> FixedArray[Byte] {
  copy_rgba_rect(pixmap.get_pixels(), pixmap.get_width(), rect)
}

///|
fn copy_rgba_rect(
  source : FixedArray[Byte],
  source_width : Int,
  rect : PixelRect,
) -> FixedArray[Byte] {
  let row_bytes = rect.width * 4
  let packed : FixedArray[Byte] = FixedArray::make(row_bytes * rect.height, 0)
  let source_row_bytes = source_width * 4
  for row in 0..<rect.height {
    let source_row = (rect.y + row) * source_row_bytes + rect.x * 4
    let packed_row = row * row_bytes
    for column in 0..<row_bytes {
      packed[packed_row + column] = source[source_row + column]
    }
  }
  packed
}

///|
fn pixmap_from_packed_rgba(
  width : Int,
  height : Int,
  pixels : FixedArray[Byte],
) -> Pixmap {
  let pixmap = Pixmap::new(width, height)
  let dst = pixmap.get_pixels()
  for i in 0..<dst.length() {
    dst[i] = pixels[i]
  }
  pixmap
}
