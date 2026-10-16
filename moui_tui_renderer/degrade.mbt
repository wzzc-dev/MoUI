///|
/// 一条降级记录:哪个来源、丢的是什么、这一帧出现了几次。
pub(all) struct DegradeRecord {
  source : String
  detail : String
  count : Int
} derive(Eq, Debug)

///|
pub extend DegradeRecord with Debug::{to_repr}

///|
pub extend DegradeRecord with Eq::{not_equal, equal}

///|
/// 降级诊断日志。投影器不拒绝帧,但必须把"画不出来的东西"记下来,
/// 否则不可投影控件会静默消失,使用者只会看到空白。
///
/// 这个句柄由 composition root 创建并持有:`RendererSession` 会擦掉
/// renderer 具体类型,所以诊断必须能从会话外面拿到。
pub struct DegradeLog {
  priv records : Array[DegradeRecord]
}

///|
pub fn DegradeLog::new() -> DegradeLog {
  { records: [], }
}

///|
/// 同一来源合并计数,细节保留首次那条。
pub fn DegradeLog::note(
  self : DegradeLog,
  source : String,
  detail : String,
) -> Unit {
  let mut i = 0
  while i < self.records.length() {
    if self.records[i].source == source {
      let previous = self.records[i]
      self.records[i] = {
        source: previous.source,
        detail: previous.detail,
        count: previous.count + 1,
      }
      return
    }
    i = i + 1
  }
  self.records.push({ source, detail, count: 1, })
}

///|
pub fn DegradeLog::records(self : DegradeLog) -> Array[DegradeRecord] {
  let out : Array[DegradeRecord] = []
  for record in self.records {
    out.push(record)
  }
  out
}

///|
pub fn DegradeLog::find(self : DegradeLog, source : String) -> DegradeRecord? {
  for record in self.records {
    if record.source == source {
      return Some(record)
    }
  }
  None
}

///|
/// 被丢弃的项目总数(按来源合并后的次数累加)。
pub fn DegradeLog::total(self : DegradeLog) -> Int {
  let mut sum = 0
  for record in self.records {
    sum = sum + record.count
  }
  sum
}

///|
pub fn DegradeLog::clear(self : DegradeLog) -> Unit {
  self.records.clear()
}

///|
fn brush_is_gradient(brush : @core.Brush) -> Bool {
  match brush {
    @core.LinearGradient(_) | @core.RadialGradient(_) => true
    @core.Solid(_) => false
  }
}

///|
/// cell 投影只吃语义树,像素命令一律丢弃。丢弃必须点名,不能沉默。
pub fn note_dropped_commands(
  log : DegradeLog,
  commands : Array[@core.DrawCommand],
  platform_views : Array[@core.PlatformViewPlacement],
) -> Unit {
  for command in commands {
    match command {
      @core.DrawImage(run) =>
        log.note(
          "draw-image",
          "图像源 \{run.source} 没有 cell 表示,已丢弃",
        )
      @core.DrawPath(path) =>
        log.note(
          "draw-path",
          "矢量路径 \{path.verbs.length()} 段没有 cell 表示,已丢弃",
        )
      @core.DrawShaderEffect(spec) =>
        log.note(
          "draw-shader-effect",
          "着色器效果 \{spec.name} 没有 cell 表示,已丢弃",
        )
      @core.DrawShadow(_) =>
        log.note("draw-shadow", "阴影没有 cell 表示,已丢弃")
      @core.PushFilter(_) =>
        log.note("push-filter", "滤镜作用域没有 cell 表示,已丢弃")
      @core.FillRoundedRectBrush(_, brush)
      | @core.StrokeRoundedRectBrush(_, brush, _) =>
        if brush_is_gradient(brush) {
          log.note("gradient-brush", "渐变画刷没有 cell 表示,已丢弃")
        }
      _ => ()
    }
  }
  for view in platform_views {
    log.note(
      "platform-view",
      "平台视图 \{view.kind} (\{view.id}) 不由 cell 投影绘制,已丢弃",
    )
  }
}
