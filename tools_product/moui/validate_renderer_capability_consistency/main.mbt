///|
/// Validate `docs/renderer-capability-report.md` against the renderer
/// capability self-reports in code.
///
/// The capability self-report (`RendererProvider.capabilities`) is the single
/// source of truth. This validator parses the report's grouped table and
/// checks, per feature row, that the Skia / native WGPU / Sun columns match
/// the status returned by the corresponding `*_capabilities` functions:
///
/// - "Skia raster native"       <- `@render_skia.skia_provider_capabilities`
///   (provider `skia-raster`, `SkiaRasterNative`)
/// - "Native wgpu diagnostic"   <- `@render_wgpu.wgpu_provider_capabilities`
///   (provider `wgpu`, `NativeWgpu`)
/// - "Sun CPU raster"           <- `@render_sun.sun_feature_capabilities()`
///   (provider `sun-raster`)
///
/// The "Web wasm-gc" column is intentionally out of scope: its self-report
/// lives in `moui_web_renderer`, a `wasm-gc`-only package that a
/// native validator cannot import. Web capability consistency is covered by
/// the wasm-side package tests instead.
///
/// The report's "Follow-up" column is free-form evidence text and is not
/// compared.
///
/// Report status strings map to `RendererFeatureStatus` as
/// supported/partial/gap/host-forwarded/unavailable.

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_renderer_capability_consistency [--repo-root PATH]
    #|
    #|Checks that docs/renderer-capability-report.md table statuses match the
    #|renderer capability self-reports in moui/render/{skia,wgpu,sun}.
    #|
  )
}

///|
/// Report row name -> `RendererFeature`. Rows whose names are absent here
/// (unknown features) are reported as failures instead of being ignored.
fn feature_by_report_name(name : String) -> @render.RendererFeature? {
  match name {
    "Rect" => Some(@render.RendererFeature::Rect)
    "Rounded rect" => Some(@render.RendererFeature::RoundedRect)
    "Gradient" => Some(@render.RendererFeature::Gradient)
    "Shadow" => Some(@render.RendererFeature::Shadow)
    "Text" => Some(@render.RendererFeature::Text)
    "Image" => Some(@render.RendererFeature::Image)
    "Clip" => Some(@render.RendererFeature::Clip)
    "Transform" => Some(@render.RendererFeature::Transform)
    "Opacity" => Some(@render.RendererFeature::Opacity)
    "Layer compositing" => Some(@render.RendererFeature::LayerCompositing)
    "Blend mode" => Some(@render.RendererFeature::BlendMode)
    "Filter effect" => Some(@render.RendererFeature::FilterEffect)
    "Path/vector" => Some(@render.RendererFeature::PathVector)
    "Shader effect" => Some(@render.RendererFeature::ShaderEffect)
    "Text shaping" => Some(@render.RendererFeature::TextShaping)
    "Emoji text" => Some(@render.RendererFeature::EmojiText)
    "Async image" => Some(@render.RendererFeature::AsyncImage)
    _ => None
  }
}

///|
fn status_from_report(text : String) -> @render.RendererFeatureStatus? {
  match text.trim() {
    "supported" => Some(@render.RendererFeatureStatus::Supported)
    "partial" => Some(@render.RendererFeatureStatus::Partial)
    "gap" => Some(@render.RendererFeatureStatus::Gap)
    "host-forwarded" => Some(@render.RendererFeatureStatus::HostForwarded)
    "unavailable" => Some(@render.RendererFeatureStatus::Unavailable)
    _ => None
  }
}

///|
fn status_label(status : @render.RendererFeatureStatus) -> String {
  match status {
    Supported => "supported"
    Partial => "partial"
    Gap => "gap"
    HostForwarded => "host-forwarded"
    Unavailable => "unavailable"
  }
}

///|
/// Split a markdown table line into its cells (without the leading/trailing
/// pipes and surrounding whitespace).
fn split_cells(line : String) -> Array[String] {
  let mut body = line.trim().to_owned()
  if body.has_prefix("|") {
    body = body[1:].to_owned()
  }
  if body.has_suffix("|") {
    body = body[:body.length() - 1].to_owned()
  }
  let cells : Array[String] = []
  for part in body.split("|") {
    cells.push(part.to_owned().trim().to_owned())
  }
  cells
}

///|
/// A single parsed table row. The Web column is intentionally not stored:
/// the "Web wasm-gc" column is out of scope (see module doc).
struct ReportRow {
  line_no : Int
  feature_name : String
  skia : String
  wgpu : String
  sun : String
}

