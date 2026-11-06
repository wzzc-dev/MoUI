///|
/// Emission of MoonBit `impl ... ViewNode for X with fn declaration` blocks
/// from manifest specs. Output is formatted by `moonfmt` in the runner shim,
/// so the emitter only guarantees syntactically valid, deterministic code.

///|
/// Emit context. `common` is the receiver for `moui/views/common` helpers:
/// `@common.` from every other pkg, and the bare (unqualified) form for
/// nodes generated *inside* `moui/views/common` itself, which cannot import
/// its own pkg.
#derive(Eq, Debug)
struct EmitContext {
  pkg : String
  common : String
}

///|
fn emit_context(pkg : String) -> EmitContext {
  let prefix = if pkg == "moui/views/common" { "" } else { "@common." }
  { pkg, common: prefix, }
}

///|
let simple_encoders : Array[(String, String)] = [
  ("string", "@core.DeclarationKey::string"),
  ("int", "@core.DeclarationKey::int"),
  ("double", "@core.DeclarationKey::double"),
  ("bool", "@core.DeclarationKey::bool"),
  ("size", "view_size_key"),
  ("size_option", "view_size_option_key"),
  ("double_option", "view_double_option_key"),
  ("insets", "view_insets_key"),
  ("color", "view_color_key"),
  ("point", "view_point_key"),
  ("font", "view_font_key"),
  ("font_option", "view_font_option_key"),
  ("brush_option", "view_brush_option_key"),
  ("border_option", "view_border_option_key"),
  ("shadow_option", "view_shadow_option_key"),
  ("semantics_role", "view_semantics_role_key"),
]

///|
fn simple_encoder_call(enc : String) -> String? {
  for entry in simple_encoders {
    if entry.0 == enc {
      return Some(entry.1)
    }
  }
  None
}

///|
fn last_path_segment(path : String) -> String {
  let mut last = -1
  let mut index = 0
  while index < path.length() {
    if path[index] == '.' {
      last = index
    }
    index += 1
  }
  if last >= 0 {
    path[last + 1:].to_owned()
  } else {
    path
  }
}

///|
fn join_path(receiver : String, path : String) -> String {
  receiver + "." + path
}

///|
/// Emit the key expression for one field. `receiver` is `self` for top-level
/// fields and the lambda parameter inside `record_option` sub-fields.
fn emit_field(
  ctx : EmitContext,
  field : FieldSpec,
  receiver : String,
  indent : String,
  out : StringBuilder,
) -> Unit {
  if field.expr != "" {
    out.write_string(field.expr)
    return
  }
  if field.enc == "custom" {
    out.write_string(
      field.custom_fn + "(" + join_path(receiver, field.path) + ")",
    )
    return
  }
  if field.enc == "enum" {
    out.write_string(
      "@core.DeclarationKey::int(match " +
      join_path(receiver, field.path) +
      " {\n" +
      enum_arms(field.arms, indent + "  ") +
      "\n" +
      indent +
      "})",
    )
    return
  }
  if field.enc == "enum_option" {
    let param = last_path_segment(field.path)
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(" +
      param +
      " => {\n" +
      indent +
      "  @core.DeclarationKey::int(match " +
      param +
      " {\n" +
      enum_arms(field.arms, indent + "    ") +
      "\n" +
      indent +
      "  })\n" +
      indent +
      " }))",
    )
    return
  }
  if field.enc == "record_option" {
    let param = last_path_segment(field.path)
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(" +
      param +
      " => { " +
      ctx.common +
      "view_record_key(\"" +
      field.record +
      "\", [",
    )
    let mut first = true
    for sub in field.fields {
      if !first {
        out.write_string(",")
      }
      first = false
      out.write_string("\n" + indent + "  (\"" + sub.name + "\", ")
      emit_field(ctx, sub, param, indent + "  ", out)
      out.write_string(")")
    }
    out.write_string("\n" + indent + "  ]) })")
    out.write_string(")")
    return
  }
  if field.enc == "color_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(" +
      ctx.common +
      "view_color_key))",
    )
    return
  }
  if field.enc == "string_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(@core.DeclarationKey::string))",
    )
    return
  }
  if field.enc == "bool_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(@core.DeclarationKey::bool))",
    )
    return
  }
  if field.enc == "point_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(" +
      ctx.common +
      "view_point_key))",
    )
    return
  }
  if field.enc == "semantics_role_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(" +
      ctx.common +
      "view_semantics_role_key))",
    )
    return
  }
  if field.enc == "icon_label_option" {
    out.write_string(
      "@core.DeclarationKey::option(" +
      join_path(receiver, field.path) +
      ".map(name => { @core.DeclarationKey::string(@icon.icon_label(name)) }))",
    )
    return
  }
  if field.enc == "bool_int" {
    out.write_string(
      "@core.DeclarationKey::int(if " +
      join_path(receiver, field.path) +
      " { 1 } else { 0 })",
    )
    return
  }
  // Simple positional encoders validated by validate_field.
  match simple_encoder_call(field.enc) {
    Some(call) =>
      out.write_string(
        qualify_common(ctx, call) + "(" + join_path(receiver, field.path) + ")",
      )
    None => out.write_string("/* unknown encoder " + field.enc + " */")
  }
}

