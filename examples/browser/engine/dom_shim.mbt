///|
/// DOM bridge shim(JS 侧):在 js_engine realm 内实现最小 document/window
/// API,页面脚本操作影子 DOM,执行完后宿主取 `__moui_dump_html()` 序列化
/// 为 HTML,再走 crater 渲染管线。
///
/// 设计约束(js_engine 0.7.0 能力边界):
/// - 只用基础 ES 语法(var/function/对象/数组/字符串/正则/try-catch/闭包)
/// - 不用 getter/setter:`textContent`/`innerHTML` 预置为 null 哨兵,
///   页面赋值后 dump 据此区分"设置过"与"未设置"
/// - 事件只存储不派发;`__moui_dispatch_ready()` 由宿主在脚本执行完后
///   调用,派发 document 的 DOMContentLoaded 与 window 的 load
///
let dom_shim_js : String =
  #|(function(){
  #|  // 动态 <script src> 注册表:宿主在脚本执行后取走并抓取执行
  #|  var __dynScripts = [];
  #|  function makeText(text) {
  #|    return {
  #|      nodeType: 3, tag: '#text', tagName: '#text',
  #|      textContent: String(text), _children: [], _attrs: {},
  #|      parentNode: null, _listeners: {}
  #|    };
  #|  }
  #|  function esc(s) {
  #|    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  #|      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  #|  }
  #|  function classListFor(el) {
  #|    var cl = {
  #|      _el: el, _set: {},
  #|      add: function(c) { this._set[c] = 1; this.sync(); },
  #|      remove: function(c) { delete this._set[c]; this.sync(); },
  #|      contains: function(c) { return this._set[c] === 1; },
  #|      toggle: function(c, force) {
  #|        if (force === undefined) force = !this.contains(c);
  #|        if (force) { this.add(c); return true; } else { this.remove(c); return false; }
  #|      },
  #|      sync: function() {
  #|        var names = [];
  #|        for (var k in this._set) names.push(k);
  #|        this._el.className = names.join(' ');
  #|      }
  #|    };
  #|    return cl;
  #|  }
  #|  function styleFor(el) {
  #|    return {
  #|      _el: el, cssText: '', _props: {},
  #|      setProperty: function(k, v) { this._props[k] = String(v); },
  #|      getPropertyValue: function(k) { return k in this._props ? this._props[k] : ''; },
  #|      removeProperty: function(k) { delete this._props[k]; }
  #|    };
  #|  }
  #|  function makeEl(tag) {
  #|    var e = {
  #|      nodeType: 1, tag: tag, tagName: String(tag).toUpperCase(),
  #|      _attrs: {}, _children: [], parentNode: null,
  #|      id: '', className: '',
  #|      textContent: null, innerHTML: null,
  #|      _listeners: {}, dataset: {},
  #|      style: null, classList: null,
  #|      setAttribute: function(k, v) {
  #|        this._attrs[k] = String(v);
  #|        if (k === 'id') this.id = String(v);
  #|        if (k === 'class') this.className = String(v);
  #|      },
  #|      getAttribute: function(k) { return k in this._attrs ? this._attrs[k] : null; },
  #|      hasAttribute: function(k) { return k in this._attrs; },
  #|      removeAttribute: function(k) { delete this._attrs[k]; if (k === 'id') this.id = ''; },
  #|      appendChild: function(c) {
  #|        if (!c) return c;
  #|        if (c.parentNode) { c.parentNode.removeChild(c); }
  #|        c.parentNode = this;
  #|        this._children.push(c);
  #|        // 动态脚本加载:页面在运行时 appendChild 带 src 的 <script>
  #|        if (c.tag === 'script' && (c.src || c._attrs['src'])) {
  #|          __dynScripts.push(c.src || c._attrs['src']);
  #|        }
  #|        return c;
  #|      },
  #|      removeChild: function(c) {
  #|        for (var i = 0; i < this._children.length; i++) {
  #|          if (this._children[i] === c) {
  #|            this._children.splice(i, 1);
  #|            c.parentNode = null;
  #|            return c;
  #|          }
  #|        }
  #|        return null;
  #|      },
  #|      insertBefore: function(c, ref) {
  #|        if (!c) return c;
  #|        if (c.parentNode) { c.parentNode.removeChild(c); }
  #|        c.parentNode = this;
  #|        if (!ref) { this._children.push(c); return c; }
  #|        for (var i = 0; i < this._children.length; i++) {
  #|          if (this._children[i] === ref) {
  #|            this._children.splice(i, 0, c);
  #|            return c;
  #|          }
  #|        }
  #|        this._children.push(c);
  #|        return c;
  #|      },
  #|      replaceChild: function(n, o) {
  #|        for (var i = 0; i < this._children.length; i++) {
  #|          if (this._children[i] === o) {
  #|            this._children[i] = n; n.parentNode = this; o.parentNode = null;
  #|            return o;
  #|          }
  #|        }
  #|        return null;
  #|      },
  #|      remove: function() { if (this.parentNode) { this.parentNode.removeChild(this); } },
  #|      addEventListener: function(t, fn) {
  #|        if (!this._listeners[t]) { this._listeners[t] = []; }
  #|        this._listeners[t].push(fn);
  #|      },
  #|      removeEventListener: function(t, fn) {
  #|        var arr = this._listeners[t];
  #|        if (!arr) return;
  #|        for (var i = 0; i < arr.length; i++) {
  #|          if (arr[i] === fn) { arr.splice(i, 1); return; }
  #|        }
  #|      },
  #|      getBoundingClientRect: function() {
  #|        return { top: 0, left: 0, right: 0, bottom: 0, width: 0, height: 0, x: 0, y: 0 };
  #|      },
  #|      focus: function() {}, click: function() {},
  #|      contains: function(n) {
  #|        while (n) { if (n === this) return true; n = n.parentNode; }
  #|        return false;
  #|      },
  #|      get children() { return this._children; },
  #|      get firstChild() { return this._children.length > 0 ? this._children[0] : null; },
  #|      get lastChild() { return this._children.length > 0 ? this._children[this._children.length - 1] : null; }
  #|    };
  #|    e.style = styleFor(e);
  #|    e.classList = classListFor(e);
  #|    return e;
  #|  }
  #|  function findById(el, id) {
  #|    if (el.id === id) return el;
  #|    for (var i = 0; i < el._children.length; i++) {
  #|      var r = findById(el._children[i], id);
  #|      if (r) return r;
  #|    }
  #|    return null;
  #|  }
  #|  function findByClass(el, cls, out) {
  #|    if (el.className && (' ' + el.className + ' ').indexOf(' ' + cls + ' ') >= 0) out.push(el);
  #|    for (var i = 0; i < el._children.length; i++) findByClass(el._children[i], cls, out);
  #|  }
  #|  function findByTag(el, tag, out) {
  #|    if (el.tag === tag) out.push(el);
  #|    for (var i = 0; i < el._children.length; i++) findByTag(el._children[i], tag, out);
  #|  }
  #|  function matchesSimple(el, sel) {
  #|    // 支持 #id、.class、tag、tag#id、tag.class
  #|    var tag = null, id = null, cls = null;
  #|    var m = sel.match(/^([a-zA-Z][a-zA-Z0-9]*)?([#.][a-zA-Z0-9_-]+)?([#.][a-zA-Z0-9_-]+)?$/);
  #|    if (!m) return false;
  #|    tag = m[1] || null;
  #|    if (m[2] && m[2].charAt(0) === '#') id = m[2].substring(1);
  #|    else if (m[2]) cls = m[2].substring(1);
  #|    if (m[3] && m[3].charAt(0) === '#') id = m[3].substring(1);
  #|    else if (m[3]) cls = m[3].substring(1);
  #|    if (tag && el.tag !== tag) return false;
  #|    if (id && el.id !== id) return false;
  #|    if (cls && (' ' + el.className + ' ').indexOf(' ' + cls + ' ') < 0) return false;
  #|    return true;
  #|  }
  #|  function queryAll(el, sel, out) {
  #|    if (matchesSimple(el, sel)) out.push(el);
  #|    for (var i = 0; i < el._children.length; i++) queryAll(el._children[i], sel, out);
  #|  }
  #|  var ATTR_PROPS = ['href','src','type','value','name','placeholder','alt',
  #|    'title','disabled','checked','selected','colspan','rowspan','width',
  #|    'height','target','rel','action','method','for','role','tabindex',
  #|    'download','accept','autocomplete','autofocus','form','lang','dir',
  #|    'size','maxlength','min','max','step','pattern','multiple',
  #|    'required','readonly','wrap','align','valign'];
  #|  function dumpNode(n) {
  #|    if (n.nodeType === 3) return esc(n.textContent);
  #|    if (n.nodeType === 11) {
  #|      var frag = '';
  #|      for (var i = 0; i < n._children.length; i++) frag += dumpNode(n._children[i]);
  #|      return frag;
  #|    }
  #|    var attrs = '';
  #|    for (var k in n._attrs) attrs += ' ' + k + '="' + esc(n._attrs[k]) + '"';
  #|    // 直接属性赋值(如 a.href = '/x')也要进序列化
  #|    for (var p = 0; p < ATTR_PROPS.length; p++) {
  #|      var key = ATTR_PROPS[p];
  #|      if (n[key] !== undefined && n[key] !== null) {
  #|        // 避免与 _attrs 重复输出
  #|        if (!(key in n._attrs)) attrs += ' ' + key + '="' + esc(n[key]) + '"';
  #|      }
  #|    }
  #|    // className 赋值(未走 setAttribute)与 classList 都要输出
  #|    if (n.className && n.className !== '' && !('class' in n._attrs)) {
  #|      attrs += ' class="' + esc(n.className) + '"';
  #|    }
  #|    if (n.style && n.style.cssText) attrs += ' style="' + esc(n.style.cssText) + '"';
  #|    var inner = '';
  #|    if (n.innerHTML !== null && n.innerHTML !== undefined) {
  #|      inner = n.innerHTML;
  #|    } else if (n.textContent !== null && n.textContent !== undefined) {
  #|      inner = esc(n.textContent);
  #|    } else {
  #|      for (var i = 0; i < n._children.length; i++) inner += dumpNode(n._children[i]);
  #|    }
  #|    return '<' + n.tag + attrs + '>' + inner + '</' + n.tag + '>';
  #|  }
  #|  function fire(listeners, ev) {
  #|    if (!listeners) return;
  #|    for (var i = 0; i < listeners.length; i++) {
  #|      try { listeners[i](ev); } catch (e) {}
  #|    }
  #|  }
  #|  var documentElement = makeEl('html');
  #|  var head = makeEl('head');
  #|  var body = makeEl('body');
  #|  documentElement.appendChild(head);
  #|  documentElement.appendChild(body);
  #|  var document = {
  #|    nodeType: 9,
  #|    documentElement: documentElement,
  #|    head: head,
  #|    body: body,
  #|    title: '',
  #|    _listeners: {},
  #|    createElement: function(tag) { return makeEl(tag); },
  #|    createTextNode: function(text) { return makeText(text); },
  #|    createDocumentFragment: function() {
  #|      return { nodeType: 11, _children: [], parentNode: null, _attrs: {},
  #|        appendChild: function(c) { c.parentNode = this; this._children.push(c); return c; },
  #|        removeChild: function(c) {
  #|          for (var i = 0; i < this._children.length; i++) {
  #|            if (this._children[i] === c) { this._children.splice(i, 1); c.parentNode = null; return c; }
  #|          }
  #|          return null;
  #|        }
  #|      };
  #|    },
  #|    getElementById: function(id) { return findById(body, id) || findById(head, id); },
  #|    getElementsByClassName: function(cls) {
  #|      var out = []; findByClass(body, cls, out); findByClass(head, cls, out); return out;
  #|    },
  #|    getElementsByTagName: function(tag) {
  #|      var out = []; findByTag(body, tag, out); findByTag(head, tag, out); return out;
  #|    },
  #|    querySelector: function(sel) {
  #|      var out = []; queryAll(body, sel, out); if (out.length > 0) return out[0];
  #|      var out2 = []; queryAll(head, sel, out2); return out2.length > 0 ? out2[0] : null;
  #|    },
  #|    querySelectorAll: function(sel) {
  #|      var out = []; queryAll(body, sel, out); queryAll(head, sel, out); return out;
  #|    },
  #|    addEventListener: function(t, fn) {
  #|      if (!this._listeners[t]) { this._listeners[t] = []; }
  #|      this._listeners[t].push(fn);
  #|    },
  #|    write: function() {}
  #|  };
  #|  var location = { href: '', protocol: 'https:', host: '', pathname: '/',
  #|    search: '', hash: '', origin: '' };
  #|  var navigator = { userAgent: 'MoUI Browser', platform: 'MoonBit',
  #|    language: 'zh-CN', onLine: true };
  #|  // window 即 globalThis:页面脚本的 `var x` 与 `window.x` 一致
  #|  var windowObj = this;
  #|  windowObj.document = document;
  #|  windowObj.location = location;
  #|  windowObj.navigator = navigator;
  #|  windowObj.innerWidth = 840;
  #|  windowObj.innerHeight = 540;
  #|  windowObj.devicePixelRatio = 1;
  #|  windowObj._listeners = {};
  #|  windowObj.addEventListener = function(t, fn) {
  #|    if (!this._listeners[t]) { this._listeners[t] = []; }
  #|    this._listeners[t].push(fn);
  #|  };
  #|  windowObj.removeEventListener = function(t, fn) {
  #|    var arr = this._listeners[t]; if (!arr) return;
  #|    for (var i = 0; i < arr.length; i++) {
  #|      if (arr[i] === fn) { arr.splice(i, 1); return; }
  #|    }
  #|  };
  #|  windowObj.requestAnimationFrame = function(fn) { setTimeout(function(){ fn(Date.now()); }, 0); };
  #|  windowObj.getComputedStyle = function() { return { getPropertyValue: function(){ return ''; } }; };
  #|  windowObj.scrollTo = function() {};
  #|  function noopCtor() {}
  #|  noopCtor.prototype.observe = function() {};
  #|  noopCtor.prototype.disconnect = function() {};
  #|  noopCtor.prototype.takeRecords = function() { return []; };
  #|  var MutationObserver = noopCtor;
  #|  function HTMLElementCtor() {}
  #|  function ElementCtor() {}
  #|  function NodeCtor() {}
  #|  function TextCtor() {}
  #|  function DocumentFragmentCtor() {}
  #|  // 注入全局
  #|  this.document = document;
  #|  this.window = windowObj;
  #|  this.self = windowObj;
  #|  this.globalThis = this;
  #|  this.location = location;
  #|  this.navigator = navigator;
  #|  this.HTMLElement = HTMLElementCtor;
  #|  this.Element = ElementCtor;
  #|  this.Node = NodeCtor;
  #|  this.Text = TextCtor;
  #|  this.DocumentFragment = DocumentFragmentCtor;
  #|  this.MutationObserver = MutationObserver;
  #|  this.performance = { now: function(){ return 0; } };
  #|  // 宿主接口
  #|  this.__moui_take_dynamic_scripts = function() {
  #|    var out = __dynScripts;
  #|    __dynScripts = [];
  #|    return out;
  #|  };
  #|  this.__moui_dump_html = function() {
  #|    var s = '';
  #|    for (var i = 0; i < body._children.length; i++) s += dumpNode(body._children[i]);
  #|    return s;
  #|  };
  #|  this.__moui_reset = function() {
  #|    body._children = []; head._children = [];
  #|    document.title = ''; document._listeners = {};
  #|    windowObj._listeners = {};
  #|    __dynScripts = [];
  #|  };
  #|  this.__moui_dispatch_ready = function() {
  #|    fire(document._listeners['DOMContentLoaded'], { type: 'DOMContentLoaded' });
  #|    fire(windowObj._listeners['load'], { type: 'load' });
  #|    fire(windowObj._listeners['DOMContentLoaded'], { type: 'DOMContentLoaded' });
  #|  };
  #|  this.__moui_set_location = function(url) {
  #|    location.href = url;
  #|  };
  #|}).call(this);
