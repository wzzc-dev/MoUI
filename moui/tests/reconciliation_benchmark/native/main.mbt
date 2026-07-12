// MoUI reconciliation micro-benchmark.
//
// Measures the find_reusable_child hot path used by reconcile_children_for_runtime
// in moui/runtime/element_reconcile.mbt. The benchmark replicates the two lookup
// strategies (legacy linear scan vs new indexed lookup) over synthetic (key, kind)
// pairs so it can run as a standalone native executable without touching private
// runtime types. The threshold (32) and composite-key shape mirror the shipping
// implementation.

///|
extern "c" fn bench_now_ms() -> Double = "moui_reconciliation_benchmark_now_ms"

///|
struct BenchItem {
  key : String?
  kind : Int
}

///|
struct BenchRunResult {
  label : String
  child_count : Int
  iterations : Int
  elapsed_ms : Double
  comparisons : Int64
}

///|
fn bench_env_int(name : String, fallback : Int) -> Int {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed.length() == 0 {
        return fallback
      }
      let mut parsed = 0
      for ch in trimmed.to_array() {
        if ch < '0' || ch > '9' {
          return fallback
        }
        parsed = parsed * 10 + ch.to_int() - '0'.to_int()
      }
      parsed.max(1)
    }
    None => fallback
  }
}

///|
fn bench_build_items(count : Int, keyed : Bool) -> Array[BenchItem] {
  let items : Array[BenchItem] = []
  for index in 0..<count {
    let key = if keyed {
      Some("item-\{index}")
    } else {
      None
    }
    items.push({ key, kind: 1 })
  }
  items
}

///|
fn bench_shuffle_order(count : Int, seed : Int) -> Array[Int] {
  // Deterministic pseudo-random shuffle so runs are reproducible.
  // We don't need cryptographic quality; a simple LCG over indices is enough
  // to defeat the "same position" fast path of find_reusable_child.
  let order : Array[Int] = []
  for index in 0..<count {
    order.push(index)
  }
  let mut state = seed.to_int64()
  for swap_index in 0..<(count - 1) {
    state = state * 6364136223846793005L + 1442695040888963407L
    let range = (count - swap_index).to_int64()
    let pick = ((state.reinterpret_as_uint64() >> 33) % range.reinterpret_as_uint64()).to_int()
    let target = swap_index + pick
    let tmp = order[swap_index]
    order[swap_index] = order[target]
    order[target] = tmp
  }
  order
}

///|
fn bench_build_next(
  old_items : Array[BenchItem],
  order : Array[Int],
) -> Array[BenchItem] {
  let next : Array[BenchItem] = []
  for next_index in 0..<old_items.length() {
    let old_index = order[next_index]
    next.push(old_items[old_index])
  }
  next
}

///|
fn bench_find_linear(
  old_items : Array[BenchItem],
  used : Array[Bool],
  next_item : BenchItem,
  index : Int,
) -> (Int?, Int) {
  let mut comparisons = 0
  match next_item.key {
    Some(key) => {
      for old_index, old_item in old_items {
        comparisons += 1
        if !used[old_index] &&
          old_item.key == Some(key) &&
          old_item.kind == next_item.kind {
          return (Some(old_index), comparisons)
        }
      }
      (None, comparisons)
    }
    None => {
      comparisons += 1
      if index < old_items.length() &&
        !used[index] &&
        old_items[index].key is None &&
        old_items[index].kind == next_item.kind {
        (Some(index), comparisons)
      } else {
        (None, comparisons)
      }
    }
  }
}

///|
fn bench_build_index(
  old_items : Array[BenchItem],
) -> Map[String, Array[Int]] {
  let index : Map[String, Array[Int]] = {}
  for old_index, old_item in old_items {
    match old_item.key {
      Some(key) => {
        let composite = "\{key}|\{old_item.kind}"
        match index.get(composite) {
          Some(arr) => arr.push(old_index)
          None => index[composite] = [old_index]
        }
      }
      None => ()
    }
  }
  index
}

///|
fn bench_find_indexed(
  old_items : Array[BenchItem],
  used : Array[Bool],
  key_index : Map[String, Array[Int]],
  next_item : BenchItem,
  index : Int,
) -> (Int?, Int) {
  let mut comparisons = 0
  match next_item.key {
    Some(key) => {
      let composite = "\{key}|\{next_item.kind}"
      comparisons += 1
      match key_index.get(composite) {
        Some(candidates) => {
          for old_index in candidates {
            comparisons += 1
            if !used[old_index] {
              return (Some(old_index), comparisons)
            }
          }
          (None, comparisons)
        }
        None => (None, comparisons)
      }
    }
    None => {
      comparisons += 1
      if index < old_items.length() &&
        !used[index] &&
        old_items[index].key is None &&
        old_items[index].kind == next_item.kind {
        (Some(index), comparisons)
      } else {
        (None, comparisons)
      }
    }
  }
}

