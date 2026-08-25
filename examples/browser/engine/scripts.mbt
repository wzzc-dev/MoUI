///|
/// Page script execution host backed by `dowdiness/js_engine` (pure MoonBit
/// embedded JavaScript engine). App code only sees this wrapper; the engine
/// instance keeps one realm alive across page loads for stateful pages.
///
/// The realm is seeded with a minimal DOM bridge shim (`dom_shim.mbt`):
/// page scripts can use `document`/`window` basics, and after script
/// execution the host serializes the shadow DOM back to HTML for the
/// crater render pipeline.
pub struct JsEngine {
  engine : @js_engine.Engine
}

///|
pub struct ScriptRunResult {
  outputs : Array[String]
  errors : Array[String]
}

///|
pub fn JsEngine::new() -> JsEngine {
  let js = { engine: @js_engine.Engine() }
  // 安装 DOM shim;失败(引擎语法不兼容)时页面脚本的 document 用法照旧报错
  js.engine.eval(dom_shim_js) catch {
    _ => ()
  }
  js
}

///|
/// 新导航前重置影子 DOM 与事件监听;并同步 `location`。
pub fn JsEngine::reset_dom(self : JsEngine, url : String) -> Unit {
  self.engine.eval("__moui_reset()") catch {
    _ => ()
  }
  self.engine.eval(
    "__moui_set_location(" + @json.to_json(url).stringify() + ")",
  ) catch {
    _ => ()
  }
}

///|
/// 脚本执行完后取回影子 DOM 序列化的 body HTML 片段。
pub fn JsEngine::dump_dom_html(self : JsEngine) -> String? {
  let r = self.engine.call_json("__moui_dump_html", []) catch {
    _ => return None
  }
  match r {
    Json::String(s) => Some(s)
    _ => None
  }
}

///|
/// 取回页面运行时动态添加的 `<script src>`(appendChild 注册),取走后清空。
pub fn JsEngine::take_dynamic_scripts(self : JsEngine) -> Array[String] {
  let r = self.engine.call_json("__moui_take_dynamic_scripts", []) catch {
    _ => return []
  }
  match r {
    Json::Array(items) =>
      items.filter_map(fn(item) {
        match item {
          Json::String(s) => Some(s)
          _ => None
        }
      })
    _ => []
  }
}

///|
/// 脚本执行后的"事件推进"：驱动 js_engine 的 timer 回调(页面常用
/// setTimeout/sb_st 调度加载与初始化,如 bing 的 onPP → rms 链),
/// 再派发 DOMContentLoaded/load。
pub fn JsEngine::pump_events(self : JsEngine) -> Unit {
  // timer checkpoint 可能触发新脚本注册;有限次迭代覆盖嵌套调度
  let mut rounds = 0
  while rounds < 8 && self.engine.has_pending_timers() {
    self.engine.run_timer_checkpoint() catch {
      _ => break
    }
    rounds = rounds + 1
  }
  self.dispatch_ready()
}

///|
/// 派发 document 的 DOMContentLoaded 与 window 的 load(脚本全部执行完后)。
pub fn JsEngine::dispatch_ready(self : JsEngine) -> Unit {
  self.engine.eval("__moui_dispatch_ready()") catch {
    _ => ()
  }
}

///|
/// Evaluate each `<script>` body (no `src`) in document order, collecting
/// console output and per-script errors. Errors are non-fatal: later
/// scripts still run.
pub fn JsEngine::run_scripts(
  self : JsEngine,
  scripts : Array[String],
) -> ScriptRunResult {
  let outputs = self.engine.take_output()
  let errors : Array[String] = []
  for script in scripts {
    let ok = try {
      self.engine.eval(script)
      true
    } catch {
      err => {
        errors.push(err.to_string())
        false
      }
    }
    let after = self.engine.take_output()
    for line in after {
      outputs.push(line)
    }
    if ok {
      // keep going: errors are non-fatal and already collected
    }
  }
  { outputs, errors }
}

///|
/// Drain any console output produced by previous script activity.
pub fn JsEngine::drain_output(self : JsEngine) -> Array[String] {
  self.engine.take_output()
}

///|
/// Depth-first document order `<script>` bodies (scripts with `src` are
/// skipped: external loading is a network concern).
pub fn extract_scripts(html : String) -> Array[String] {
  let entries = extract_script_entries(html)
  let out : Array[String] = []
  for e in entries {
    if e.inline {
      out.push(e.body)
    }
  }
  out
}

///|
/// 脚本条目:内联(body 非空)或外链(src 非空),按文档顺序。
pub struct ScriptEntry {
  inline : Bool
  src : String
  body : String
}

///|
/// 提取全部 `<script>` 条目(含外链 src),按文档顺序。
pub fn extract_script_entries(html : String) -> Array[ScriptEntry] {
  let out : Array[ScriptEntry] = []
  let doc = @html.parse_document(html)
  fn visit(e : @html.Element) -> Unit {
    if e.tag == "script" {
      let has_src = e.attributes.contains("src")
      let buf = StringBuilder()
      for child in e.children {
        match child {
          @html.Node::Text(text) => buf.write_string(text)
          @html.Node::Element(_) => ()
        }
      }
      out.push({
        inline: !has_src,
        src: if has_src {
          match e.attributes.get("src") {
            Some(v) => v
            None => ""
          }
        } else {
          ""
        },
        body: buf.to_string(),
      })
    }
    for child in e.children {
      match child {
        @html.Node::Element(sub) => visit(sub)
        @html.Node::Text(_) => ()
      }
    }
  }
  visit(doc.root)
  out
}

///|
/// 提取外链样式表 href(rel="stylesheet"),按文档顺序。
pub fn extract_stylesheets(html : String) -> Array[String] {
  let out : Array[String] = []
  let doc = @html.parse_document(html)
  fn visit(e : @html.Element) -> Unit {
    if e.tag == "link" {
      let rel = match e.attributes.get("rel") {
        Some(v) => v.to_lower()
        None => ""
      }
      if rel.contains("stylesheet") {
        match e.attributes.get("href") {
          Some(href) => out.push(href)
          None => ()
        }
      }
    }
    for child in e.children {
      match child {
        @html.Node::Element(sub) => visit(sub)
        @html.Node::Text(_) => ()
      }
    }
  }
  visit(doc.root)
  out
}
