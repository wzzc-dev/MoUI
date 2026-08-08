///|
/// DOM bridge(shim)测试:验证页面脚本经 document API 建树、序列化 HTML、
/// 事件派发、重置。

///|
fn run_and_dump(js : JsEngine, code : String) -> String? {
  js.engine.eval(code) catch {
    _ => ()
  }
  js.dump_dom_html()
}

///|
fn json_string_contains(j : Json, needle : String) -> Bool {
  match j {
    Json::String(s) => s.contains(needle)
    _ => false
  }
}

///|
test "dom shim: createElement appendChild textContent" {
  let js = JsEngine::new()
  let html = run_and_dump(
    js,
    "var d = document.createElement('div'); d.setAttribute('id','box');" +
    "d.textContent = 'hello'; document.body.appendChild(d);",
  )
  debug_inspect(html, content="Some(\"<div id=\\\"box\\\">hello</div>\")")
}

///|
test "dom shim: nested tree and className" {
  let js = JsEngine::new()
  let html = run_and_dump(
    js,
    "var ul = document.createElement('ul'); ul.className = 'list';" +
    "for (var i = 0; i < 2; i++) {" +
    "  var li = document.createElement('li'); li.textContent = 'item' + i; ul.appendChild(li);" +
    "}" +
    "document.body.appendChild(ul);",
  )
  debug_inspect(
    html,
    content="Some(\"<ul class=\\\"list\\\"><li>item0</li><li>item1</li></ul>\")",
  )
}

///|
test "dom shim: classList and style" {
  let js = JsEngine::new()
  let html = run_and_dump(
    js,
    "var a = document.createElement('a'); a.href = '/x'; a.classList.add('nav');" +
    "a.classList.add('active'); a.style.cssText = 'color: red;';" +
    "document.body.appendChild(a);",
  )
  debug_inspect(
    html,
    content="Some(\"<a href=\\\"/x\\\" class=\\\"nav active\\\" style=\\\"color: red;\\\"></a>\")",
  )
}

///|
test "dom shim: getElementById and querySelector" {
  let js = JsEngine::new()
  js.engine.eval(
    "var root = document.createElement('div'); root.id = 'app';" +
    "var p = document.createElement('p'); p.className = 'msg'; p.textContent = 'hi';" +
    "root.appendChild(p); document.body.appendChild(root);" +
    "function __q1(){ var el = document.getElementById('app'); return el ? el.tag : 'none' }" +
    "function __q2(){ var el = document.querySelector('.msg'); return el ? el.textContent : 'none' }",
  ) catch {
    _ => ()
  }
  let r1 = js.engine.call_json("__q1", []) catch { _ => @json.to_json(()) }
  debug_inspect(json_string_contains(r1, "div"), content="true")
  let r2 = js.engine.call_json("__q2", []) catch { _ => @json.to_json(()) }
  debug_inspect(json_string_contains(r2, "hi"), content="true")
}

///|
test "dom shim: documentFragment and innerHTML passthrough" {
  let js = JsEngine::new()
  let html = run_and_dump(
    js,
    "var frag = document.createDocumentFragment();" +
    "var s1 = document.createElement('span'); s1.textContent = 'a'; frag.appendChild(s1);" +
    "var s2 = document.createElement('span'); s2.textContent = 'b'; frag.appendChild(s2);" +
    "document.body.appendChild(frag);" +
    "var box = document.createElement('div'); box.innerHTML = '<b>bold</b>'; document.body.appendChild(box);",
  )
  debug_inspect(
    html,
    content="Some(\"<span>a</span><span>b</span><div><b>bold</b></div>\")",
  )
}

///|
test "dom shim: reset clears tree between navigations" {
  let js = JsEngine::new()
  ignore(
    run_and_dump(js, "document.body.appendChild(document.createElement('div'))"),
  )
  js.reset_dom("https://example.com")
  let html = js.dump_dom_html()
  debug_inspect(html, content="Some(\"\")")
}

///|
test "dom shim: DOMContentLoaded listeners fire after scripts" {
  let js = JsEngine::new()
  js.engine.eval(
    "window.__ready = 0;" +
    "document.addEventListener('DOMContentLoaded', function(){ window.__ready = 1 });" +
    "window.addEventListener('load', function(){ window.__ready += 2 });",
  ) catch {
    _ => ()
  }
  js.dispatch_ready()
  js.engine.eval("function __qr(){ return window.__ready }")
  let r = js.engine.call_json("__qr", []) catch { _ => @json.to_json(()) }
  let ready : Int = @json.from_json(r) catch { _ => -1 }
  debug_inspect(ready, content="3")
}

///|
test "dom shim: innerHTML setter survives page script reading it" {
  let js = JsEngine::new()
  js.engine.eval(
    "var box = document.createElement('div'); box.innerHTML = '<i>x</i>';" +
    "var read = box.innerHTML; document.body.appendChild(box);",
  ) catch {
    _ => ()
  }
  js.engine.eval("function __qr2(){ return window.read }")
  let r = js.engine.call_json("__qr2", []) catch { _ => @json.to_json(()) }
  debug_inspect(json_string_contains(r, "<i>x</i>"), content="true")
}
