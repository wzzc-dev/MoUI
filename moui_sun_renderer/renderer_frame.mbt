///|
pub fn SunRasterRenderer::render_frame(
  self : SunRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  self.render_frame_inner(frame) catch {
    err => {
      self.record_unsupported_command("RenderFrame", err.message())
      @render.RenderFrameResult::new(
        presented=false,
        diagnostics=sun_unsupported_command_events(self),
      )
    }
  }
}

///|
fn SunRasterRenderer::render_frame_inner(
  self : SunRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult raise SunRendererError {
  let profile = sun_profile_enabled()
  let profile_start = @bench.monotonic_clock_start()
  sun_profile_begin_frame()
  self.prepare_canvas_for_frame()
  self.canvas.clear(sun_color(frame.clear_color))
  self.canvas.scale(sx=self.metrics.scale_factor, sy=self.metrics.scale_factor)
  let setup_us = if profile {
    @bench.monotonic_clock_end(profile_start)
  } else {
    0.0
  }
  let replay_start = @bench.monotonic_clock_start()
  self.unsupported_command_count = 0
  self.unsupported_command_diagnostics.clear()
  let canvas_scopes : Array[@render_common.PlanScopeKind] = []
  let opacity_stack : Array[Double] = []
  let blend_mode_stack : Array[@sun_graphics.BlendMode] = []
  let layer_spec_stack : Array[SunLayerScope] = []
  let rounded_clip_transform_stack : Array[@sun_graphics.Transform] = []
  let stats = SunCachedLayerFrameStats::new()
  // The command stream is interpreted directly; scope balance is validated in
  // this traversal (canvas scope stack + unclosed-scope report below).
  let complete = self.render_cached_command_range(
    frame.commands,
    0,
    frame.commands.length(),
    canvas_scopes,
    opacity_stack,
    blend_mode_stack,
    layer_spec_stack,
    rounded_clip_transform_stack,
    stats,
  )
  if !canvas_scopes.is_empty() {
    for scope in canvas_scopes {
      self.record_unsupported_command(
        @render_common.plan_scope_push_command(scope),
        "command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
      )
    }
    while !self.canvas_stack.is_empty() {
      match self.canvas_stack.pop() {
        Some(parent_canvas) => self.canvas = parent_canvas
        None => ()
      }
    }
    self.filter_stack.clear()
    self.blur_radius_stack.clear()
    self.rounded_clip_stack.clear()
    rounded_clip_transform_stack.clear()
    while !blend_mode_stack.is_empty() {
      ignore(blend_mode_stack.pop())
    }
    while !layer_spec_stack.is_empty() {
      ignore(layer_spec_stack.pop())
    }
  }
  if !complete {
    return stats.to_render_frame_result(
      presented=false,
      diagnostics=sun_unsupported_command_events(self),
    )
  }
  let replay_us = @bench.monotonic_clock_end(replay_start)
  let platform_view_start = @bench.monotonic_clock_start()
  match self.platform_view_draw_fn {
    Some(draw_fn) => draw_fn()
    None => ()
  }
  sun_profile_add(30, @bench.monotonic_clock_end(platform_view_start))
  let read_start = @bench.monotonic_clock_start()
  let sun_frame = self.read_frame()
  let read_us = @bench.monotonic_clock_end(read_start)
  self.last_frame = Some(sun_frame)
  let present_start = @bench.monotonic_clock_start()
  if (self.target.present)(sun_frame) {
    let present_us = @bench.monotonic_clock_end(present_start)
    self.present_count = self.present_count + 1
    sun_profile_report_frame(
      frame.commands.length(),
      setup_us,
      replay_us,
      read_us,
      present_us,
    )
    stats.to_render_frame_result(
      presented=true,
      diagnostics=sun_unsupported_command_events(self),
    )
  } else {
    raise PresentFailed(self.target.description)
  }
}

///|
fn sun_unsupported_command_events(
  renderer : SunRasterRenderer,
) -> Array[@diagnostics.DiagnosticEvent] {
  renderer.unsupported_command_diagnostics.map(diagnostic => {
    @diagnostics.DiagnosticEvent::new(
      code="renderer.unsupported_command",
      severity=@diagnostics.DiagnosticSeverity::Warning,
      domain=@diagnostics.DiagnosticDomain::Render,
      message=diagnostic.reason(),
      source=diagnostic.command(),
    )
  })
}