///|
/// Parse the capability table out of the report text. Returns the header
/// line number (1-based) and the data rows.
fn parse_table(text : String) -> (Int, Array[ReportRow]) {
  let rows : Array[ReportRow] = []
  let mut header_line = 0
  let mut line_no = 0
  for line in text.split("\n") {
    line_no += 1
    if line.trim().has_prefix("| Feature |") {
      header_line = line_no
      continue
    }
    if header_line > 0 && line.trim().has_prefix("|") {
      let cells = split_cells(line.to_owned())
      if cells.length() >= 5 && cells[0] != "---" {
        rows.push({
          line_no,
          feature_name: cells[0],
          skia: cells[1],
          wgpu: cells[3],
          sun: cells[4],
        })
      }
    }
  }
  (header_line, rows)
}

///|
/// Collect a provider's self-reported status for every `RendererFeature`.
fn status_by_feature(
  caps : Array[@render.RendererBackendFeatureCapability],
) -> (@render.RendererFeature) -> @render.RendererFeatureStatus {
  fn(feature : @render.RendererFeature) -> @render.RendererFeatureStatus {
    let mut result : @render.RendererFeatureStatus? = None
    for cap in caps {
      if cap.feature == feature {
        result = Some(cap.status)
        break
      }
    }
    match result {
      Some(status) => status
      None => @render.RendererFeatureStatus::Unavailable
    }
  }
}

///|
struct ColumnRule {
  column_label : String
  provider_id : String
  status_of : (@render.RendererFeature) -> @render.RendererFeatureStatus
}

///|
fn code_statuses() -> Array[ColumnRule] {
  let skia_caps = @render_skia.skia_provider_capabilities(
    provider_id="skia-raster",
    backend=@render.RendererBackendKind::SkiaRasterNative,
  )
  let wgpu_caps = @render_wgpu.wgpu_provider_capabilities(
    provider_id="wgpu",
    backend=@render.RendererBackendKind::NativeWgpu,
  )
  let sun_caps = @render_sun.sun_feature_capabilities()
  [
    {
      column_label: "Skia raster native",
      provider_id: "skia-raster",
      status_of: status_by_feature(skia_caps),
    },
    {
      column_label: "Native wgpu diagnostic",
      provider_id: "wgpu",
      status_of: status_by_feature(wgpu_caps),
    },
    {
      column_label: "Sun CPU raster",
      provider_id: "sun-raster",
      status_of: status_by_feature(sun_caps),
    },
  ]
}

///|
/// Report cell accessor per column rule.
fn report_cell(row : ReportRow, label : String) -> String {
  match label {
    "Skia raster native" => row.skia
    "Native wgpu diagnostic" => row.wgpu
    "Sun CPU raster" => row.sun
    _ => row.skia
  }
}

///|
fn run(repo_root : String) -> Int {
  let report_path = @tools.resolve_path(
    repo_root, "docs/renderer-capability-report.md",
  )
  let text = match
    @tools.read_required_text(report_path, "docs/renderer-capability-report.md") {
    Ok(text) => text
    Err(message) => {
      println(message)
      return 1
    }
  }
  let (header_line, rows) = parse_table(text)
  if header_line == 0 {
    println(
      "failure: no capability table header (`| Feature |`) found in docs/renderer-capability-report.md",
    )
    return 1
  }
  if rows.length() == 0 {
    println(
      "failure: capability table has no data rows (header at line \{header_line})",
    )
    return 1
  }
  let rules = code_statuses()
  let failures : Array[String] = []
  let mut checked = 0
  for row in rows {
    let feature = feature_by_report_name(row.feature_name)
    match feature {
      None =>
        failures.push(
          "row \{row.line_no}: unknown feature name `\{row.feature_name}` in report table",
        )
      Some(feature) =>
        for rule in rules {
          let report_status = status_from_report(
            report_cell(row, rule.column_label),
          )
          let code_status = (rule.status_of)(feature)
          match report_status {
            None =>
              failures.push(
                "row \{row.line_no} / \{rule.column_label}: report value `\{report_cell(row, rule.column_label)}` is not a recognized status",
              )
            Some(report_status) => {
              checked += 1
              if report_status != code_status {
                failures.push(
                  "row \{row.line_no} / \{rule.column_label} / \{row.feature_name}: report says \{status_label(report_status)}, code self-report (\{rule.provider_id}) says \{status_label(code_status)}",
                )
              }
            }
          }
        }
    }
  }
  if failures.length() > 0 {
    println(
      "renderer capability consistency: \{failures.length()} mismatch(es) across \{checked} checked cells:",
    )
    for failure in failures {
      println("  - \{failure}")
    }
    1
  } else {
    println(
      "renderer capability consistency: \{checked} cells match the code self-reports",
    )
    0
  }
}

///|
fn main {
  let args = @tools.args_without_program(@env.args())
  let mut repo_root = "."
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--repo-root" =>
        if i + 1 < args.length() {
          repo_root = args[i + 1]
          i += 2
          continue
        }
      "--help" | "-h" => {
        println(usage())
        return
      }
      _ => ()
    }
    i += 1
  }
  let code = run(repo_root)
  if code != 0 {
    @sys.exit(code)
  }
}
