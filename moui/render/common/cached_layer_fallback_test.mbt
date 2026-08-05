///|
test "cached layer fallback expands updates and replays hits" {
  let rendered : Array[Array[@core.DrawCommand]] = []
  let renderer = window_renderer_with_cached_layer_fallback(
    resize=_ => (),
    render=commands => rendered.push(commands.copy()),
    text_system=() => @core.TextSystem::fallback(),
  )
  let spec = @core.CachedLayerSpec::new(
    key="layer:1",
    frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
    content_revision=1,
  )
  let text = @core.DrawCommand::DrawText(
    @core.TextRun::new(
      text="cached",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
      font=@core.FontSpec::new(size=12.0),
      color=@core.Color::black(),
    ),
  )
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::BeginCachedLayer(spec),
        text,
        @core.DrawCommand::EndCachedLayer(spec.key),
      ],
      damage=@core.DamageRegion::full("test"),
    ),
  )
  inspect(first.cache_update_count, content="1")
  let second = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[@core.DrawCommand::DrawCachedLayer(spec)],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  assert_true(
    rendered[1].any(command => {
      command is @core.DrawCommand::DrawText({ text: "cached", .. })
    }),
  )
}
