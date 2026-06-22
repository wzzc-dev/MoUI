# wzzc-dev - MoonBit Graphics & Text Rendering

A collection of MoonBit libraries for 2D graphics rendering, text processing, and display.

## Project Structure

```
wzzc-dev/
├── moon.mod                    # Root module
├── moon.work                   # Workspace configuration
│
├── graphics/                   # 2D graphics rendering
│   ├── moon.mod
│   ├── color.mbt              # RGBA color
│   ├── path.mbt               # Vector path
│   ├── paint.mbt              # Paint configuration
│   ├── pixmap.mbt             # Pixel buffer
│   ├── layer.mbt              # Off-screen layer cache
│   ├── layer_tree.mbt         # Z-ordered cached layer composition
│   ├── render_frame.mbt       # Frame canvas + layer tree submit unit
│   ├── rasterizer.mbt         # Scanline rasterizer
│   └── canvas.mbt             # Drawing canvas
│
├── text/                       # Text processing
│   ├── moon.mod
│   ├── reader.mbt             # Binary reader
│   ├── tables.mbt             # TTF tables
│   ├── parser.mbt             # TTF parser
│   ├── font.mbt               # Font data
│   ├── glyph.mbt              # Glyph representation
│   ├── shaper.mbt             # Text shaping
│   ├── layout.mbt             # Layout engine
│   ├── rasterizer.mbt         # Glyph rasterizer
│   ├── renderer.mbt           # Font renderer
│   └── file_io.mbt            # File I/O (uses moonbitlang/x/fs)
│
├── renderer/                   # Graphics + text integration
│   ├── moon.mod
│   ├── renderer.mbt           # Renderer core and text mask composition
│   └── renderer_test.mbt
│
├── softbuffer/                 # Pixel display
│   ├── moon.mod
│   ├── ffi.mbt                # FFI bindings
│   ├── surface.mbt            # graphics.Surface native present targets
│   ├── native_renderer.h      # Native present declarations
│   └── native_renderer.c      # Win32 present implementation and non-Windows stubs
│
└── examples/
    ├── headless_render/       # MemorySurface off-screen render smoke test
    │   ├── moon.mod
    │   ├── moon.pkg
    │   └── main.mbt
    ├── render_bench/          # Deterministic CPU render microbenchmark smoke
    │   ├── moon.mod
    │   ├── moon.pkg
    │   └── main.mbt
    ├── hello_world/            # RenderFrame + LayerTree window demo
    │   ├── moon.mod
    │   ├── moon.pkg
    │   └── main.mbt
    ├── font_demo/              # Font rendering demo
    │   ├── moon.mod
    │   ├── moon.pkg
    │   └── main.mbt
    └── triangle_window/        # Triangle rendering demo
        ├── moon.mod
        ├── moon.pkg
        └── main.mbt
```

## Libraries

### graphics
2D graphics rendering library.

**Features:**
- Color, Path, Paint, Pixmap, Canvas, Layer, LayerTree, RenderFrame
- Scanline triangle/polygon fill
- Bresenham line drawing
- Bezier curve rendering
- `Canvas` line/polyline/polygon/arc/pie/rect/circle/ellipse and uniform/per-corner rounded-rect helpers for reusable GUI dividers, borders, progress rings, badges, ovals, panels, tabs, buttons, charts, simple icons, and input backgrounds
- `Path` conservative control-point bounds, fill-rule point containment
  queries, exact no-op simplification, and path-local affine transforms for hit
  testing, planning, reuse, and later geometry refinement
- `Canvas::draw_placeholder_text` for debug text boxes; real text drawing lives in `renderer`
- Canvas save/restore state stack, transform-aware rect/path drawing, transform helpers, and intersecting clip scopes for nested GUI drawing
- `PaintShader` device-space linear/radial/sweep gradients, color stops,
  spread modes, local transform inspection, and color-stop/geometry metadata
  queries for vector fills/strokes and coverage-mask drawing, with solid-color
  fallback through `Paint`
