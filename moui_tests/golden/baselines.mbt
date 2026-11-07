///|
/// Checked-in golden baselines: the FNV-1a 64 hash of each scene's RGBA
/// bytes (width * 4 bytes per row, row padding skipped).
///
/// A mismatch means the rendered pixels moved. If the move is intentional
/// (a renderer or draw-command change), read the actual hash from the
/// failing test's diff, paste it over the constant here, and record the
/// reason in the commit message. If it is not intentional, the diff is the
/// regression.
///
/// Update procedure:
///
/// 1. `moon test moui_tests/golden --target native` — the failing test
///    prints the actual hash per scene.
/// 2. Verify the new rendering visually (render the same scene through a
///    Showcase entrypoint or a scratch harness before trusting it).
/// 3. Paste the hashes, run the suite again, commit with the reason.

///|
/// Scene `solid_and_rounded_rects`: clear + fill rect + fill/stroke rounded
/// rects.
pub let golden_baseline_solid_and_rounded_rects : UInt64 = 3990293542802571389UL

///|
/// Scene `linear_gradient`: diagonal linear gradient inside a rounded rect.
pub let golden_baseline_linear_gradient : UInt64 = 8759695772735398335UL

///|
/// Scene `clip_transform_opacity`: clipped, sheared, 60%-opacity rect.
pub let golden_baseline_clip_transform_opacity : UInt64 = 10787988435370361550UL

///|
/// Scene `path_fill`: filled triangle path.
pub let golden_baseline_path_fill : UInt64 = 1924209875266629837UL

///|
pub fn golden_baselines() -> Array[(String, UInt64)] {
  [
    ("solid_and_rounded_rects", golden_baseline_solid_and_rounded_rects),
    ("linear_gradient", golden_baseline_linear_gradient),
    ("clip_transform_opacity", golden_baseline_clip_transform_opacity),
    ("path_fill", golden_baseline_path_fill),
  ]
}
