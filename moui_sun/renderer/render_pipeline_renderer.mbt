///|
/// Replay all queued commands through this renderer, preserving checked errors.
pub fn Renderer::draw_pipeline_result(
  self : Renderer,
  pipeline : RenderPipeline,
) -> Result[RenderPipelineReplayResult, RenderPipelineReplayError] {
  pipeline.replay_result(self)
}

///|
/// Replay a pipeline through resources, preserving checked replay errors.
pub fn Renderer::draw_pipeline_with_renderer_resources_result(
  self : Renderer,
  pipeline : RenderPipeline,
  resources : RendererResources,
) -> Result[
  RenderPipelineResourceReplayResult,
  RenderPipelineResourceReplayError,
] {
  pipeline.replay_with_renderer_resources_result(self, resources)
}

///|
/// Replay a pipeline through resources and a font loader, preserving checked replay errors.
pub fn[L : @text.FontLoader] Renderer::draw_pipeline_with_font_loader_resources_result(
  self : Renderer,
  pipeline : RenderPipeline,
  resources : RendererResources,
  loader : L,
) -> Result[
  RenderPipelineResourceReplayResult,
  RenderPipelineResourceReplayError,
] {
  pipeline.replay_with_font_loader_resources_result(self, resources, loader)
}

///|
/// Analyze a pipeline against this renderer's canvas dimensions.
pub fn Renderer::analyze_pipeline(
  self : Renderer,
  pipeline : RenderPipeline,
) -> RenderPipelineAnalysis {
  let pixmap = self.get_canvas().get_pixmap()
  pipeline.analyze(pixmap.get_width(), pixmap.get_height())
}

///|
/// Build a scheduler-facing batch plan against this renderer's canvas size.
pub fn Renderer::plan_pipeline_batches(
  self : Renderer,
  pipeline : RenderPipeline,
) -> RenderPipelineBatchPlan {
  let pixmap = self.get_canvas().get_pixmap()
  pipeline.batch_plan(pixmap.get_width(), pixmap.get_height())
}

///|
/// Pre-resolve image and parsed-font text resource uses for a pipeline.
pub fn Renderer::plan_pipeline_resources(
  self : Renderer,
  pipeline : RenderPipeline,
) -> RenderPipelineResourcePlan {
  ignore(self)
  pipeline.resource_plan()
}
