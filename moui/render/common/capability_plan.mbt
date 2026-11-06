///|
/// One provider that rejected a host surface, with the provider-supplied reason.
/// The plan records only providers attempted before the first successful bind;
/// selection still stops at the first `Bound` session.
pub(all) struct RendererRejection {
  provider_id : String
  reason : String
}

///|
/// Declarative startup view of a provider list: declared capabilities,
/// follow-up features, surface eligibility, and every rejection encountered
/// before the selected session. It is a plan, not a central renderer switch.
pub(all) struct RendererCapabilityPlan {
  provider_ids : Array[String]
  selected_provider_id : String?
  rejections : Array[RendererRejection]
  features : Array[@render.RendererFeatureCapability]
  follow_ups : Array[@render.RendererFeatureCapability]
  surface_error : String?
}

///|
pub(all) struct RendererBindingResolution {
  session : @render.RendererSession?
  plan : RendererCapabilityPlan
}

///|
/// Startup policy for a provider list. `required_features` must be present in
/// the plan with a status at least as strong as the policy allows; `allow_partial`
/// keeps a `Partial` feature acceptable, while `fail_on_missing` turns a `Gap`
/// or `Unavailable` feature into a startup failure.
pub(all) struct RendererCapabilityPolicy {
  required_features : Array[@render.RendererFeature]
  allow_partial : Bool
  fail_on_missing : Bool
}

///|
pub fn RendererCapabilityPolicy::new(
  required_features~ : Array[@render.RendererFeature] = [],
  allow_partial~ : Bool = true,
  fail_on_missing~ : Bool = true,
) -> RendererCapabilityPolicy {
  { required_features, allow_partial, fail_on_missing, }
}

///|
fn renderer_feature_status_acceptable(
  status : @render.RendererFeatureStatus,
  policy : RendererCapabilityPolicy,
) -> Bool {
  match status {
    @render.RendererFeatureStatus::Supported => true
    @render.RendererFeatureStatus::HostForwarded => true
    @render.RendererFeatureStatus::Partial => policy.allow_partial
    _ => false
  }
}

///|
/// A surface-free plan for `AppBuilder` preflight. The selected provider is
/// unknown before a host surface exists, so a required feature is acceptable
/// when any registered provider declares it at the policy's level.
pub fn RendererCapabilityPlan::from_providers(
  providers : Array[@render.RendererProvider],
) -> RendererCapabilityPlan {
  {
    provider_ids: providers.map(provider => provider.id()),
    selected_provider_id: None,
    rejections: [],
    features: renderer_feature_capability_report(providers),
    follow_ups: renderer_feature_follow_ups(providers),
    surface_error: None,
  }
}

///|
pub fn RendererCapabilityPlan::policy_problems(
  self : RendererCapabilityPlan,
  policy : RendererCapabilityPolicy,
) -> Array[String] {
  let problems : Array[String] = []
  for feature in policy.required_features {
    let mut acceptable = false
    for entry in self.features {
      if entry.feature == feature {
        match self.selected_provider_id {
          Some(provider_id) => {
            let status = entry.status_for_provider(provider_id)
            if renderer_feature_status_acceptable(status, policy) {
              acceptable = true
            }
          }
          None =>
            for provider in entry.providers {
              if renderer_feature_status_acceptable(provider.status, policy) {
                acceptable = true
              }
            }
        }
      }
    }
    if !acceptable {
      problems.push(
        "renderer feature " +
        feature.label() +
        " is unavailable at the required level",
      )
    }
  }
  problems
}

///|
pub fn RendererCapabilityPlan::rejection_summary(
  self : RendererCapabilityPlan,
) -> String {
  let parts : Array[String] = []
  for rejection in self.rejections {
    parts.push("\{rejection.provider_id}: \{rejection.reason}")
  }
  parts.join("; ")
}

///|
/// Bind providers in registration order, stop at the first live session, and
/// return the ordered rejection reasons plus the declared capability plan.
/// Rejected providers remain side-effect-free; providers after the first
/// success are never called.
pub fn resolve_renderer_with_plan(
  providers : Array[@render.RendererProvider],
  surface : @render.HostSurface,
) -> RendererBindingResolution {
  let rejections : Array[RendererRejection] = []
  let mut session : @render.RendererSession? = None
  let mut selected_provider_id : String? = None
  for provider in providers {
    match provider.bind_surface(surface) {
      Bound(bound) => {
        session = Some(bound)
        selected_provider_id = Some(provider.id())
        break
      }
      Rejected(reason) =>
        rejections.push({ provider_id: provider.id(), reason, })
    }
  }
  {
    session,
    plan: {
      provider_ids: providers.map(provider => provider.id()),
      selected_provider_id,
      rejections,
      features: renderer_feature_capability_report(providers),
      follow_ups: renderer_feature_follow_ups(providers),
      surface_error: host_surface_metrics_error(surface),
    },
  }
}

