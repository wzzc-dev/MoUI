// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CanvasReplayStats with Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasReplayStats with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CanvasReplayStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasReplayStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontMetrics with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontMetrics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphId with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderCompletion with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderCompletion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderCompletionStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderCompletionStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerControl with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerControl with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerDiagnostics with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerDiagnostics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerState with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeGpuWorkerCompletion with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeGpuWorkerCompletion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeGpuWorkerCompletionStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeGpuWorkerCompletionStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeGpuWorkerDiagnostics with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeGpuWorkerDiagnostics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeReplayResourceStats with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeReplayResourceStats with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ParagraphHitTestResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ParagraphHitTestResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ParagraphLineMetric with Debug::{to_repr}

///|
#doc(hidden)
pub extend ParagraphLineMetric with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaGpuContextSupportStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaGpuContextSupportStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceFrameReplayStats with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceFrameReplayStats with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceFrameReplayStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceFrameReplayStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceTargetSupportStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceTargetSupportStatus with Eq::{not_equal, equal}
