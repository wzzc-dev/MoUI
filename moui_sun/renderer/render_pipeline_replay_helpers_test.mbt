///|
fn must_draw_pipeline(
  renderer : @renderer.Renderer,
  pipeline : @renderer.RenderPipeline,
) -> @renderer.RenderPipelineReplayResult {
  match renderer.draw_pipeline_result(pipeline) {
    Ok(result) => result
    Err(_) => abort("expected checked pipeline replay")
  }
}

///|
fn must_draw_pipeline_with_renderer_resources(
  renderer : @renderer.Renderer,
  pipeline : @renderer.RenderPipeline,
  resources : @renderer.RendererResources,
) -> @renderer.RenderPipelineResourceReplayResult {
  match
    renderer.draw_pipeline_with_renderer_resources_result(pipeline, resources) {
    Ok(result) => result
    Err(_) => abort("expected checked renderer-resource pipeline draw")
  }
}