///|
test "capability plan records rejections before the first bound provider" {
  let first_binds = Ref(0)
  let second_binds = Ref(0)
  let third_binds = Ref(0)
  let rejecting = @render.RendererProvider::new(
    id="first",
    descriptor=@render.RendererDescriptor::new(
      backend=SkiaRasterNative,
      family=Skia,
      presentation=CpuPixelFrame,
      supported_targets=[Native],
      capabilities=[],
      description="rejecting test provider",
    ),
    capabilities=() => [],
    bind=_surface => {
      first_binds.val = first_binds.val + 1
      Rejected("no GPU surface")
    },
  )
  let accepting = @render.RendererProvider::new(
    id="second",
    descriptor=@render.RendererDescriptor::new(
      backend=SkiaRasterNative,
      family=Skia,
      presentation=CpuPixelFrame,
      supported_targets=[Native],
      capabilities=[],
      description="accepting test provider",
    ),
    capabilities=() => [],
    bind=_surface => {
      second_binds.val = second_binds.val + 1
      Bound(
        @render.RendererSession::new(
          resize=_metrics => (),
          render_frame=_frame => @render.RenderFrameResult::new(presented=true),
          text_system=() => @core.TextSystem::fallback(),
          dispose=() => (),
        ),
      )
    },
  )
  let never_called = @render.RendererProvider::new(
    id="third",
    descriptor=@render.RendererDescriptor::new(
      backend=SkiaRasterNative,
      family=Skia,
      presentation=CpuPixelFrame,
      supported_targets=[Native],
      capabilities=[],
      description="unused test provider",
    ),
    capabilities=() => [],
    bind=_surface => {
      third_binds.val = third_binds.val + 1
      Rejected("should not run")
    },
  )
  let surface = @render.HostSurface::new(
    surface_id="test-surface",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=50.0),
      scale_factor=2.0,
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description="test", present=_frame => true),
    ),
  )
  let resolution = resolve_renderer_with_plan(
    [rejecting, accepting, never_called],
    surface,
  )
  assert_true(resolution.session is Some(_))
  match resolution.plan.selected_provider_id {
    Some(id) => inspect(id, content="second")
    None => fail("expected second provider to be selected")
  }
  inspect(resolution.plan.rejections.length(), content="1")
  inspect(resolution.plan.rejections[0].provider_id, content="first")
  inspect(resolution.plan.rejections[0].reason, content="no GPU surface")
  inspect(first_binds.val, content="1")
  inspect(second_binds.val, content="1")
  inspect(third_binds.val, content="0")
}

///|
test "capability plan reports every rejection when no provider binds" {
  let provider = @render.RendererProvider::new(
    id="rejecting",
    descriptor=@render.RendererDescriptor::new(
      backend=SkiaRasterNative,
      family=Skia,
      presentation=CpuPixelFrame,
      supported_targets=[Native],
      capabilities=[],
      description="rejecting test provider",
    ),
    capabilities=() => [],
    bind=_surface => Rejected("unavailable"),
  )
  let surface = @render.HostSurface::new(
    surface_id="test-surface",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=50.0),
      scale_factor=2.0,
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description="test", present=_frame => true),
    ),
  )
  let resolution = resolve_renderer_with_plan([provider], surface)
  assert_true(resolution.session is None)
  inspect(resolution.plan.selected_provider_id is None, content="true")
  inspect(resolution.plan.rejections.length(), content="1")
  inspect(resolution.plan.rejection_summary(), content="rejecting: unavailable")
}

///|
test "capability policy turns a required gap into a startup problem" {
  let plan = RendererCapabilityPlan::{
    provider_ids: ["p"],
    selected_provider_id: Some("p"),
    rejections: [],
    features: [
      @render.RendererFeatureCapability::new(feature=Text, providers=[
        @render.RendererBackendFeatureCapability::new(
          provider_id="p",
          feature=Text,
          backend=SkiaRasterNative,
          status=Gap,
        ),
      ]),
    ],
    follow_ups: [],
    surface_error: None,
  }
  let problems = plan.policy_problems(
    RendererCapabilityPolicy::new(required_features=[Text]),
  )
  inspect(problems.length(), content="1")
  assert_true(problems[0].contains("required"))
}
