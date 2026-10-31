///|
/// Manifest model for `checks/viewnode-declarations.json` (ADR 0034 Option B).
/// Each entry describes one `ViewNode`'s `declaration()` contract: per-channel
/// key material over the node's struct fields. The generated impl blocks live
/// in `<pkg>/declarations.generated.mbt` and the P17 coverage gate keeps
/// reading them like any other declaration body.

///|
struct FieldSpec {
  /// Record label for the field.
  name : String
  /// Encoder name; "" when `expr` carries the whole key expression.
  enc : String
  /// Function name for the `custom` encoder.
  custom_fn : String
  /// Path after `self.` (or after the enclosing lambda parameter for
  /// record_option sub-fields).
  path : String
  /// Whole raw key expression; "" unless set.
  expr : String
  /// Constructor arms for `enum` / `enum_option` encoders (ordinal = index).
  arms : Array[String]
  /// Record tag for the `record_option` encoder.
  record : String
  /// Sub-fields for the `record_option` encoder.
  fields : Array[FieldSpec]
} derive(Eq, Debug)

///|
struct KeySpec {
  /// Record form: tag + labelled fields.
  record : String
  fields : Array[FieldSpec]
  /// Bare single-key form.
  bare : FieldSpec?
  /// Whole raw key expression form.
  expr : String
} derive(Eq, Debug)

///|
struct ChannelSpec {
  /// exact | theme_pinned | uncacheable | constant
  kind : String
  /// When true, a pinned `style` degrades the paint channel to Uncacheable.
  style_pins_uncacheable : Bool
  key : KeySpec?
} derive(Eq, Debug)

///|
struct NodeSpec {
  node : String
  pkg : String
  /// Emit `impl[Msg] ... for Node[Msg]`.
  generic : Bool
  /// `self` or `_self` parameter name.
  self_param : String
  /// Shared `let` bindings emitted ahead of the channel expression.
  bindings : Array[FieldSpec]
  /// "" when per-channel; "constant" / "uncacheable" for whole declarations.
  whole : String
  channels : Array[(String, ChannelSpec)]
} derive(Eq, Debug)

///|
struct Manifest {
  nodes : Array[NodeSpec]
} derive(Eq, Debug)

///|
fn json_object(
  value : Json?,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Some(Json::Object(fields)) => Ok(fields)
    _ => Err(label + " must be a JSON object")
  }
}

///|
fn json_string(value : Json?, label : String) -> Result[String, String] {
  match value {
    Some(Json::String(text)) => Ok(text)
    _ => Err(label + " must be a string")
  }
}

///|
fn json_string_or(
  value : Json?,
  fallback : String,
  label : String,
) -> Result[String, String] {
  match value {
    None => Ok(fallback)
    Some(Json::String(text)) => Ok(text)
    Some(_) => Err(label + " must be a string")
  }
}

///|
fn json_bool_or(
  value : Json?,
  fallback : Bool,
  label : String,
) -> Result[Bool, String] {
  match value {
    None => Ok(fallback)
    Some(Json::True) => Ok(true)
    Some(Json::False) => Ok(false)
    Some(_) => Err(label + " must be a boolean")
  }
}

///|
fn json_strings(value : Json?, label : String) -> Result[Array[String], String] {
  match value {
    None => Ok([])
    Some(Json::Array(items)) => {
      let arms : Array[String] = []
      for item in items {
        match item {
          Json::String(text) => arms.push(text)
          _ => return Err(label + " must contain only strings")
        }
      }
      Ok(arms)
    }
    _ => Err(label + " must be an array")
  }
}

///|
fn parse_field(value : Json, label : String) -> Result[FieldSpec, String] {
  let fields = match json_object(Some(value), label) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let name = match json_string_or(fields.get("name"), "", label + ".name") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let enc = match json_string_or(fields.get("enc"), "", label + ".enc") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let custom_fn = match json_string_or(fields.get("fn"), "", label + ".fn") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let path = match json_string_or(fields.get("path"), "", label + ".path") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let expr = match json_string_or(fields.get("expr"), "", label + ".expr") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let arms = match json_strings(fields.get("arms"), label + ".arms") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let record = match
    json_string_or(fields.get("record"), "", label + ".record") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let sub_fields : Array[FieldSpec] = []
  match fields.get("fields") {
    None => ()
    Some(Json::Array(items)) => {
      let mut index = 0
      for item in items {
        match parse_field(item, label + ".fields[\{index}]") {
          Ok(sub) => sub_fields.push(sub)
          Err(message) => return Err(message)
        }
        index += 1
      }
    }
    Some(_) => return Err(label + ".fields must be an array")
  }
  Ok({ name, enc, custom_fn, path, expr, arms, record, fields: sub_fields, })
}

