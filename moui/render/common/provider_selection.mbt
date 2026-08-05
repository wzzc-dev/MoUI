///|
/// Select the first binding that accepts a surface in registration order.
pub fn select_renderer_provider_binding(
  bindings : Array[@render.RendererProviderBinding],
  surface : @render.SurfaceDescriptor,
) -> (@render.RendererProviderBinding, @render.BoundSurface)? {
  for binding in bindings {
    match (binding.provider().negotiate)(surface) {
      @render.SurfaceNegotiationResult::SurfaceAccepted(bound) =>
        return Some((binding, bound))
      @render.SurfaceNegotiationResult::SurfaceRejected(_) => ()
    }
  }
  None
}

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
pub fn RendererProviderRegistry::select(
  self : RendererProviderRegistry,
  surface : @render.SurfaceDescriptor,
) -> (@render.RendererProvider, @render.BoundSurface)? {
  for provider in self.providers {
    match (provider.negotiate)(surface) {
      @render.SurfaceNegotiationResult::SurfaceAccepted(bound) =>
        return Some((provider, bound))
      @render.SurfaceNegotiationResult::SurfaceRejected(_) => ()
    }
  }
  None
}

///|
/// Bind and negotiate delayed factories in registration order.
pub fn resolve_renderer(
  factories : Array[@render.RendererFactory],
  context : @render.SurfaceContext,
) -> @render.RendererResolution? {
  for factory in factories {
    let plan = factory.bind(context)
    let binding = plan.binding()
    let surface = match plan.surface() {
      Some(surface) => surface
      None => context.surface()
    }
    match (binding.provider().negotiate)(surface) {
      @render.SurfaceNegotiationResult::SurfaceAccepted(bound) =>
        return Some(
          @render.RendererResolution::new(
            renderer=(binding.create_host_renderer)(context.metrics(), bound),
            image_loader=plan.image_loader(),
          ),
        )
      @render.SurfaceNegotiationResult::SurfaceRejected(_) => ()
    }
  }
  None
}
