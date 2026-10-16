///|
/// 字节出口。cell 投影的产物是 ANSI 文本而不是像素,而
/// `HostSurface::cpu_present()` 的 `PresentTarget` 与 `PixelFrame`
/// 几何(宽/高/row_bytes/scale)绑死,拿它传字节流会逼协议层为文本
/// 造一个假的像素帧。所以出口由 composition root 提供:
/// terminal backend 把它接到 stdout,测试把它接到捕获缓冲。
///
/// 这是对 sun 模板的唯一偏离,`host_surface_metrics_error` 仍然是
/// 共用的 bind 门禁。
pub(all) struct TuiSink {
  description : String
  write : (String) -> Unit
}

///|
pub fn TuiSink::new(
  description~ : String,
  write~ : (String) -> Unit,
) -> TuiSink {
  { description, write, }
}

///|
pub fn TuiSink::emit(self : TuiSink, bytes : String) -> Unit {
  (self.write)(bytes)
}

///|
pub fn TuiSink::describe(self : TuiSink) -> String {
  self.description
}

///|
/// 丢弃所有输出:用于只要结构不要字节的 headless 场景。
pub fn TuiSink::discard() -> TuiSink {
  TuiSink::new(description="discard", write=_ => ())
}

///|
/// Terminal ANSI renderer:语义帧 → 等宽 cell 栅格 → ANSI 增量。
///
/// 纯 MoonBit,不 link native 库也不碰 GPU。渲染输入只有
/// `@core.DrawFrame.semantics`,像素命令一律走降级诊断;
/// 量化、归属抢占与盒内折行都留在这个模块里,
/// `moui/core` 与 `moui/runtime` 不知道终端的存在。
pub struct TuiRenderer {
  mut metrics : @core.SurfaceMetrics
  cell : CellBox
  priv canvas : Canvas
  text_system : @core.TextSystem
  sink : TuiSink
  diagnostics : DegradeLog
  mut palette : TuiPalette
  mut frame_count : Int
  mut present_count : Int
  mut offscreen_nodes : Int
}

///|
pub fn TuiRenderer::new(
  metrics~ : @core.SurfaceMetrics,
  sink~ : TuiSink,
  cell? : CellBox = CellBox::default(),
  diagnostics? : DegradeLog = DegradeLog::new(),
  palette? : TuiPalette = TuiPalette::default(),
) -> TuiRenderer {
  let canvas = Canvas::new(cell.cols_of(metrics), cell.rows_of(metrics))
  {
    metrics,
    cell,
    canvas,
    text_system: cell_text_system(cell),
    sink,
    diagnostics,
    palette,
    frame_count: 0,
    present_count: 0,
    offscreen_nodes: 0,
  }
}

///|
/// 换调色板并强制下一帧整屏重建:attrs 遍布每一格,增量通路比较的是
/// 「上次发出的格子」,换色后所有格子都算变了。重建走 `Canvas::resize`
/// 同款的全帧标记,由下一次 `render_frame` 发一个 `ESC[2J` 帧。
pub fn TuiRenderer::set_palette(
  self : TuiRenderer,
  palette : TuiPalette,
) -> Unit {
  self.palette = palette
  self.canvas.force_rebuild()
}

///|
pub fn TuiRenderer::resize(
  self : TuiRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.metrics = metrics
  // 新栅格从空白开始画,残影由 `Canvas::resize` 清掉;这里只保证下一帧
  // 的编码走整屏重建。
  self.canvas.resize(self.cell.cols_of(metrics), self.cell.rows_of(metrics))
}

///|
pub fn TuiRenderer::cols(self : TuiRenderer) -> Int {
  self.canvas.cols
}

///|
pub fn TuiRenderer::rows(self : TuiRenderer) -> Int {
  self.canvas.rows
}

///|
/// 投影后的第 `row` 行可见文本,用于结构断言而不是字节比对。
pub fn TuiRenderer::line_text(self : TuiRenderer, row : Int) -> String {
  self.canvas.screen.line_at(row).text()
}

///|
pub fn TuiRenderer::diagnostics(self : TuiRenderer) -> DegradeLog {
  self.diagnostics
}

///|
/// 最后一帧被丢掉的离屏语义节点数。
pub fn TuiRenderer::offscreen_node_count(self : TuiRenderer) -> Int {
  self.offscreen_nodes
}

///|
pub fn TuiRenderer::frame_count(self : TuiRenderer) -> Int {
  self.frame_count
}

///|
pub fn TuiRenderer::present_count(self : TuiRenderer) -> Int {
  self.present_count
}

///|
pub fn TuiRenderer::text_system(self : TuiRenderer) -> @core.TextSystem {
  self.text_system
}

///|
/// 渲染一帧:投影语义树、登记被丢弃的像素命令、只输出脏行增量。
///
/// 零增量帧返回 `presented=false` 且不写一个字节。这不是失败,
/// 而是增量通路生效的证据:内容没变就不该重画终端。
pub fn TuiRenderer::render_frame(
  self : TuiRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  self.frame_count = self.frame_count + 1
  self.canvas.resize(
    self.cell.cols_of(self.metrics),
    self.cell.rows_of(self.metrics),
  )
  self.diagnostics.clear()
  self.canvas.begin_frame()
  self.offscreen_nodes = 0
  match frame.semantics {
    Some(payload) => {
      let offscreen = project_payload(
        self.canvas,
        payload,
        self.cell,
        self.diagnostics,
        self.palette,
      )
      self.offscreen_nodes = offscreen
      if offscreen > 0 {
        self.diagnostics.note(
          "offscreen-nodes",
          "\{offscreen} 个语义节点完全在可视区之外,已按投影规则丢掉而不是夹到边界",
        )
      }
    }
    None => {
      self.offscreen_nodes = 0
      self.diagnostics.note(
        "missing-semantics", "帧没有语义负载,TUI 渲染器无内容可投影;需要 AppRuntime::set_semantics_frames_enabled(true)",
      )
    }
  }
  note_dropped_commands(self.diagnostics, frame.commands, frame.platform_views)
  let bytes = self.canvas.present_update()
  let presented = bytes.length() > 0
  if presented {
    self.sink.emit(bytes)
    self.present_count = self.present_count + 1
  }
  @render.RenderFrameResult::new(presented~, queued=false)
}
