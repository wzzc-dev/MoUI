// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CompileDiagnostic with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend CompileDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend CompileFile with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend CompileFile with ToJson::{to_json}

///|
#doc(hidden)
pub extend CompileRequest with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend CompileRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend CompileResult with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend CompileResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend CompileStatus with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend CompileStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CompileStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlaygroundFile with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlaygroundProject with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend PlaygroundProject with ToJson::{to_json}
