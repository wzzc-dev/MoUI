///|
/// H2 boilerplate convergence (`hot-path-invalidation-boilerplate-convergence`):
/// MoonBit derive-generated trait impls are only "implicit promoted" to regular
/// methods, which is deprecated — the sanctioned re-export is the explicit
/// `pub extend T with Trait::{...}` line. Hand-writing three to five of those
/// lines after every `#derive(...)` attribute in `moui/core` is pure boilerplate,
/// so this tool derives them mechanically from the source of truth (the
/// `#derive` attributes and hand-written `pub impl` blocks) into one committed
/// generated file.
///
/// Scope: `moui/core/paint.mbt`, `moui/core/semantics.mbt`,
/// `moui/core/theme.mbt` (the three files named by the plan). Extends for
/// other core files stay hand-written.

///|
#derive(Eq, Debug)
struct TypeDerives {
  name : String
  file : String
  /// Traits requested by the type's `#derive(...)` attribute.
  derived : Array[String]
  /// Traits promoted from hand-written `pub impl <Trait> for <Type>` blocks.
  impld : Array[String]
}

///|
#derive(Eq, Debug)
struct ParsedSource {
  types : Array[TypeDerives]
}

///|
/// Canonical emission order and method-set for every supported trait.
fn extend_method_set(trait_name : String) -> String? {
  match trait_name {
    "Debug" => Some("Debug::{to_repr}")
    "Eq" => Some("Eq::{not_equal, equal}")
    "ToJson" => Some("ToJson::{to_json}")
    "Compare" => Some("Compare::{op_lt, op_le, op_ge, compare, op_gt}")
    "Hash" => Some("Hash::{hash, hash_combine}")
    _ => None
  }
}

///|
fn canonical_trait_order() -> Array[String] {
  ["Debug", "Eq", "ToJson", "Compare", "Hash"]
}

///|
let derive_source_files : Array[String] = [
  "moui/core/paint.mbt", "moui/core/gradient.mbt", "moui/core/semantics.mbt", "moui/core/theme.mbt",
]

///|
fn type_decl_name(line : String) -> String? {
  let t = line
  let mut rest = ""
  if t.has_prefix("pub(all) ") {
    rest = t["pub(all) ".length():].to_owned()
  } else if t.has_prefix("pub ") {
    rest = t["pub ".length():].to_owned()
  } else if t.has_prefix("priv ") {
    rest = t["priv ".length():].to_owned()
  } else {
    rest = t
  }
  if !(rest.has_prefix("struct ") || rest.has_prefix("enum ")) {
    return None
  }
  let kind_len = if rest.has_prefix("struct ") { 7 } else { 5 }
  ident_at(rest, kind_len)
}

///|
fn ident_char(ch : Char) -> Bool {
  ch == '_' ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9')
}

///|
fn ident_at(line : String, from : Int32) -> String? {
  let mut i = from
  let buf = StringBuilder()
  let mut found = false
  while i < line.length() {
    let ch = match line[i].to_char() {
      Some(ch) => ch
      None => break
    }
    if ident_char(ch) {
      buf.write_char(ch)
      found = true
    } else {
      break
    }
    i += 1
  }
  if found {
    Some(buf.to_string())
  } else {
    None
  }
}

///|
/// Traits inside a `#derive(A, B, C)` attribute found anywhere in the line.
fn derive_traits(line : String) -> Result[Array[String], String] {
  let open = match line.find("derive(") {
    Some(index) => index + "derive(".length()
    None => return Ok([])
  }
  let tail = line[open:].to_owned()
  let close = match tail.find(")") {
    Some(relative) => open + relative
    None => return Err("unterminated derive( clause: " + line)
  }
  let inner = line[open:close].to_owned()
  let traits : Array[String] = []
  for part in inner.split(",") {
    let name = part.trim().to_owned()
    if name != "" {
      traits.push(name)
    }
  }
  Ok(traits)
}

///|
/// `(trait, type)` of a hand-written `pub impl <Trait> for <Type> ...` line.
fn pub_impl_target(line : String) -> (String, String)? {
  let t = line
  if !t.has_prefix("pub impl ") {
    return None
  }
  let rest = t["pub impl ".length():].to_owned()
  let for_at = match rest.find(" for ") {
    Some(index) => index
    None => return None
  }
  let trait_name = rest[:for_at].to_owned()
  match ident_at(rest, for_at + 5) {
    Some(type_name) => Some((trait_name, type_name))
    None => None
  }
}

///|
/// A boilerplate-shaped `pub extend` line that must live in the generated
/// file instead of the hand-written sources.
fn boilerplate_extend_line(line : String) -> Bool {
  let t = line
  if !t.has_prefix("pub extend ") {
    return false
  }
  t.contains("Debug::{to_repr}") ||
  t.contains("Eq::{not_equal, equal}") ||
  t.contains("ToJson::{to_json}") ||
  t.contains("Compare::{op_lt") ||
  t.contains("Hash::{hash")
}

///|
fn find_type(types : Array[TypeDerives], name : String) -> TypeDerives? {
  for entry in types {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
fn parse_source(file : String, text : String) -> Result[ParsedSource, String] {
  let types : Array[TypeDerives] = []
  let pending_derived : Array[String] = []
  let lines = text.split("\n").map(fn(v) { v.to_owned() }).collect()
  for line in lines {
    if boilerplate_extend_line(line) {
      return Err(
        file +
        ": boilerplate `pub extend` must move to moui/core/derives.generated.mbt (regenerate with scripts/generate-core-derives.mjs): " +
        line.trim().to_owned(),
      )
    }
    match pub_impl_target(line) {
      Some((trait_name, type_name)) =>
        match find_type(types, type_name) {
          Some(entry) => entry.impld.push(trait_name)
          None =>
            types.push({
              name: type_name,
              file,
              derived: [],
              impld: [trait_name],
            })
        }
      None => ()
    }
    let trimmed = line.trim()
    if trimmed.has_prefix("#derive(") {
      let traits = match derive_traits(line) {
        Ok(value) => value
        Err(message) => return Err(file + ": " + message)
      }
      pending_derived.clear()
      pending_derived.append(traits)
    }
    if trimmed.contains("} derive(") {
      return Err(
        file +
        ": deprecated suffix derive syntax; use a #derive(...) attribute before the type declaration",
      )
    }
    match type_decl_name(line) {
      Some(name) => {
        if pending_derived.is_empty() {
          continue
        }
        let traits = pending_derived.copy()
        pending_derived.clear()
        for trait_name in traits {
          if extend_method_set(trait_name) is None {
            return Err(
              file +
              ": unmapped derive trait `" +
              trait_name +
              "` on type " +
              name,
            )
          }
        }
        match find_type(types, name) {
          Some(entry) => entry.derived.append(traits)
          None => types.push({ name, file, derived: traits, impld: [], })
        }
      }
      None => ()
    }
  }
  Ok({ types, })
}