- `PaintFilter` identity/modulate/grayscale color filter chains with stage
  metadata for solid/shader/mask and paint-aware Pixmap drawing paths
- `Surface` trait, `MemorySurface` with present-operation records, aggregate
  present telemetry plus telemetry reset, isolated full/rect `Pixmap`, raw RGBA
  byte, and PPM snapshots, full/rect pixel checksums, present helpers,
  preflight-validated present batches with source-byte telemetry, and
  dirty-present batch dry-runs for `Canvas`, `LayerTree`, `RenderFrame`, and
  `Pixmap`
- Pixmap blitting, source-rect atlas drawing, source-rect coverage-mask drawing,
  tiled Pixmap fills, explicit nearest/bilinear/bicubic sampling modes,
  quality strategies for fast/balanced/high image drawing, transform-aware
  sampled Pixmap drawing, Porter-Duff and artistic Paint blend modes,
  deterministic full/rect raw RGBA bytes, PPM(P6) export, and lightweight
  full/rect pixel checksums for headless fixtures, and straight-alpha
  composition for image, glyph atlas, and layer caching
- `PixmapCache` for keyed reuse of image/layer pixmaps with copy-isolated cache
  entries, membership introspection, optional hit/insert telemetry, and opt-in
  LRU entry limits
- Nine-patch Pixmap scaling for reusable GUI panel/background image composition
- `PixelRect` / `DirtyRegion` tracking with merge, explicit dirty-present/dirty-submit plans, scheduler states, and `Canvas` bounded dirty-present helpers
- `Layer` off-screen caches with resize, overlap preservation, opacity/blend-mode
  composition, and dirty-region composition back into a target `Canvas`
- `LayerTree` z-order composition with dirty rectangle propagation, layer resize/remove/replace/reorder lifecycle, opacity/blend-mode property-change invalidation, dirty-present planning/batch dry-runs, and partial present submission
- `RenderFrame` as a frame-sized canvas and layer-tree submit unit with resize lifecycle, single/batched layer resize/clear and replacement/redraw helpers, dirty queries/marking, dirty-submit planning/results, event-loop schedule snapshots, explicit DirtyOnly/CachedRedraw/FullRedraw submit policies, policy-aware submit requests, cached redraw schedule execution, precomputed schedule submit execution, result-level scheduler, did-present, planned rect/cost telemetry, dirty batch dry-runs, Skip/Partial/Full present strategy planning, and strategy-aware submit helpers for backend event-loop integration

### text
Text processing library (font parsing, shaping, layout).

**Features:**
- TTF font loading and parsing
- Checked TTF structural validation through `FontFace`/`FontData` parsing
- Documented `FontParseError` categories for callers that load untrusted font bytes
- `FontFace`, `GlyphRun`, and `TextLayout` facades for renderer and GUI-facing text APIs, including glyph coverage queries for fallback/resource selection
- `FontFallbackPlan` for segmenting text across an ordered `FontFace` stack and
  reporting missing-glyph spans before fallback shaping or cache scheduling
- `FontFaceCache` for keyed reuse of checked parsed faces in GUI/resource code,
  with membership introspection, optional hit/parse-miss telemetry, and opt-in
  LRU entry limits
- `TextSystem` for GUI/editor-facing keyed in-memory font registration/removal,
  checked parsed-face reuse, registered `FontData` lookup/replacement
  telemetry, registered-font layout, and caret geometry in layout-local
  coordinates
- `GlyphMaskCache` for keyed reuse of individual glyph coverage masks, with
  membership introspection, optional hit/rasterize-miss telemetry, and opt-in
  LRU entry limits
- `GlyphMaskAtlas` for text-local row-packed placement of copied glyph masks,
  with capacity, occupancy, free-space, fit-query, rotate-on-full insert, and
  atlas hit/new-insert telemetry helpers for resource lifecycle decisions
