///|
let sample_manifest =
  #|{
  #|  "overallStatus": "passed",
  #|  "targets": [
  #|    {
  #|      "name": "showcase-web-wasm",
  #|      "status": "passed",
  #|      "observations": {
  #|        "radialGradient": "yes",
  #|        "transformPixels": "yes",
  #|        "colorEmojiPixels": "yes",
  #|        "zwjGrapheme": "yes",
  #|        "bidiLayout": "yes",
  #|        "paragraphWrapping": "yes",
  #|        "selectionRects": "yes",
  #|        "graphemeEditing": "yes",
  #|        "imeCandidateAnchor": "yes",
  #|        "imeCompositionVisual": "yes",
  #|        "asyncImageSecondFrame": "yes"
  #|      },
  #|      "screenshot": {
  #|        "radialGradient": { "passed": true, "evidence": ["center-mid-edge-pixels", "shader-payload"] },
  #|        "colorEmojiPixels": {
  #|          "passed": true,
  #|          "evidence": ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
  #|          "metadata": {
  #|            "font": {
  #|              "family": "system-ui, emoji",
  #|              "source": "browser-canvas",
  #|              "textSystem": "webgpu-wasm",
  #|              "shaper": "browser-canvas"
  #|            },
  #|            "glyph": {
  #|              "format": "rgba",
  #|              "glyphCount": 1,
  #|              "clusterCount": 1,
  #|              "highSaturationPixels": 42,
  #|              "alphaPixels": 120,
  #|              "key": "1|normal|400|24|system-ui|rgba|emoji",
  #|              "width": 24,
  #|              "height": 24
  #|            }
  #|          }
  #|        },
  #|        "zwjGrapheme": { "passed": true, "evidence": ["single-grapheme-cluster", "no-interior-caret"] },
  #|        "bidiLayout": { "passed": true, "evidence": ["visual-order"] },
  #|        "paragraphWrapping": { "passed": true, "evidence": ["line-metrics", "later-line-pixels"] },
  #|        "selectionRects": { "passed": true, "evidence": ["selection-rects", "line-range"] },
  #|        "graphemeEditing": { "passed": true, "evidence": ["grapheme-boundaries", "edit-actions"] },
  #|        "imeCandidateAnchor": { "passed": true, "evidence": ["candidate-anchor", "surrounding-text"] },
  #|        "imeCompositionVisual": { "passed": true, "evidence": ["composition-range", "preedit-pixels"] },
  #|        "asyncImageSecondFrame": { "passed": true, "evidence": ["late-completion", "repaint-request", "second-frame-pixels"] }
  #|      }
  #|    }
  #|  ]
  #|}

///|
fn sample_showcase() -> Map[String, Json] {
  sample_showcase_from_text(sample_manifest)
}

///|
fn sample_showcase_from_text(text : String) -> Map[String, Json] {
  let parsed = @json.parse(text) catch { _ => return {} }
  let manifest = match json_object(Some(parsed)) {
    Some(value) => value
    None => return {}
  }
  match find_showcase_target(manifest) {
    Some(value) => value
    None => {}
  }
}

///|
test "metadata token value replaces whitespace runs" {
  assert_true(metadata_token_value("system-ui, emoji") == "system-ui,_emoji")
  assert_true(metadata_token_value("a  b\tc") == "a_b_c")
}

///|
test "proof readiness and markers are detected from manifest" {
  let showcase = sample_showcase()
  assert_true(proof_ready(Some(showcase), "radialGradient"))
  assert_true(color_emoji_metadata_ready(Some(showcase)))
  let lines = marker_lines(Some(showcase))
  assert_true(lines.any(line => line.contains("colorEmojiPixels passed")))
  assert_true(lines.any(line => line.contains("font_family=system-ui,_emoji")))
  assert_true(missing_proofs(Some(showcase)).is_empty())
}

///|
test "missing color emoji glyph key keeps proof missing" {
  let showcase = sample_showcase_from_text(
    sample_manifest.replace(
      old="\"key\": \"1|normal|400|24|system-ui|rgba|emoji\"",
      new="\"key\": \"\"",
    ),
  )
  assert_false(color_emoji_metadata_ready(Some(showcase)))
  assert_true(missing_proofs(Some(showcase)).contains("colorEmojiPixels"))
}
