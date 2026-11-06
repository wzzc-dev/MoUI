///|
/// Runtime values re-exported for the backend-common owners. `AppRuntime` and
/// the semantics DTO family are produced by runtime internals and stay there;
/// `apphost` is the only package the common owners import, so the direct
/// `backend/common -> runtime` edge disappears without moving the engine.
pub using @runtime {
  type AccessibilityAnnouncement,
  type AppRuntime,
  type PerformSemanticsActionRequest,
  type SemanticsActionDispatchError,
  type SemanticsActionReceipt,
  type SemanticsGenerationPrecondition,
  type SemanticsIssue,
  type SemanticsRead,
  type SemanticsReadError,
}
