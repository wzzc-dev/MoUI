///|
/// Model configuration: which provider to talk to, and how much context to
/// send.
///
/// The app owns the plain-data shape and the JSON encoding; the platform
/// entrypoints only move the bytes (`WorldHost::read_config` /
/// `write_config`). Endpoint, model, sampling, and the context preset persist
/// to `<library>/config.json` so they travel with the player's worlds. The API
/// key does **not** persist: it lives in session memory only, is never logged,
/// and `to_json` leaves it out (see `ModelConfig::to_json`).

///|
pub struct ModelConfig {
  endpoint : String
  model : String
  /// Provider credential. Session-only: never serialized, never logged.
  api_key : String
  temperature : Double
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
pub fn ModelConfig::new() -> ModelConfig {
  {
    endpoint: config_default_endpoint,
    model: config_default_model,
    api_key: "",
    temperature: 0.7,
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
/// Encode the *shareable* configuration: endpoint, model, sampling, and the
/// context preset.
///
/// The API key is deliberately **not** written. `config.json` lives in the
/// player's library folder, which is an ordinary directory (`config.json` gets
/// committed, shared, or synced like any other file), so persisting a live
/// credential there would leak it. The key stays in session memory; the
/// settings page says so, and re-entering it after a restart is the cost.
pub fn ModelConfig::to_json(self : ModelConfig) -> String {
  let root : Map[String, Json] = {
    "endpoint": Json::string(self.endpoint),
    "model": Json::string(self.model),
    "temperature": Json::number(self.temperature),
    "context_preset": Json::string(self.context_preset),
  }
  Json::object(root).stringify()
}

///|
/// Decode from the library's `config.json`. Hand-written instead of derived so
/// a field missing from an older file falls back per-field: one new setting
/// must never wipe the player's endpoint/model.
///
/// `api_key` is accepted when an older file still contains one (so upgrading
/// players keep working for that session) but is never written back by
/// `to_json`.
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
    context_preset: text_at("context_preset", config_context_standard),
  }
}