///|
fn parse_key(
  fields : Map[String, Json],
  label : String,
) -> Result[KeySpec, String] {
  let record = match
    json_string_or(fields.get("record"), "", label + ".record") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let key_fields : Array[FieldSpec] = []
  match fields.get("fields") {
    None => ()
    Some(Json::Array(items)) => {
      let mut index = 0
      for item in items {
        match parse_field(item, label + ".fields[\{index}]") {
          Ok(sub) => key_fields.push(sub)
          Err(message) => return Err(message)
        }
        index += 1
      }
    }
    Some(_) => return Err(label + ".fields must be an array")
  }
  let bare : FieldSpec? = match fields.get("bare") {
    None => None
    Some(value) =>
      match parse_field(value, label + ".bare") {
        Ok(sub) => Some(sub)
        Err(message) => return Err(message)
      }
  }
  let expr = match json_string_or(fields.get("expr"), "", label + ".expr") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ record, fields: key_fields, bare, expr, })
}

///|
let channel_order : Array[String] = ["layout", "paint", "semantics"]

///|
let channel_kinds : Array[String] = [
  "exact", "theme_pinned", "uncacheable", "constant",
]

///|
fn parse_channel(value : Json, label : String) -> Result[ChannelSpec, String] {
  match value {
    Json::String(kind) =>
      if kind == "constant" || kind == "uncacheable" {
        Ok({ kind, style_pins_uncacheable: false, key: None, })
      } else {
        Err(label + ": string channels must be \"constant\" or \"uncacheable\"")
      }
    _ => {
      let fields = match json_object(Some(value), label) {
        Ok(fields) => fields
        Err(message) => return Err(message)
      }
      let kind = match json_string(fields.get("kind"), label + ".kind") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if !channel_kinds.contains(kind) {
        return Err(
          label +
          ": unknown kind `" +
          kind +
          "` (expected one of exact, theme_pinned, uncacheable, constant)",
        )
      }
      let style_pins = match
        json_bool_or(
          fields.get("style_pins_uncacheable"),
          false,
          label + ".style_pins_uncacheable",
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let key : KeySpec? = match fields.get("record") {
        Some(_) =>
          match parse_key(fields, label + ".key") {
            Ok(value) => Some(value)
            Err(message) => return Err(message)
          }
        None =>
          match fields.get("bare") {
            Some(_) =>
              match parse_key(fields, label + ".key") {
                Ok(value) => Some(value)
                Err(message) => return Err(message)
              }
            None =>
              match fields.get("expr") {
                Some(_) =>
                  match parse_key(fields, label + ".key") {
                    Ok(value) => Some(value)
                    Err(message) => return Err(message)
                  }
                None => None
              }
          }
      }
      if kind == "exact" || kind == "theme_pinned" {
        if key is None {
          return Err(label + ": kind `" + kind + "` requires a key")
        }
      }
      Ok({ kind, style_pins_uncacheable: style_pins, key, })
    }
  }
}

///|
fn parse_node(value : Json, label : String) -> Result[NodeSpec, String] {
  let fields = match json_object(Some(value), label) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let node = match json_string(fields.get("node"), label + ".node") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pkg = match json_string(fields.get("package"), label + ".pkg") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let generic = match
    json_bool_or(fields.get("generic"), false, label + ".generic") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let self_param = match
    json_string_or(fields.get("self"), "self", label + ".self") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let bindings : Array[FieldSpec] = []
  match fields.get("bindings") {
    None => ()
    Some(Json::Array(items)) => {
      let mut index = 0
      for item in items {
        match parse_field(item, label + ".bindings[\{index}]") {
          Ok(binding) => bindings.push(binding)
          Err(message) => return Err(message)
        }
        index += 1
      }
    }
    Some(_) => return Err(label + ".bindings must be an array")
  }
  let whole = match fields.get("declaration") {
    Some(Json::String(kind)) => kind
    Some(Json::Object(_)) => ""
    None => ""
    Some(_) => return Err(label + ".declaration must be a string or object")
  }
  let channels : Array[(String, ChannelSpec)] = []
  match fields.get("declaration") {
    Some(Json::Object(declaration_fields)) =>
      for name in channel_order {
        match declaration_fields.get(name) {
          Some(value) =>
            match parse_channel(value, label + ".declaration." + name) {
              Ok(channel) => channels.push((name, channel))
              Err(message) => return Err(message)
            }
          None => ()
        }
      }
    _ => ()
  }
  Ok({ node, pkg, generic, self_param, bindings, whole, channels, })
}

///|
fn parse_manifest(text : String) -> Result[Manifest, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("viewnode declaration manifest is not valid JSON")
  }
  let root = match json_object(Some(parsed), "manifest") {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) =>
      if value != 1.0 {
        return Err("manifest schemaVersion must be 1")
      }
    _ => return Err("manifest requires schemaVersion: 1")
  }
  let items = match root.get("nodes") {
    Some(Json::Array(items)) => items
    _ => return Err("manifest requires a nodes array")
  }
  let nodes : Array[NodeSpec] = []
  let mut index = 0
  for item in items {
    let node = match parse_node(item, "manifest.nodes[\{index}]") {
      Ok(node) => node
      Err(message) => return Err(message)
    }
    for existing in nodes {
      if existing.node == node.node {
        return Err("duplicate node in manifest: " + node.node)
      }
    }
    nodes.push(node)
    index += 1
  }
  Ok({ nodes, })
}

