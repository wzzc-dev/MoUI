///|
/// Owner-scoped cancellation and generation. A scope is created by the task
/// owner (program runtime, service bridge, image owner, or GPU worker); a
/// completion is accepted only while its token still matches.
pub struct TaskScope {
  priv mut generation : UInt64
  priv mut cancelled : Bool
}

///|
pub fn TaskScope::new() -> TaskScope {
  { generation: 1UL, cancelled: false, }
}

///|
pub fn TaskScope::generation(self : TaskScope) -> UInt64 {
  self.generation
}

///|
pub fn TaskScope::cancel(self : TaskScope) -> Unit {
  if !self.cancelled {
    self.cancelled = true
    self.generation = self.generation + 1UL
  }
}

///|
pub fn TaskScope::is_cancelled(self : TaskScope) -> Bool {
  self.cancelled
}

///|
pub fn TaskScope::token(self : TaskScope) -> CancelToken {
  { scope_generation: self.generation, }
}

///|
/// A completion token captured when a task starts. `is_current` checks both
/// the cancelled flag and the generation, so a scope that was cancelled and
/// reused cannot accept an old completion.
pub struct CancelToken {
  priv scope_generation : UInt64
}

///|
pub fn CancelToken::scope_generation(self : CancelToken) -> UInt64 {
  self.scope_generation
}

///|
pub fn CancelToken::is_current(self : CancelToken, scope : TaskScope) -> Bool {
  !scope.is_cancelled() && self.scope_generation == scope.generation()
}

///|
test "cancel token becomes stale after the scope is cancelled" {
  let scope = TaskScope::new()
  let token = scope.token()
  assert_true(token.is_current(scope))
  scope.cancel()
  assert_true(scope.is_cancelled())
  assert_false(token.is_current(scope))
  assert_true(scope.token().scope_generation() > token.scope_generation())
}

///|
test "cancelling twice keeps one generation bump" {
  let scope = TaskScope::new()
  let generation = scope.generation()
  scope.cancel()
  scope.cancel()
  inspect(scope.generation(), content="\{generation + 1UL}")
}
