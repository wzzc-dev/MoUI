# Benchmark variance on shared hosts

- **Plan**: `docs/plans/done/hot-path-invalidation-boilerplate-convergence.md`.

## Standing facts

- `benchmarks/full_cycle` p50/p95 on a laptop host swings ±40% between
  consecutive runs — observed on both a stashed-original build and a changed
  build in the same session (F-deep-click 25.9 → 12.8 ms across two runs).
  First run after a rebuild is systematically slower; treat it as a
  build-state artifact, not a measurement.
- Never accept a single-run delta as a regression or improvement signal.
  The working method: stash → warm second-run of original → unstash → warm
  second-run of changed, compare like-for-like; structural claims are
  carried by unit tests and code inspection, not by noisy wall-clock.
- `checks/performance-budgets.json` p99 reads the second-highest sample
  below 100 runs (see `memories/repo/skia-renderer-perf.md`); the same
  "one outlier is noise, a shifted tail is real" rule applies when a
  budget gate trips.
- Absolute numbers are not comparable across hosts or across weeks. Plans
  that need a baseline record it in-plan (A0 pattern) and compare
  per-plan deltas on the same host.