///|
fn bench_run_linear(
  old_items : Array[BenchItem],
  next_items : Array[BenchItem],
  iterations : Int,
) -> BenchRunResult {
  let mut total_comparisons : Int64 = 0L
  let start = bench_now_ms()
  for _ in 0..<iterations {
    let used : Array[Bool] = []
    for _ in old_items {
      used.push(false)
    }
    for index, next_item in next_items {
      let (found, comparisons) = bench_find_linear(old_items, used, next_item, index)
      total_comparisons += comparisons.to_int64()
      match found {
        Some(old_index) => used[old_index] = true
        None => ()
      }
    }
  }
  let elapsed = bench_now_ms() - start
  {
    label: "linear-scan",
    child_count: old_items.length(),
    iterations,
    elapsed_ms: elapsed,
    comparisons: total_comparisons,
  }
}

///|
fn bench_run_indexed(
  old_items : Array[BenchItem],
  next_items : Array[BenchItem],
  iterations : Int,
) -> BenchRunResult {
  let mut total_comparisons : Int64 = 0L
  let start = bench_now_ms()
  for _ in 0..<iterations {
    let used : Array[Bool] = []
    for _ in old_items {
      used.push(false)
    }
    // Index is rebuilt every iteration to mirror real reconcile behavior
    // where build_keyed_child_index runs once per reconcile_children call.
    let key_index = bench_build_index(old_items)
    for index, next_item in next_items {
      let (found, comparisons) = bench_find_indexed(
        old_items, used, key_index, next_item, index,
      )
      total_comparisons += comparisons.to_int64()
      match found {
        Some(old_index) => used[old_index] = true
        None => ()
      }
    }
  }
  let elapsed = bench_now_ms() - start
  {
    label: "indexed-lookup",
    child_count: old_items.length(),
    iterations,
    elapsed_ms: elapsed,
    comparisons: total_comparisons,
  }
}

///|
fn bench_avg_ms(result : BenchRunResult) -> Double {
  if result.iterations == 0 {
    0.0
  } else {
    result.elapsed_ms / result.iterations.to_double()
  }
}

///|
fn bench_speedup(linear : BenchRunResult, indexed : BenchRunResult) -> Double {
  let indexed_avg = bench_avg_ms(indexed)
  if indexed_avg <= 0.0 {
    0.0
  } else {
    bench_avg_ms(linear) / indexed_avg
  }
}

///|
fn bench_comparison_reduction(
  linear : BenchRunResult,
  indexed : BenchRunResult,
) -> Double {
  if linear.comparisons == 0L {
    0.0
  } else {
    1.0 - indexed.comparisons.to_double() / linear.comparisons.to_double()
  }
}

///|
fn bench_print_result(result : BenchRunResult) -> Unit {
  println(
    "  \{result.label}: children=\{result.child_count} iterations=\{result.iterations} elapsed_ms=\{result.elapsed_ms} avg_ms=\{bench_avg_ms(result)} comparisons=\{result.comparisons}",
  )
}

///|
fn bench_run_scenario(
  label : String,
  child_count : Int,
  iterations : Int,
  shuffle_seed : Int,
) -> Unit {
  let old_items = bench_build_items(child_count, true)
  let order = bench_shuffle_order(child_count, shuffle_seed)
  let next_items = bench_build_next(old_items, order)
  println("\{label}: children=\{child_count} iterations=\{iterations}")
  // Warmup to stabilize caches and JIT.
  ignore(bench_run_linear(old_items, next_items, 1))
  ignore(bench_run_indexed(old_items, next_items, 1))
  let linear = bench_run_linear(old_items, next_items, iterations)
  let indexed = bench_run_indexed(old_items, next_items, iterations)
  bench_print_result(linear)
  bench_print_result(indexed)
  println(
    "  speedup=\{bench_speedup(linear, indexed)}x comparison_reduction=\{bench_comparison_reduction(linear, indexed) * 100.0}%",
  )
  println(
    "{\"benchmark\":\"\{label}\",\"children\":\{child_count},\"iterations\":\{iterations},\"linear\":{\"elapsed_ms\":\{linear.elapsed_ms},\"comparisons\":\{linear.comparisons}},\"indexed\":{\"elapsed_ms\":\{indexed.elapsed_ms},\"comparisons\":\{indexed.comparisons}},\"speedup\":\{bench_speedup(linear, indexed)},\"comparison_reduction\":\{bench_comparison_reduction(linear, indexed)}}",
  )
}

///|
fn main {
  let iterations = bench_env_int("MOUI_RECONCILE_BENCH_ITERATIONS", 200)
  let small = bench_env_int("MOUI_RECONCILE_BENCH_SMALL", 32)
  let medium = bench_env_int("MOUI_RECONCILE_BENCH_MEDIUM", 128)
  let large = bench_env_int("MOUI_RECONCILE_BENCH_LARGE", 512)
  let xlarge = bench_env_int("MOUI_RECONCILE_BENCH_XLARGE", 1024)
  println(
    "MoUI reconciliation benchmark: linear-scan (O(n^2)) vs indexed-lookup (O(n))",
  )
  println(
    "Each iteration: build index (if indexed), then find reusable child for each next item with shuffled order.",
  )
  println("")
  // small (threshold): linear scan still used in production at this size.
  bench_run_scenario("small-at-threshold", small, iterations, 42)
  println("")
  // medium: above threshold, indexed lookup wins clearly.
  bench_run_scenario("medium", medium, iterations, 42)
  println("")
  // large: indexed lookup should dominate.
  bench_run_scenario("large", large, iterations, 42)
  println("")
  // xlarge: stress test the quadratic gap.
  bench_run_scenario("xlarge", xlarge, iterations, 42)
}
