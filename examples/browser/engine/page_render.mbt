///|
/// 页面渲染入口(仅内联脚本):执行内联脚本,序列化影子 DOM 交给 crater。
/// 无脚本页面原样渲染;dump 为空回退原始 HTML。
pub fn render_html_with_js(
  js : JsEngine,
  source : String,
  url : String,
) -> (String, ScriptRunResult) {
  let scripts = extract_scripts(source)
  if scripts.length() == 0 {
    return (source, { outputs: [], errors: [] })
  }
  js.reset_dom(url)
  let run = js.run_scripts(scripts)
  js.pump_events()
  match js.dump_dom_html() {
    Some(body_html) if body_html.length() > 0 =>
      // 无内联样式/脚本的包装;页面自带 <head> 内容(如内联 CSS)在此丢失,
      // 属已知限制(影子 DOM 只承载 body)
      (
        "<!DOCTYPE html><html><head></head><body>" +
        body_html +
        "</body></html>",
        run,
      )
    _ => (source, run)
  }
}

///|
/// 页面渲染入口(含 DOM bridge 与子资源加载):执行页面脚本(内联 + 外链,
/// 外链并行抓取)、收集外链样式表,序列化影子 DOM 后交给 crater 渲染。
///
/// 流程:
/// 1. 提取脚本条目(内联/外链按文档顺序)与外链样式表 href
/// 2. 无外链资源:走纯内联路径(原 render_html_with_js 行为)
/// 3. 有外链:resolve 绝对 URL → 批量并行抓取(线程池) →
///    内联+外链脚本按文档顺序执行(失败容忍)→ 派发就绪事件 →
///    序列化 body HTML,外链 CSS 内容拼入 `<head>` 的 `<style>`
/// 4. dump 为空回退原始 HTML
pub fn render_page_with_resources(
  js : JsEngine,
  source : String,
  url : String,
  proxy : String?,
) -> (String, ScriptRunResult) {
  let entries = extract_script_entries(source)
  let styles = extract_stylesheets(source)
  let external_src : Array[String] = []
  for e in entries {
    if !e.inline && e.src.length() > 0 {
      external_src.push(resolve_url(url, e.src))
    }
  }
  let has_external = external_src.length() > 0 || styles.length() > 0
  if !has_external {
    // 纯内联/无脚本:现有路径
    return render_html_with_js(js, source, url)
  }
  // 批量抓取外链脚本与样式表(并行线程)
  let fetch_urls : Array[String] = []
  for s in external_src {
    fetch_urls.push(s)
  }
  for href in styles {
    fetch_urls.push(resolve_url(url, href))
  }
  let results = fetch_resources(fetch_urls, proxy)
  let external_bodies : Array[String] = []
  let style_bodies : Array[String] = []
  let mut idx = 0
  for r in results {
    if idx < external_src.length() {
      external_bodies.push(if r.ok { r.body } else { "" })
    } else {
      style_bodies.push(if r.ok { r.body } else { "" })
    }
    idx = idx + 1
  }
  // 组装脚本序列:内联与外链按文档顺序,外链用抓取内容替换
  let ordered : Array[String] = []
  let mut ext_i = 0
  for e in entries {
    if e.inline {
      ordered.push(e.body)
    } else {
      if ext_i < external_bodies.length() && external_bodies[ext_i].length() > 0 {
        ordered.push(external_bodies[ext_i])
      }
      ext_i = ext_i + 1
    }
  }
  js.reset_dom(url)
  let run = js.run_scripts(ordered)
  js.pump_events()
  // 动态脚本循环:页面运行时 appendChild 的 <script src>(如 rms 按需
  // 加载器),逐轮抓取执行,最多 4 轮(SPA bundle 可能再触发加载)。
  let mut round = 0
  while round < 4 {
    let dyn_urls = js.take_dynamic_scripts()
    if dyn_urls.length() == 0 {
      break
    }
    let resolved : Array[String] = []
    for u in dyn_urls {
      resolved.push(resolve_url(url, u))
    }
    let dyn_results = fetch_resources(resolved, proxy)
    let bodies : Array[String] = []
    for r in dyn_results {
      if r.ok && r.body.length() > 0 {
        bodies.push(r.body)
      }
    }
    if bodies.length() > 0 {
      let run2 = js.run_scripts(bodies)
      for e in run2.errors {
        run.errors.push(e)
      }
      for o in run2.outputs {
        run.outputs.push(o)
      }
      js.pump_events()
    }
    round = round + 1
  }
  let style_html = StringBuilder()
  for css in style_bodies {
    if css.length() > 0 {
      style_html.write_string("<style>")
      style_html.write_string(css)
      style_html.write_string("</style>")
    }
  }
  match js.dump_dom_html() {
    Some(body_html) if body_html.length() > 0 =>
      (
        "<!DOCTYPE html><html><head>" +
        style_html.to_string() +
        "</head><body>" +
        body_html +
        "</body></html>",
        run,
      )
    _ => {
      // 脚本未生成 DOM(或报错):回退原始 HTML,但仍注入外链 CSS
      let css = style_html.to_string()
      if css.length() > 0 {
        (inject_styles(source, css), run)
      } else {
        (source, run)
      }
    }
  }
}

///|
/// 把抓到的外链 CSS 注入原始 HTML 的 </head> 之前(没有 </head> 则加前缀)。
fn inject_styles(source : String, style_html : String) -> String {
  let head_end = source.find("</head>")
  match head_end {
    Some(i) => source[:i].to_owned() + style_html + source[i:].to_owned()
    None => "<head>" + style_html + "</head>" + source
  }
}

///|
/// 相对引用解析:绝对 URL 原样返回;相对路径拼到 base 的 scheme+host。
/// 复用网络层的 Location 解析逻辑。
pub fn resolve_url(base : String, ref_url : String) -> String {
  resolve_location(ref_url, base)
}
