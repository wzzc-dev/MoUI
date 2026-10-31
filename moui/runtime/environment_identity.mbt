///|
/// Interned environment identities (plan
/// hot-path-invalidation-boilerplate-convergence C1). The measure/place/
/// semantics/platform caches used to compare the full `Environment` — which
/// embeds the complete `Theme` — structurally at every element on every pass.
/// Passes now resolve the environment's identity once and thread it through
/// the tree; only environment-scoping modifiers (whose child environment is a
/// new value) resolve through this intern table, and identity is content:
/// structurally equal environments always share an id.
let environment_identities : Array[(@core.Environment, Int32)] = []

///|
let environment_identity_limit : Int32 = 32

///|
let next_environment_identity : Ref[Int32] = Ref(1)

///|
/// Identity for a concrete environment value. Ids are monotonically
/// increasing and never reused, so clearing the lookup table can never alias
/// a stale cached id to a different environment; a miss just re-interns.
fn environment_identity(environment : @core.Environment) -> Int32 {
  for entry in environment_identities {
    if entry.0 == environment {
      return entry.1
    }
  }
  let id = next_environment_identity.val
  next_environment_identity.val = id + 1
  environment_identities.push((environment, id))
  if environment_identities.length() > environment_identity_limit {
    environment_identities.clear()
  }
  id
}
