///|
/// Diff two retained pipelines against this renderer's canvas dimensions.
pub fn Renderer::diff_pipelines(
  self : Renderer,
  previous : RenderPipeline,
  next : RenderPipeline,
) -> RenderPipelineDiffResult {
  let pixmap = self.get_canvas().get_pixmap()
  RenderPipeline::diff(previous, next, pixmap.get_width(), pixmap.get_height())
}

///|
/// Diff two retained display lists and estimate the dirty region to redraw.
pub fn RenderPipeline::diff(
  previous : RenderPipeline,
  next : RenderPipeline,
  width : Int,
  height : Int,
) -> RenderPipelineDiffResult {
  let dirty_region = @graphics.DirtyRegion::new()
  let canvas_bounds = @graphics.PixelRect::new(x=0, y=0, width~, height~)
  let previous_len = previous.commands.length()
  let next_len = next.commands.length()
  let common_len = previous_len.min(next_len)
  let mut retained_count = 0
  let mut changed_count = 0
  for index in 0..<common_len {
    let old_command = previous.commands[index]
    let new_command = next.commands[index]
    if render_commands_are_same(old_command, new_command) {
      retained_count += 1
    } else {
      changed_count += 1
      render_pipeline_add_command_dirty(
        dirty_region, canvas_bounds, old_command, width, height,
      )
      render_pipeline_add_command_dirty(
        dirty_region, canvas_bounds, new_command, width, height,
      )
    }
  }
  for index in common_len..<previous_len {
    render_pipeline_add_command_dirty(
      dirty_region,
      canvas_bounds,
      previous.commands[index],
      width,
      height,
    )
  }
  for index in common_len..<next_len {
    render_pipeline_add_command_dirty(
      dirty_region,
      canvas_bounds,
      next.commands[index],
      width,
      height,
    )
  }
  {
    previous_command_count: previous_len,
    next_command_count: next_len,
    retained_command_count: retained_count,
    changed_command_count: changed_count,
    inserted_command_count: if next_len > previous_len {
      next_len - previous_len
    } else {
      0
    },
    removed_command_count: if previous_len > next_len {
      previous_len - next_len
    } else {
      0
    },
    dirty_region,
  }
}
