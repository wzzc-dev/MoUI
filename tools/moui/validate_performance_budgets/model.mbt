///|
struct PercentileBudget {
  p50 : Double
  p95 : Double
  p99 : Double
  max_regression_percent : Double
}

///|
struct ResourceBudget {
  baseline : Double
  max_regression_percent : Double
  higher_is_better : Bool
}

///|
struct ScenarioBudget {
  minimum_samples : Int
  timings : Map[String, PercentileBudget]
  resources : Map[String, ResourceBudget]
}

///|
let required_scenarios : Array[String] = [
  "showcase-runtime-scroll", "markdown-editor-text-input", "excel-grid-navigation",
  "virtual-list-100k", "multi-window-4",
]

///|
let required_performance_runner = "native-skia-raster"

///|
let required_timing_metrics : Array[String] = [
  "buildMs", "layoutMs", "paintMs", "presentMs", "frameMs",
]

///|
let required_resource_metrics : Array[String] = [
  "peakRssBytes", "allocationCount", "cacheHitRate", "startupMs", "packageBytes",
]

///|
fn performance_json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn performance_json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Some(text)
    _ => None
  }
}

///|
fn performance_json_number(value : Json?) -> Double? {
  match value {
    Some(Json::Number(number, repr=_)) => Some(number)
    _ => None
  }
}

///|
fn performance_json_bool(value : Json?) -> Bool? {
  match value {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn performance_json_number_array(value : Json?) -> Array[Double]? {
  guard value is Some(Json::Array(values)) else { return None }
  let numbers : Array[Double] = []
  for value in values {
    match value {
      Json::Number(number, repr=_) => numbers.push(number)
      _ => return None
    }
  }
  Some(numbers)
}

///|
fn[T] performance_has_exact_keys(
  values : Map[String, T],
  required : Array[String],
) -> Bool {
  if values.length() != required.length() {
    return false
  }
  required.all(key => values.contains(key))
}

///|
fn performance_nearest_rank(
  samples : Array[Double],
  percentile : Int,
) -> Double {
  if samples.is_empty() {
    return 0.0
  }
  let sorted = samples.copy()
  sorted.sort()
  let rank = ((sorted.length() * percentile + 99) / 100).max(1)
  sorted[rank - 1]
}

///|
fn performance_limit(baseline : Double, regression_percent : Double) -> Double {
  baseline * (1.0 + regression_percent / 100.0)
}

///|
fn performance_floor(baseline : Double, regression_percent : Double) -> Double {
  baseline * (1.0 - regression_percent / 100.0)
}