- `TextMaskCache` for keyed reuse of rendered coverage masks with copy-isolated
  cache entries, membership introspection, optional hit/render-miss telemetry,
  and opt-in LRU entry limits
- Left, center, right, and basic non-final-line justify alignment through the `TextLayout` facade
- Explicit newline and empty-line preservation in `TextLayout`, text masks, and renderer text drawing
- Configurable letter spacing and word spacing through `LayoutConfig`
- Trailing-space measurement and wrapping semantics suitable for editor-style text blocks
- Simplified LTR/RTL shaping order with inspectable `ShapedText` glyphs and positions
- Text layout and basic Unicode line-break classes for digits, combining marks, Hangul clusters, joiners, emoji modifiers, CJK ranges, and supplementary-plane format-12 cmap input, with unspaced CJK/Hangul wrapping through `TextLayout`
- Glyph rasterization with anti-aliasing
- Kerning support

### renderer
Renderer integration layer that composes `graphics.Canvas` with `text` coverage masks.

**Features:**
- `Renderer::draw_text_face` for checked `FontFace -> TextLayout -> Canvas` drawing
- `Renderer::draw_text_fallback_line` for ordered `FontFace` fallback spans,
  with missing-glyph span telemetry for GUI labels and resource scheduling
- `Renderer::draw_text_fallback_line_cached` for repeated ordered `FontFace`
  fallback labels backed by `TextMaskCache`, with render-hit telemetry per span
- `Renderer::draw_text_face_cached` for caller-owned `TextMaskCache` backed
  label/text-run drawing with hit/render telemetry
- `Renderer::draw_text_face_atlas` for caller-owned glyph mask cache and
  `GlyphMaskAtlas` backed text drawing with per-call draw/skip/cache/atlas/clear
  telemetry
- `Renderer::draw_text_fallback_line_atlas` for ordered `FontFace` fallback
  labels backed by glyph mask cache and `GlyphMaskAtlas` telemetry
- `RendererTextResources` for sharing bounded text-mask cache, glyph-mask cache,
  glyph atlas state, text/glyph residency checks, and cache/atlas snapshot
  telemetry across renderer text draws
- `RendererResources` for sharing checked font-face cache, renderer text
  resources, image `PixmapCache`, and font/text/glyph/image residency and
  snapshot telemetry from one GUI/resource object
- `Renderer::draw_font_bytes_cached_with_renderer_resources`, fallback-line,
  fallback atlas, and single-face atlas-backed font-byte drawing for checked
  parse reuse with font/span/text/glyph/atlas telemetry
- `Renderer::draw_pixmap_cached` and quality-scaled cached pixmap drawing for
  `RendererResources` backed image reuse with hit/insert telemetry
- `Renderer::draw_coverage_mask` for testing and low-level mask composition
- `Renderer::draw_glyph_atlas_entry` for compositing one glyph placement from a
  `GlyphMaskAtlas` coverage snapshot
- End-to-end regression from a parsed TTF printable ASCII fixture to rendered `Pixmap` pixels
- Keeps `graphics` independent from font parsing and text layout

### softbuffer
Native-handle pixel presentation adapter.

**Features:**
- `NativeSurface` implementation of the `graphics.Surface` present contract for
  external native window handles
- `RenderFrame -> NativeSurface` dirty/full present methods plus dry-run packed
  present batches, event-loop schedule snapshots, explicit native submit
  policies, policy-aware submit requests, cached redraw submit methods,
  precomputed schedule submit methods, and adapters for graphics-core
  strategy-aware submit/query/plan results with dirty bounds, fallback state,
  planned rect/cost, and full-present savings telemetry for window integration
- `NativeSurface` frame-size match/sync helpers and synced policy/strategy
  submit wrappers for persistent backend surfaces across window resize events
