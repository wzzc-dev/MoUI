///|
/// The settings page's message arms: configuration edits, persistence, and the
/// page switch.
///
/// Split out of `update.mbt` for the same reason as `library.mbt`,
/// `creation.mbt`, and `editing.mbt`: one cohesive feature, and a source-file
/// budget that must keep meaning something.
///
/// The credential lives in the **library-root** `config.json`, so it survives a
/// restart. It does **not** live in a world folder, and a world (a sibling
/// subfolder) is what export/import/share moves — which is why persisting the
/// key here is safe and why the copy on the page explains it.

///|
/// Dispatch the configuration arms.
pub fn update_settings(
  model : WorldModel,
  msg : Msg,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    EndpointChanged(value) =>
      (
        { ..model, config: model.config.with_endpoint(value), },
        @moui.Effect::none(),
      )
    ModelChanged(value) =>
      (
        { ..model, config: model.config.with_model(value), },
        @moui.Effect::none(),
      )
    ApiKeyChanged(value) =>
      (
        { ..model, config: model.config.with_api_key(value), },
        @moui.Effect::none(),
      )
    TemperatureChanged(value) =>
      (
        {
          ..model,
          config: model.config.with_temperature(
            parse_double(value, model.config.temperature()),
          ),
        },
        @moui.Effect::none(),
      )
    SaveConfig =>
      // The configuration persists as JSON at the library root, next to the
      // world folders — the player's own data folder, not a project file and not
      // part of any world.
      match host {
        Some(h) => (model, write_config_effect(h, model.config.to_json()))
        None => {
          let next = model.fork()
          next.push_log(
            "（未接入世界库）设置仅保存在本会话内存中",
          )
          (next, @moui.Effect::none())
        }
      }
    ShellTabChanged(code) =>
      (
        {
          ..model,
          shell_tab: match code {
            1 => Library
            2 => Controls
            _ => Chat
          },
        },
        @moui.Effect::none(),
      )
    _ => (model, @moui.Effect::none())
  }
}