///|
/// Simple encoder names are stored unqualified; qualify them with the
/// pkg-aware common receiver.
fn qualify_common(ctx : EmitContext, call : String) -> String {
  if call.has_prefix("@core.") || call.has_prefix("@icon.") {
    return call
  }
  ctx.common + call
}

///|
fn enum_arms(arms : Array[String], indent : String) -> String {
  let parts : Array[String] = []
  let mut ordinal = 0
  for arm in arms {
    parts.push(indent + arm + " => " + ordinal.to_string())
    ordinal += 1
  }
  parts.join("\n")
}

///|
fn emit_key(
  ctx : EmitContext,
  key : KeySpec,
  indent : String,
  out : StringBuilder,
) -> Unit {
  if key.expr != "" {
    out.write_string(key.expr)
    return
  }
  match key.bare {
    Some(bare) => emit_field(ctx, bare, "self", indent, out)
    None => {
      out.write_string(ctx.common + "view_record_key(\"" + key.record + "\", [")
      let mut first = true
      for field in key.fields {
        if !first {
          out.write_string(",")
        }
        first = false
        out.write_string("\n" + indent + "  (\"" + field.name + "\", ")
        emit_field(ctx, field, "self", indent + "  ", out)
        out.write_string(")")
      }
      out.write_string("\n" + indent + "])")
    }
  }
}

///|
fn emit_channel(
  ctx : EmitContext,
  name : String,
  channel : ChannelSpec,
  indent : String,
  out : StringBuilder,
) -> Unit {
  out.write_string(name + "=")
  if channel.kind == "uncacheable" {
    out.write_string("Uncacheable")
    return
  }
  if channel.kind == "constant" {
    out.write_string("Constant")
    return
  }
  if channel.style_pins_uncacheable {
    out.write_string("if self.style is Some(_) {\n")
    out.write_string(indent + "  Uncacheable\n")
    out.write_string(indent + "} else {\n")
    out.write_string(indent + "  " + ctx.common + "views_theme_channel(")
    match channel.key {
      Some(key) => emit_key(ctx, key, indent + "    ", out)
      None => ()
    }
    out.write_string(", self.theme)\n")
    out.write_string(indent + "}")
    return
  }
  match channel.kind {
    "exact" => {
      out.write_string(ctx.common + "view_exact_channel(")
      match channel.key {
        Some(key) => emit_key(ctx, key, indent + "  ", out)
        None => ()
      }
      out.write_string(")")
    }
    "theme_pinned" => {
      out.write_string(ctx.common + "views_theme_channel(")
      match channel.key {
        Some(key) => emit_key(ctx, key, indent + "  ", out)
        None => ()
      }
      out.write_string(", self.theme)")
    }
    _ => out.write_string("Constant")
  }
}

///|
fn emit_node(ctx : EmitContext, node : NodeSpec, out : StringBuilder) -> Unit {
  out.write_string("///|\n")
  out.write_string("impl")
  if node.generic {
    out.write_string("[Msg]")
  }
  out.write_string(" @core.ViewNode for " + node.node)
  if node.generic {
    out.write_string("[Msg]")
  }
  out.write_string(" with fn declaration(" + node.self_param + ") {\n")
  for binding in node.bindings {
    out.write_string("  let " + binding.name + " = ")
    emit_field(ctx, binding, "self", "  ", out)
    out.write_string("\n")
  }
  if node.whole == "constant" {
    out.write_string("  @core.ViewDeclaration::constant()\n")
  } else if node.whole == "uncacheable" {
    out.write_string("  @core.ViewDeclaration::uncacheable()\n")
  } else {
    let active : Array[(String, ChannelSpec)] = []
    for entry in node.channels {
      let (_, channel) = entry
      if channel.kind != "constant" {
        active.push(entry)
      }
    }
    if active.length() == 1 &&
      active[0].1.kind == "exact" &&
      !active[0].1.style_pins_uncacheable {
      let (name, _) = active[0]
      let call = match name {
        "layout" => "view_layout_declaration"
        "paint" => "view_paint_declaration"
        _ => "view_semantics_declaration"
      }
      out.write_string("  " + ctx.common + call + "(")
      match active[0].1.key {
        Some(key) => emit_key(ctx, key, "  ", out)
        None => ()
      }
      out.write_string(")\n")
    } else {
      out.write_string("  " + ctx.common + "view_declaration(\n")
      for entry in node.channels {
        let (name, channel) = entry
        if channel.kind == "constant" {
          continue
        }
        out.write_string("    ")
        emit_channel(ctx, name, channel, "    ", out)
        out.write_string(",\n")
      }
      out.write_string("  )\n")
    }
  }
  out.write_string("}\n")
}

///|
fn emit_package_file(pkg : String, nodes : Array[NodeSpec]) -> String {
  let ctx = emit_context(pkg)
  let out = StringBuilder()
  out.write_string(
    "// Generated by tools/moui/generate_view_declarations. DO NOT EDIT.\n" +
    "//\n" +
    "// Source of truth: checks/viewnode-declarations.json (ADR 0034 Option B,\n" +
    "// plan hot-path-invalidation H1). Regenerate with:\n" +
    "//   node scripts/generate-view-declarations.mjs\n",
  )
  for node in nodes {
    out.write_string("\n")
    emit_node(ctx, node, out)
  }
  out.to_string()
}
