///|
/// TEMPORARY keystroke-phase probe for the input-path optimization work.
/// Remove after the benchmark comparison.
pub struct MarkdownEditorProbeBucket {
  label : String
  ms : Ref[Double]
  count : Ref[Int]
}

///|
let markdown_editor_probes : Array[MarkdownEditorProbeBucket] = []

///|
pub fn markdown_editor_probe_bucket(label : String) -> MarkdownEditorProbeBucket {
  let mut found : MarkdownEditorProbeBucket? = None
  for bucket in markdown_editor_probes {
    if bucket.label == label {
      found = Some(bucket)
      break
    }
  }
  match found {
    Some(bucket) => bucket
    None => {
      let bucket = MarkdownEditorProbeBucket::{ label, ms: Ref(0.0), count: Ref(0) }
      markdown_editor_probes.push(bucket)
      bucket
    }
  }
}

///|
fn markdown_editor_probe_now_ms() -> Double {
  @env.now().to_double()
}

///|
pub fn markdown_editor_probe_capture[A](
  label : String,
  body : () -> A,
) -> A {
  let bucket = markdown_editor_probe_bucket(label)
  let started = markdown_editor_probe_now_ms()
  let value = body()
  bucket.ms.val = bucket.ms.val + (markdown_editor_probe_now_ms() - started)
  bucket.count.val = bucket.count.val + 1
  value
}

///|
pub fn markdown_editor_probe_reset() -> Unit {
  for bucket in markdown_editor_probes {
    bucket.ms.val = 0.0
    bucket.count.val = 0
  }
}

///|
pub fn markdown_editor_probe_report() -> String {
  let lines : Array[String] = []
  for bucket in markdown_editor_probes {
    lines.push(
      "{\"label\":\"\{bucket.label}\",\"total_ms\":\{bucket.ms.val},\"count\":\{bucket.count.val}}",
    )
  }
  "[" + lines.join(",") + "]"
}
