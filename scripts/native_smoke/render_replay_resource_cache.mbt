///|
priv struct ReplayResourceCacheSmokeStats {
  frame_cacheable_plan : @skia.RendererResourcePlan
  frame_uncacheable_plan : @skia.RendererResourcePlan
  cache_inserts : Int
  missing_before : @skia.RendererResourcePlan
  cached_after : @skia.RendererResourcePlan
  lru_stats : @skia.ResourceCacheStats
  lru_byte_size : Int64
}

///|
fn run_replay_resource_cache_smoke(
  replay_frame : @skia.RenderFrameDescriptor,
) -> ReplayResourceCacheSmokeStats {
  let replay_resource_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new(max_bytes=replay_frame.resource_plan.byte_size)
  let replay_cached_before = replay_frame.cached_cacheable_resource_plan(
    replay_resource_cache,
  )
  let replay_missing_before = replay_frame.missing_cacheable_resource_plan(
    replay_resource_cache,
  )
  let replay_cache_inserts = replay_frame.cache_resources(replay_resource_cache)
  let replay_cached_after = replay_frame.cached_cacheable_resource_plan(
    replay_resource_cache,
  )
  let replay_missing_after = replay_frame.missing_cacheable_resource_plan(
    replay_resource_cache,
  )
  let replay_frame_cacheable_plan = replay_frame.cacheable_resource_plan()
  let replay_frame_uncacheable_plan = replay_frame.uncacheable_resource_plan()
  if !replay_cached_before.is_empty() ||
    replay_missing_before.length() != replay_frame.resource_plan.cacheable_count ||
    replay_cache_inserts != replay_frame.resource_plan.cacheable_count ||
    replay_resource_cache.byte_size() != replay_frame.resource_plan.byte_size ||
    replay_cached_after.length() != replay_frame.resource_plan.cacheable_count ||
    !replay_missing_after.is_empty() ||
    replay_frame_cacheable_plan.length() != replay_frame.resource_plan.length() ||
    !replay_frame_uncacheable_plan.is_empty() ||
    !replay_resource_cache.contains_resource_plan(replay_frame.resource_plan) {
    fail_smoke(
      "native render frame resources did not populate the resource cache",
    )
  }

  let lru_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new(max_bytes=8L)
  let lru_image = @skia.RendererResourceDescriptor::image(
    b"native-smoke-cache-image",
    byte_size=4L,
  )
  let lru_shader = @skia.RendererResourceDescriptor::shader(
    b"native-smoke-cache-shader",
    byte_size=4L,
  )
  let lru_path = @skia.RendererResourceDescriptor::path(
    b"native-smoke-cache-path",
    byte_size=4L,
  )
  ignore(lru_cache.insert_resource_descriptor(lru_image))
  ignore(lru_cache.insert_resource_descriptor(lru_shader))
  if lru_cache.get(lru_image.key) != Some(lru_image) {
    fail_smoke("native resource cache did not report a refreshed LRU hit")
  }
  ignore(lru_cache.insert_resource_descriptor(lru_path))
  let lru_stats = lru_cache.stats()
  if lru_stats.evictions != 1 ||
    lru_stats.hits != 1 ||
    lru_stats.misses != 0 ||
    lru_cache.byte_size() != 8L ||
    !lru_cache.contains(lru_image.key) ||
    lru_cache.contains(lru_shader.key) ||
    !lru_cache.contains(lru_path.key) {
    fail_smoke(
      "native resource cache LRU budget behavior did not match expectations",
    )
  }
  {
    frame_cacheable_plan: replay_frame_cacheable_plan,
    frame_uncacheable_plan: replay_frame_uncacheable_plan,
    cache_inserts: replay_cache_inserts,
    missing_before: replay_missing_before,
    cached_after: replay_cached_after,
    lru_stats,
    lru_byte_size: lru_cache.byte_size(),
  }
}
