///|
pub struct RendererProviderRegistry {
  priv providers : Array[@render.RendererProvider]
}

///|
pub fn RendererProviderRegistry::new() -> RendererProviderRegistry {
  { providers: [] }
}

///|
pub fn RendererProviderRegistry::from_providers(
  providers : Array[@render.RendererProvider],
) -> RendererProviderRegistry {
  { providers: providers.copy() }
}

///|
pub fn RendererProviderRegistry::register(
  self : RendererProviderRegistry,
  provider : @render.RendererProvider,
) -> Unit {
  self.providers.push(provider)
}

///|
pub fn RendererProviderRegistry::providers(
  self : RendererProviderRegistry,
) -> Array[@render.RendererProvider] {
  self.providers.copy()
}

///|
pub fn RendererProviderRegistry::lookup(
  self : RendererProviderRegistry,
  id : String,
) -> @render.RendererProvider? {
  for provider in self.providers {
    if provider.id() == id {
      return Some(provider)
    }
  }
  None
}

///|
/// Bind providers in registration order and return the first live session.
/// Rejected providers are required to leave no persistent resources behind.
pub fn resolve_renderer(
  providers : Array[@render.RendererProvider],
  surface : @render.HostSurface,
) -> @render.RendererSession? {
  for provider in providers {
    match provider.bind_surface(surface) {
      @render.RendererBindResult::Bound(session) => return Some(session)
      @render.RendererBindResult::Rejected(_) => ()
    }
  }
  None
}

///|
pub fn RendererProviderRegistry::bind(
  self : RendererProviderRegistry,
  surface : @render.HostSurface,
) -> @render.RendererSession? {
  resolve_renderer(self.providers, surface)
}
