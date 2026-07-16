///|
fn plugin_directory_name(id : String) -> String {
  id.replace_all(old=".", new="_").replace_all(old="-", new="_")
}

///|
fn plugin_class_name(id : String) -> String {
  let parts = id.split(".")
  let builder = StringBuilder::new()
  for part in parts {
    if part.length() == 0 {
      continue
    }
    let first = part[0].to_string().to_upper()
    let rest = if part.length() > 1 { part[1:].to_owned() } else { "" }
    builder.write_string(first)
    builder.write_string(rest)
  }
  let name = builder.to_string()
  if name == "" {
    "SamplePlugin"
  } else if name.has_suffix("Plugin") {
    name
  } else {
    name + "Plugin"
  }
}

///|
fn plugin_manifest_text(
  id : String,
  platforms : Array[String],
  class_name : String,
) -> String {
  let platform_map : Map[String, Json] = Map([])
  for platform in platforms {
    if platform == "android" {
      platform_map["android"] = {
        "sources": ["android/src/" + class_name + ".kt"],
        "resources": [],
        "entry": "dev.example." + class_name,
      }
    } else if platform == "ios" {
      platform_map["ios"] = {
        "sources": ["ios/Sources/" + class_name + ".swift"],
        "resources": [],
        "entry": class_name,
      }
    } else if platform == "harmonyos" {
      platform_map["harmonyos"] = {
        "sources": ["harmonyos/src/main/ets/" + class_name + ".ets"],
        "resources": [],
        "entry": class_name,
      }
    }
  }
  let empty_strings : Array[String] = []
  let value : Json = {
    "schemaVersion": 1,
    "id": id,
    "shellApi": 1,
    "platforms": Json::object(platform_map),
    "platformViewKinds": empty_strings,
    "hostChannels": [id + ".control"],
    "permissions": empty_strings,
  }
  value.stringify(indent=2) + "\n"
}

///|
fn plugin_source_stub(platform : String, class_name : String) -> String {
  if platform == "android" {
    (
      #|package dev.example
      #|
      #|// Managed MoUI plugin stub. Replace with host-channel / PlatformView wiring.
      #|class __CLASS__ {
      #|}
      #|
    ).replace_all(old="__CLASS__", new=class_name)
  } else if platform == "ios" {
    (
      #|// Managed MoUI plugin stub. Replace with host-channel / PlatformView wiring.
      #|public final class __CLASS__ {
      #|}
      #|
    ).replace_all(old="__CLASS__", new=class_name)
  } else {
    (
      #|// Managed MoUI plugin stub. Replace with host-channel / PlatformView wiring.
      #|export class __CLASS__ {
      #|}
      #|
    ).replace_all(old="__CLASS__", new=class_name)
  }
}

///|
fn plugin_source_relative(platform : String, class_name : String) -> String {
  if platform == "android" {
    "android/src/" + class_name + ".kt"
  } else if platform == "ios" {
    "ios/Sources/" + class_name + ".swift"
  } else {
    "harmonyos/src/main/ets/" + class_name + ".ets"
  }
}

///|
fn scaffold_plugin(
  options : PluginScaffoldOptions,
) -> Result[Array[String], String] {
  if options.id.trim() == "" {
    return Err("plugin id must not be empty")
  }
  match doctor_identifier(options.id, "plugin id") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let platforms = match normalize_plugin_platforms(options.platforms) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let directory = "plugins/" + plugin_directory_name(options.id)
  let manifest_relative = directory + "/moui.plugin.json"
  let class_name = plugin_class_name(options.id)
  let files = [
    text_file(
      manifest_relative,
      plugin_manifest_text(options.id, platforms, class_name),
    ),
  ]
  for platform in platforms {
    files.push(
      text_file(
        directory + "/" + plugin_source_relative(platform, class_name),
        plugin_source_stub(platform, class_name),
      ),
    )
  }
  let written = match write_planned_files_into(options.project_root, files) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mobile_path = join_path(options.project_root, "mobile.json")
  if @fs.path_exists(mobile_path) {
    let text = @fs.read_file_to_string(mobile_path) catch {
      _ => return Err("could not read mobile.json while registering plugin")
    }
    let parsed = @json.parse(text) catch {
      _ => return Err("mobile.json is invalid JSON")
    }
    guard parsed is Object(root) else {
      return Err("mobile.json root must be an object")
    }
    guard root.get("mobile") is Some(Object(mobile)) else {
      return Err("mobile.json is missing mobile settings")
    }
    let plugins : Array[String] = []
    match mobile.get("plugins") {
      Some(Array(values)) =>
        for value in values {
          match value {
            String(path) => plugins.push(path)
            _ => return Err("mobile.json.mobile.plugins must contain strings")
          }
        }
      Some(_) => return Err("mobile.json.mobile.plugins must be an array")
      None => ()
    }
    if !plugins.contains(manifest_relative) {
      plugins.push(manifest_relative)
      mobile["plugins"] = plugins.to_json()
      root["mobile"] = Json::object(mobile)
      match
        replace_file_atomic(
          mobile_path,
          @utf8.encode(
            (Json::object(root).stringify(indent=2) + "\n")[:],
            bom=false,
          ),
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(written)
}

///|
fn normalize_plugin_platforms(
  requested : Array[String],
) -> Result[Array[String], String] {
  if requested.is_empty() {
    return Err("plugin scaffold requires at least one mobile platform")
  }
  let selected : Map[String, Bool] = Map([])
  for requested_platform in requested {
    let platform = requested_platform.to_lower()
    if platform == "all" {
      for value in ["android", "ios", "harmonyos"] {
        selected[value] = true
      }
    } else if is_mobile_platform(platform) {
      selected[platform] = true
    } else {
      return Err(
        "plugin platform must be android, ios, harmonyos, or all; got " +
        requested_platform,
      )
    }
  }
  let result : Array[String] = []
  for platform in ["android", "ios", "harmonyos"] {
    if selected.contains(platform) {
      result.push(platform)
    }
  }
  Ok(result)
}
