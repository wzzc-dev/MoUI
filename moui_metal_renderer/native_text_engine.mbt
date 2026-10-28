///|
// The renderer-neutral native text model lives in
// `wzzc-dev/moui/render/native_text` (plan stage L0.2). The value this package's
// own API names is re-exported here so a host entrypoint reaches the engine
// through the renderer it composes with, exactly as the WGPU route does; text
// providers import the neutral package directly instead of this one.
pub using @native_text {
  type NativeTextEngine,
  native_noop_text_engine,
  native_platform_text_engine,
  native_platform_text_engine_with_fallback,
}
