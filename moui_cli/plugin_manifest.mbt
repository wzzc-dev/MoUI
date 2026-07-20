// Managed shell plugin manifest reader. Migrates
// `moui_shell/scripts/plugin-manifest.mjs` (227 lines) into MoonBit. The
// reader is intentionally strict: managed plugins cannot carry native
// dependencies or build scripts. The validation logic reuses
// `shell_contracts.mbt::read_doctor_plugin` (already complete) and adds the
// global uniqueness checks (`id`, `platformViewKinds`, `hostChannels`) that
// `readMouiPluginManifests` performs in the .mjs source.

///|
/// Managed shell plugin manifest. A type alias over `DoctorPlugin` because
/// the schema and validation are identical — `read_doctor_plugin` already
/// enforces the full `moui.plugin.json` contract.
type PluginManifest = DoctorPlugin

///|
/// Read and validate a list of plugin manifests. Performs:
/// 1. Per-manifest strict validation via `read_doctor_plugin` (schema,
///    sources, resources, native-dependency prohibition, etc.).
/// 2. Global uniqueness of `id`, `platformViewKinds`, and `hostChannels`.
///
/// Unlike `read_doctor_plugins`, this function does NOT check that plugin
/// `permissions` are a subset of `shell.permissions` — that check belongs to
/// `read_shell_app` callers that have a full ShellApp in hand. Build scripts
/// that just need the manifest list (e.g. to copy plugin files) can call this
/// directly. Replaces `plugin-manifest.mjs::readMouiPluginManifests`.
fn read_moui_plugin_manifests(
  plugin_paths : Array[String],
  workspace_root : String,
) -> Result[Array[PluginManifest], String] {
  let plugins : Array[PluginManifest] = []
  let ids : Map[String, Bool] = Map([])
  let views : Map[String, String] = Map([])
  let channels : Map[String, String] = Map([])
  for path in plugin_paths {
    let plugin = match read_doctor_plugin(workspace_root, path) {
      Ok(result) => result
      Err(message) => return Err(message)
    }
    if ids.contains(plugin.id) {
      return Err("shell.json contains duplicate plugin id: " + plugin.id)
    }
    ids[plugin.id] = true
    for kind in plugin.platform_view_kinds {
      match views.get(kind) {
        Some(owner) =>
          return Err(
            "PlatformView kind " +
            kind +
            " is declared by " +
            owner +
            " and " +
            plugin.id,
          )
        None => views[kind] = plugin.id
      }
    }
    for channel in plugin.host_channels {
      match channels.get(channel) {
        Some(owner) =>
          return Err(
            "Host Service channel " +
            channel +
            " is declared by " +
            owner +
            " and " +
            plugin.id,
          )
        None => channels[channel] = plugin.id
      }
    }
    plugins.push(plugin)
  }
  Ok(plugins)
}

///|
/// Convenience helper: read manifests for a parsed `ShellApp`. Returns the
/// manifests listed in `app.plugins`, validating them against the app's
/// declared `shell.permissions`. Used by build commands (M6) that need both
/// the file list and the permission boundary.
fn read_shell_app_plugins(
  app : ShellApp,
  workspace_root : String,
) -> Result[Array[PluginManifest], String] {
  let plugins = match read_moui_plugin_manifests(app.plugins, workspace_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for plugin in plugins {
    for permission in plugin.permissions {
      if !app.shell.permissions.contains(permission) {
        return Err(
          app.metadata_path +
          ": plugin " +
          plugin.id +
          " requires undeclared permission " +
          permission,
        )
      }
    }
  }
  Ok(plugins)
}