- Optional `NativeSurface` pre-present hook for window lifecycle notifications before validated native presents
- `NativeSurface::present` uses the same validated full-frame contract as
  `Surface::present_pixels`, including error propagation and hook timing
- Native full-frame and rectangle present entry points for dirty redraw plumbing;
  the current C backend presents through Win32 GDI on Windows and AppKit
  `NSView` layer contents on macOS, with no-op stubs for other native hosts

### examples
Small build-checked programs that exercise the public packages together.

**Features:**
- `headless_render` renders a GUI-style frame through `RenderFrame`,
  `LayerTree`, and `MemorySurface`, then self-checks graphics-core
  strategy-aware submit planning/results and PPM fixture bytes without creating
  a window
- `render_bench` runs a deterministic CPU render workload covering fill rect,
  path fill, stroke, glyph raster/mask composition, Pixmap blit, and full
  present-copy telemetry
- `hello_world` uses `graphics.RenderFrame`, `LayerTree`, frame-level resize/clear/replacement redraw helpers, and `softbuffer` policy-aware submit requests as a minimal window submit path with resize/redraw lifecycle reuse
- `font_demo` renders real TTF text through the `renderer` package
- `triangle_window` keeps a simple native pixel-output smoke test

## Building & Running

### Prerequisites

- **MoonBit** - https://www.moonbitlang.com/
- **Visual Studio Build Tools** - For native compilation on Windows

### Using VS Developer Command Prompt (Recommended)

The easiest way to build and run on Windows is using the VS Developer Command Prompt:

```powershell
# 1. Open VS Developer PowerShell
& "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# 2. Then validate the native softbuffer package
moon test softbuffer
```

Or create a batch file `check-softbuffer.bat`:

```batch
@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
moon test softbuffer
```

The current GUI example packages import `wzzc-dev/window/macos`, so they are
macOS build/run examples until the example packages are split by host window
backend.

### Manual Environment Setup (PowerShell)

If you prefer to set environment variables manually:

```powershell
$env:PATH = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231\bin\Hostx64\x64;$env:PATH"
$env:INCLUDE = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231\include;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um"
$env:LIB = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64"

moon test softbuffer
```

### Commands

```bash
# Check all packages
moon check

# Run the local validation gate
scripts/check_ci.sh

# Run deterministic render microbenchmark smoke workload
moon run examples/render_bench

# Run renderer package tests directly
moon test graphics
moon test text
moon test renderer
moon test softbuffer

# Build native GUI examples (current packages are macOS window examples)
moon build examples/hello_world --target native
moon build examples/font_demo --target native
moon build examples/triangle_window --target native

# Run headless rendering smoke test
moon run examples/headless_render

# Manual GUI smoke tests; these open windows and run until closed
moon run examples/hello_world --target native
moon run examples/font_demo --target native
moon run examples/triangle_window --target native
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                            │
│               (examples/font_demo)                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   graphics    │   │     text      │   │  softbuffer   │
│  (渲染图形)    │   │  (解析字体)    │   │  (显示到屏幕)  │
└───────┬───────┘   └───────┬───────┘   └───────────────┘
        │                   │
        └─────────┬─────────┘
                  ▼
          ┌───────────────┐
          │   renderer    │
          │ (组合渲染管线) │
          └───────────────┘
```

## Project Direction

The long-term goal is to grow this repository into a MoonBit-native,
CPU-first, testable, cross-platform lightweight 2D rendering stack for text,
vector graphics, pixel output, and GUI foundations. See [ROADMAP.md](ROADMAP.md)
for milestones and acceptance criteria, and [docs/testing.md](docs/testing.md)
for the local validation gate. The checked font parser error contract is tracked
in [docs/font-parser-errors.md](docs/font-parser-errors.md), and text API facade
boundaries are tracked in [docs/text-api-boundaries.md](docs/text-api-boundaries.md).

## License

Apache-2.0
