// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of
// trait methods as regular methods (`derive(Eq, Debug)` making
// `x.equal(y)` and `x.to_repr()` resolve). Each promotion is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the
// promotions out of the generated interface, leaving the package's
// public API unchanged.

///|
#doc(hidden)
pub extend DeclarationKey with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend SemanticId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#doc(hidden)
pub extend SemanticId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend SemanticsGeneration with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
#doc(hidden)
pub extend SemanticsGeneration with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend SemanticsNodeId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#doc(hidden)
pub extend SemanticsNodeId with Hash::{hash, hash_combine}
