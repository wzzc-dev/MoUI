///|
/// The renderer/backend composition request handed to a platform entry.
pub struct AppLaunchRequest {
  title : String
  runtime : AppRuntime
  renderer_providers : Array[@render.RendererProvider]
  window_requests : @backend_host.WindowRequests
}

///|
pub fn AppLaunchRequest::title(self : AppLaunchRequest) -> String {
  self.title
}

///|
pub fn AppLaunchRequest::runtime(self : AppLaunchRequest) -> AppRuntime {
  self.runtime
}

///|
pub fn AppLaunchRequest::renderer_providers(
  self : AppLaunchRequest,
) -> Array[@render.RendererProvider] {
  self.renderer_providers.copy()
}

///|
pub fn AppLaunchRequest::window_requests(
  self : AppLaunchRequest,
) -> @backend_host.WindowRequests {
  self.window_requests
}

///|
/// A platform launch closure. The platform package captures its concrete
/// window options and erases the window type at this boundary.
pub struct PlatformEntry {
  id : String
  launch_fn : (AppLaunchRequest) -> Unit
  launch_async_fn : (async (AppLaunchRequest, Int) -> Unit)?
}

///|
pub fn PlatformEntry::new(
  id~ : String,
  launch~ : (AppLaunchRequest) -> Unit,
  launch_async? : (async (AppLaunchRequest, Int) -> Unit)? = None,
) -> PlatformEntry {
  { id, launch_fn: launch, launch_async_fn: launch_async }
}

///|
pub fn PlatformEntry::id(self : PlatformEntry) -> String {
  self.id
}

///|
pub fn PlatformEntry::launch(
  self : PlatformEntry,
  request : AppLaunchRequest,
) -> Unit {
  (self.launch_fn)(request)
}

///|
pub async fn PlatformEntry::launch_async_pump(
  self : PlatformEntry,
  request : AppLaunchRequest,
  frame_interval_ms : Int,
) -> Unit {
  match self.launch_async_fn {
    Some(launch) => launch(request, frame_interval_ms)
    None => self.launch(request)
  }
}

///|
pub struct AppBuilder {
  title : String
  runtime : AppRuntime
  renderer_providers : Array[@render.RendererProvider]
  backend : PlatformEntry?
  window_requests : @backend_host.WindowRequests
}

///|
pub fn run_app(title : String, runtime : AppRuntime) -> AppBuilder {
  {
    title,
    runtime,
    renderer_providers: [],
    backend: None,
    window_requests: @backend_host.WindowRequests::unavailable(),
  }
}

///|
pub fn AppBuilder::render(
  self : AppBuilder,
  provider : @render.RendererProvider,
) -> AppBuilder {
  let providers = self.renderer_providers.copy()
  providers.push(provider)
  { ..self, renderer_providers: providers }
}

///|
pub fn AppBuilder::render_all(
  self : AppBuilder,
  providers : Array[@render.RendererProvider],
) -> AppBuilder {
  let next = self.renderer_providers.copy()
  for provider in providers {
    next.push(provider)
  }
  { ..self, renderer_providers: next }
}

///|
pub fn AppBuilder::backend(
  self : AppBuilder,
  backend : PlatformEntry,
) -> AppBuilder {
  { ..self, backend: Some(backend) }
}

///|
pub fn AppBuilder::window_requests(
  self : AppBuilder,
  window_requests : @backend_host.WindowRequests,
) -> AppBuilder {
  { ..self, window_requests, }
}

///|
pub fn AppBuilder::run(self : AppBuilder) -> Unit {
  if self.renderer_providers.is_empty() {
    abort("runtime.run_app: at least one renderer provider is required")
  }
  let backend = match self.backend {
    Some(backend) => backend
    None => abort("runtime.run_app: a platform backend is required")
  }
  backend.launch({
    title: self.title,
    runtime: self.runtime,
    renderer_providers: self.renderer_providers,
    window_requests: self.window_requests,
  })
}

///|
/// Run through a platform's cooperative async event pump. Platforms without
/// a dedicated pump fall back to their normal synchronous launch closure.
pub async fn AppBuilder::run_async_pump(
  self : AppBuilder,
  frame_interval_ms? : Int = 8,
) -> Unit {
  if self.renderer_providers.is_empty() {
    abort("runtime.run_app: at least one renderer provider is required")
  }
  let backend = match self.backend {
    Some(backend) => backend
    None => abort("runtime.run_app: a platform backend is required")
  }
  backend.launch_async_pump(
    {
      title: self.title,
      runtime: self.runtime,
      renderer_providers: self.renderer_providers,
      window_requests: self.window_requests,
    },
    frame_interval_ms,
  )
}
