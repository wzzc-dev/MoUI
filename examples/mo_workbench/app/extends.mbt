// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AgentBackendKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentBackendKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentConfigValue with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentConfigValue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentPermissionOption with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentPermissionOption with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentPermissionRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentPermissionRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSessionConfigOption with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSessionConfigOption with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSessionMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSessionMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSessionModeState with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSessionModeState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppearanceMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppearanceMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ApprovalPolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend ApprovalPolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MoProviderFile with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend MoProviderFile with Debug::{to_repr}

///|
#doc(hidden)
pub extend MoProviderFile with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MoProviderFile with ToJson::{to_json}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFile with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFile with Debug::{to_repr}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFile with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFile with ToJson::{to_json}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFileLegacy with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFileLegacy with Debug::{to_repr}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFileLegacy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MoWorkbenchSettingsFileLegacy with ToJson::{to_json}

///|
#doc(hidden)
pub extend PermissionOutcome with Debug::{to_repr}

///|
#doc(hidden)
pub extend PermissionOutcome with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProviderConfig with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProviderConfig with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProviderField with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProviderField with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SandboxMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend SandboxMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SessionSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend SessionSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SettingsSection with Debug::{to_repr}

///|
#doc(hidden)
pub extend SettingsSection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TaskFilter with Debug::{to_repr}

///|
#doc(hidden)
pub extend TaskFilter with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TaskGroup with Debug::{to_repr}

///|
#doc(hidden)
pub extend TaskGroup with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TaskStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend TaskStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TaskTreeNode with Debug::{to_repr}

///|
#doc(hidden)
pub extend TaskTreeNode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThinkingChoice with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThinkingChoice with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TopTab with Debug::{to_repr}

///|
#doc(hidden)
pub extend TopTab with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TurnStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend TurnStatus with Eq::{not_equal, equal}
