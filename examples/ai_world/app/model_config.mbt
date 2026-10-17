///|
/// Model configuration: which provider to talk to, and how fast the world runs.
///
/// Configuration is persisted through `@services.SettingsServices` by the
/// platform entrypoint, never by the app package directly: the app only owns
/// the plain-data shape and the JSON encoding, which keeps it portable and
/// testable. The API key lives only in session memory — it is never logged and
/// never written into a project file.

///|
pub struct ModelConfig {
  endpoint : String
  model : String
  api_key : String
  temperature : Double
  /// Milliseconds between world ticks. Lower is faster and costs more calls.
  tick_interval_ms : Double
  /// Context budget preset: "compact" / "standard" / "roomy". Hand-decoded
  /// (see `from_json`) so an older config.json without this field still loads
  /// every other field instead of falling back wholesale to defaults.
  context_preset : String
} derive(Eq, Debug, ToJson)

///|
pub extend ModelConfig with Debug::{to_repr}

///|
pub extend ModelConfig with Eq::{not_equal, equal}

///|
pub let config_default_endpoint : String = "https://api.openai.com/v1"

///|
pub let config_default_model : String = "gpt-4o-mini"

///|
/// How many characters of prompt we are willing to send. Bounded so a
/// misbehaving provider cannot be handed an unbounded request.
pub let config_prompt_budget : Int = 6000

///|
/// Context presets: the settings page exposes tiers, never raw numbers —
/// players cannot reason about a character budget, but they can choose
/// "更长的对话记忆". Unknown stored values snap back to standard.
pub let config_context_compact : String = "compact"

///|
pub let config_context_standard : String = "standard"

///|
pub let config_context_roomy : String = "roomy"

///|
pub fn ModelConfig::context_preset(self : ModelConfig) -> String {
  self.context_preset
}

///|
/// The character budget this preset yields (consumed by `plan_messages`).
pub fn ModelConfig::context_budget(self : ModelConfig) -> Int {
  match self.context_preset {
    "compact" => 3000
    "roomy" => 12000
    _ => 6000
  }
}

///|
pub fn ModelConfig::with_context_preset(
  self : ModelConfig,
  preset : String,
) -> ModelConfig {
  let safe = match preset {
    "compact" | "standard" | "roomy" => preset
    _ => config_context_standard
  }
  { ..self, context_preset: safe, }
}

///|
/// Label of the preset for the event log.
pub fn context_preset_label(preset : String) -> String {
  match preset {
    "compact" | "standard" | "roomy" => preset
    _ => "standard"
  }
}

///|
pub fn ModelConfig::new() -> ModelConfig {
  {
    endpoint: config_default_endpoint,
    model: config_default_model,
    api_key: "",
    temperature: 0.7,
    tick_interval_ms: 900.0,
    context_preset: config_context_standard,
  }
}

///|
pub fn ModelConfig::endpoint(self : ModelConfig) -> String {
  self.endpoint
}

///|
pub fn ModelConfig::model(self : ModelConfig) -> String {
  self.model
}

///|
pub fn ModelConfig::api_key(self : ModelConfig) -> String {
  self.api_key
}

///|
pub fn ModelConfig::temperature(self : ModelConfig) -> Double {
  self.temperature
}

///|
pub fn ModelConfig::tick_interval_ms(self : ModelConfig) -> Double {
  self.tick_interval_ms
}

///|
/// Is an LLM provider usable at all? No key means the deterministic brain
/// stays in charge — the example must run without credentials.
pub fn ModelConfig::llm_enabled(self : ModelConfig) -> Bool {
  self.api_key.trim() != "" &&
  self.endpoint.trim() != "" &&
  self.model.trim() != ""
}

///|
pub fn ModelConfig::with_endpoint(
  self : ModelConfig,
  endpoint : String,
) -> ModelConfig {
  { ..self, endpoint, }
}

///|
pub fn ModelConfig::with_model(
  self : ModelConfig,
  model : String,
) -> ModelConfig {
  { ..self, model, }
}

///|
pub fn ModelConfig::with_api_key(
  self : ModelConfig,
  api_key : String,
) -> ModelConfig {
  { ..self, api_key, }
}

///|
pub fn ModelConfig::with_temperature(
  self : ModelConfig,
  temperature : Double,
) -> ModelConfig {
  { ..self, temperature, }
}

///|
pub fn ModelConfig::with_tick_interval_ms(
  self : ModelConfig,
  tick_interval_ms : Double,
) -> ModelConfig {
  { ..self, tick_interval_ms, }
}

///|
/// Encode for `SettingsServices::write`. Owned by the app so the persisted
/// shape stays stable while the model evolves.
pub fn ModelConfig::to_json(self : ModelConfig) -> String {
  @json.to_json(self).stringify()
}

///|
/// Decode from `SettingsServices::read`. Hand-written instead of derived so
/// a field missing from an older config.json falls back per-field: one new
/// setting must never wipe the player's endpoint/model/key.
pub fn ModelConfig::from_json(text : String) -> ModelConfig {
  let defaults = ModelConfig::new()
  let parsed = @json.parse(text) catch { _ => return defaults }
  let fields = match parsed {
    Object(values) => values
    _ => return defaults
  }
  fn text_at(key : String, fallback : String) -> String {
    match fields.get(key) {
      Some(String(value)) => value
      _ => fallback
    }
  }
  fn number_at(key : String, fallback : Double) -> Double {
    match fields.get(key) {
      Some(Number(value, ..)) => value
      _ => fallback
    }
  }
  let temperature = number_at("temperature", defaults.temperature)
  let tick = number_at("tick_interval_ms", defaults.tick_interval_ms)
  {
    endpoint: text_at("endpoint", defaults.endpoint),
    model: text_at("model", defaults.model),
    api_key: text_at("api_key", ""),
    // A bad number must not become NaN or a runaway sampling temperature.
    temperature: if temperature.is_nan() ||
      temperature <= 0.0 ||
      temperature > 2.0 {
      defaults.temperature
    } else {
      temperature
    },
    tick_interval_ms: if tick.is_nan() || tick <= 0.0 {
      defaults.tick_interval_ms
    } else {
      tick
    },
    context_preset: text_at("context_preset", config_context_standard),
  }
}