///|
/// Static manifest validation: encoder names, required payloads, and path
/// safety. Runs before any file is written.
fn validate_node(node : NodeSpec) -> Result[Unit, String] {
  let label = "node " + node.node
  if node.node == "" || node.pkg == "" {
    return Err(label + ": node and pkg are required")
  }
  if node.pkg.contains("..") || node.pkg.has_prefix("/") {
    return Err(label + ": pkg must be a repository-relative path")
  }
  if node.whole != "" && node.whole != "constant" && node.whole != "uncacheable" {
    return Err(label + ": declaration shortcut must be constant/uncacheable")
  }
  if node.whole == "" && node.channels.is_empty() {
    return Err(label + ": declaration requires channels or a shortcut")
  }
  for binding in node.bindings {
    if binding.name == "" || binding.expr == "" {
      return Err(label + ": bindings need name and expr")
    }
  }
  for entry in node.channels {
    let (_, channel) = entry
    match channel.kind {
      "uncacheable" | "constant" => ()
      _ =>
        match channel.key {
          None =>
            return Err(label + ": channel " + channel.kind + " needs a key")
          Some(key) =>
            match validate_key(key, label) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
        }
    }
    if channel.style_pins_uncacheable && entry.0 != "paint" {
      return Err(
        label + ": style_pins_uncacheable is only valid on the paint channel",
      )
    }
  }
  Ok(())
}

///|
fn validate_field(field : FieldSpec, label : String) -> Result[Unit, String] {
  if field.expr != "" {
    return Ok(())
  }
  match field.enc {
    "custom" =>
      if field.custom_fn == "" || field.path == "" {
        return Err(
          label +
          ": custom encoder requires fn and path (field " +
          field.name +
          ")",
        )
      }
    "enum" | "enum_option" =>
      if field.arms.is_empty() || field.path == "" {
        return Err(
          label +
          ": " +
          field.enc +
          " requires arms and path (field " +
          field.name +
          ")",
        )
      }
    "record_option" => {
      if field.path == "" || field.record == "" {
        return Err(
          label +
          ": record_option requires path and record (field " +
          field.name +
          ")",
        )
      }
      if field.fields.is_empty() {
        return Err(
          label +
          ": record_option requires sub-fields (field " +
          field.name +
          ")",
        )
      }
      for sub in field.fields {
        match validate_field(sub, label) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
    "string"
    | "int"
    | "double"
    | "bool"
    | "bool_int"
    | "size"
    | "size_option"
    | "double_option"
    | "insets"
    | "color"
    | "color_option"
    | "string_option"
    | "bool_option"
    | "point"
    | "point_option"
    | "font"
    | "font_option"
    | "brush_option"
    | "border_option"
    | "shadow_option"
    | "semantics_role"
    | "semantics_role_option"
    | "icon_label_option" =>
      if field.path == "" {
        return Err(
          label +
          ": encoder " +
          field.enc +
          " requires path (field " +
          field.name +
          ")",
        )
      }
    other =>
      return Err(
        label + ": unknown encoder `" + other + "` (field " + field.name + ")",
      )
  }
  Ok(())
}

///|
fn validate_key(key : KeySpec, label : String) -> Result[Unit, String] {
  if key.expr != "" {
    return Ok(())
  }
  match key.bare {
    Some(bare) => validate_field(bare, label)
    None => {
      if key.record == "" {
        return Err(label + ": record key requires a record tag")
      }
      if key.fields.is_empty() {
        return Err(label + ": record key requires fields")
      }
      for field in key.fields {
        match validate_field(field, label) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      Ok(())
    }
  }
}
