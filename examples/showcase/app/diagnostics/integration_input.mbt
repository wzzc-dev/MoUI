///|
pub(all) struct ShowcaseHostDiagnostics {
  label : String
  backend_label : String
  service_count : Int
  service_capacity : Int
  service_labels : Array[String]
  input_count : Int
  input_capacity : Int
  input_labels : Array[String]
  multi_window : Bool
  window_lifecycle : Bool
}

///|
pub(all) enum ShowcaseCapabilityPriority {
  GapOrPartial
  FollowUp
  Complete
} derive(Eq, Debug)

///|
pub(all) struct ShowcaseRendererProviderDiagnostic {
  provider_id : String
  status_label : String
  needs_follow_up : Bool
}

///|
pub(all) struct ShowcaseRendererFeatureDiagnostic {
  feature_label : String
  providers : Array[ShowcaseRendererProviderDiagnostic]
  priority : ShowcaseCapabilityPriority
}

///|
pub(all) struct ShowcaseInspectorDiagnostics {
  scheduled_effect_label : String
  duplicate_effect_keys : Array[String]
  subscription_source_count : Int
  active_subscription_label : String
  duplicate_subscription_keys : Array[String]
}

///|
pub struct ShowcaseDiagnosticsInput {
  host : ShowcaseHostDiagnostics
  renderer_features : Array[ShowcaseRendererFeatureDiagnostic]
  inspector : ShowcaseInspectorDiagnostics
}

///|
pub fn ShowcaseDiagnosticsInput::new(
  host~ : ShowcaseHostDiagnostics,
  renderer_features~ : Array[ShowcaseRendererFeatureDiagnostic],
  inspector~ : ShowcaseInspectorDiagnostics,
) -> ShowcaseDiagnosticsInput {
  { host, renderer_features, inspector }
}

///|
pub fn ShowcaseDiagnosticsInput::fallback() -> ShowcaseDiagnosticsInput {
  {
    host: {
      label: "Showcase test host",
      backend_label: "Test",
      service_count: 0,
      service_capacity: 5,
      service_labels: [],
      input_count: 0,
      input_capacity: 7,
      input_labels: [],
      multi_window: false,
      window_lifecycle: false,
    },
    renderer_features: [],
    inspector: {
      scheduled_effect_label: "Inspector boot",
      duplicate_effect_keys: [],
      subscription_source_count: 2,
      active_subscription_label: "Inspector tick",
      duplicate_subscription_keys: ["diagnostics:tick"],
    },
  }
}
