///|
using @views {
  button,
  canvas,
  column,
  container,
  expanded,
  row,
  spacer,
  text,
  text_field,
}

///|
/// 默认首页。
///
/// 注意:当前引擎的 JS 只执行内联 `<script>`,不加载外链脚本,
/// 且无外链 CSS/图片资源——JS 渲染的站点(如 bing.com 首页是 SPA,
/// 主体为空壳 `<div id="hp_app">`,DOM 生成代码在未加载的外链脚本里)
/// 仍会显示空白。默认选纯服务器渲染的站点,保证启动即可看到真实网页。
pub let default_url : String = "https://news.ycombinator.com"

///|
/// 本机默认代理(用户环境);`program(proxy=...)` 可覆盖,传 None 禁用。
pub let default_proxy : String? = Some("http://127.0.0.1:7897")

///|
/// 网络加载期间显示的内置页面。
fn loading_html(url : String) -> String {
  [
    "<!DOCTYPE html>", "<html>", "<head>", "<style>", "  body { font-family: sans-serif; margin: 0; padding: 16px; background: #f2f4f7; }",
    "  .card {", "    background: white; border-radius: 8px; padding: 12px;", "    margin: 10px 0; border: 1px solid #dadce0;",
    "  }", "</style>", "</head>", "<body>", "  <h1 style='color:#1a73e8'>加载中…</h1>",
    "  <div class='card'><b>", url, "</b><p>正在通过网络获取页面。首次加载可能需要几秒。</p></div>",
    "</body>", "</html>",
  ].join("\n")
}

///|
/// 网络加载失败时显示的内置页面。
fn error_html(url : String, message : String) -> String {
  [
    "<!DOCTYPE html>", "<html>", "<head>", "<style>", "  body { font-family: sans-serif; margin: 0; padding: 16px; background: #f2f4f7; }",
    "  .card {", "    background: white; border-radius: 8px; padding: 12px;", "    margin: 10px 0; border: 1px solid #dadce0;",
    "  }", "</style>", "</head>", "<body>", "  <h1 style='color:#d93025'>加载失败</h1>",
    "  <div class='card'><b>", url, "</b><p>", message, "</p></div>", "</body>",
    "</html>",
  ].join("\n")
}

///|
pub struct Model {
  address : String
  status : String
  loading : Bool
  pending_url : String
  proxy : String?
  commands : Array[@core.DrawCommand]
  links : Array[@moui_crater.LinkRegion]
  js : @moui_crater.JsEngine
  console_logs : Array[String]
  script_errors : Int
  renders : Int
}

///|
pub(all) enum Msg {
  AddressChanged(String)
  LoadAddress
  PollNetwork
  CanvasDrag(@core.DragGestureEvent)
}

///|
pub fn Model::new(
  address? : String = default_url,
  proxy? : String? = default_proxy,
) -> Model {
  {
    address,
    status: "ready",
    loading: false,
    pending_url: "",
    proxy,
    commands: [],
    links: [],
    js: @moui_crater.JsEngine::new(),
    console_logs: [],
    script_errors: 0,
    renders: 0,
  }
}

///|
pub fn update(model : Model, message : Msg) -> (Model, @moui.Effect[Msg]) {
  match message {
    AddressChanged(value) => ({ ..model, address: value }, @moui.Effect::none())
    LoadAddress => model.navigate(model.address)
    PollNetwork => model.poll_network()
    CanvasDrag(event) =>
      match event.phase {
        @core.DragGesturePhase::Ended =>
          model.handle_canvas_click(event.position)
        _ => (model, @moui.Effect::none())
      }
  }
}

///|
/// Synchronously render HTML through crater, translate the paint tree into
/// MoUI draw commands, and run page `<script>` bodies on the embedded
/// pure-MoonBit JS engine with the DOM bridge shim (`document`/`window`
/// basics): scripts build a shadow DOM which is serialized back to HTML
/// before crater rendering.
fn Model::render_source(
  self : Model,
  source : String,
  origin : String,
) -> Model {
  let (html, run) = @moui_crater.render_page_with_resources(
    self.js,
    source,
    origin,
    self.proxy,
  )
  let result = @moui_crater.render_html_document(
    html, content_width, content_height,
  )
  let scripts = @moui_crater.extract_scripts(source)
  let logs = self.console_logs
  for line in run.outputs {
    logs.push(line)
  }
  let mut status = "rendered " +
    result.commands.length().to_string() +
    " cmds, " +
    result.links.length().to_string() +
    " links"
  if scripts.length() > 0 {
    status = status + ", ran " + scripts.length().to_string() + " scripts"
  }
  if run.errors.length() > 0 {
    status = status + ", " + run.errors.length().to_string() + " script errors"
  }
  {
    ..self,
    address: origin,
    commands: result.commands,
    links: result.links,
    console_logs: logs,
    script_errors: run.errors.length(),
    status,
    renders: self.renders + 1,
  }
}

///|
/// 导航:data: 立即解码渲染;http(s) 走网络(异步);其他内容直接当 HTML 渲染。
fn Model::navigate(self : Model, href : String) -> (Model, @moui.Effect[Msg]) {
  match @moui_crater.decode_data_url(href) {
    Some(html) => (self.render_source(html, href), @moui.Effect::none())
    None =>
      if href.has_prefix("http://") || href.has_prefix("https://") {
        (
          {
            ..self.render_source(loading_html(href), href),
            loading: true,
            pending_url: href,
            status: "loading " + href,
          },
          fetch_effect(href, self.proxy),
        )
      } else {
        (self.render_source(href, href), @moui.Effect::none())
      }
  }
}

///|
/// 每帧轮询 curl 桥的结果队列(由 subscriptions 的 timer 触发)。
fn Model::poll_network(self : Model) -> (Model, @moui.Effect[Msg]) {
  match @moui_crater.poll_fetch() {
    Some(@moui_crater.FetchOutcome::Fetched(html~)) =>
      (
        { ..self.render_source(html, self.pending_url), loading: false },
        @moui.Effect::none(),
      )
    Some(@moui_crater.FetchOutcome::FetchFailed(message~)) =>
      (
        {
          ..self.render_source(
            error_html(self.pending_url, message),
            self.pending_url,
          ),
          loading: false,
          status: "load failed: " + self.pending_url + " (" + message + ")",
        },
        @moui.Effect::none(),
      )
    None => (self, @moui.Effect::none())
  }
}

///|
fn Model::handle_canvas_click(
  self : Model,
  position : @core.Point,
) -> (Model, @moui.Effect[Msg]) {
  match self.link_at(position) {
    Some(href) => self.navigate(href)
    None =>
      (
        {
          ..self,
          status: "clicked at (" +
          position.x.to_string() +
          ", " +
          position.y.to_string() +
          ")",
        },
        @moui.Effect::none(),
      )
  }
}

///|
fn Model::link_at(self : Model, position : @core.Point) -> String? {
  for link in self.links {
    if position.x >= link.x &&
      position.x <= link.x + link.width &&
      position.y >= link.y &&
      position.y <= link.y + link.height {
      return Some(link.href)
    }
  }
  None
}

///|
/// 发起后台抓取:detached 线程里跑 curl,结果写入加锁槽,
/// 主线程经 PollNetwork 轮询取回。`proxy` 非 None 时 curl 走 `-x`。
fn fetch_effect(url : String, proxy : String?) -> @moui.Effect[Msg] {
  @moui.Effect::task(key="browser:nav:" + url, start=_send => {
    ignore(@moui_crater.start_fetch(url, proxy))
    None
  })
}

///|
pub fn program(
  initial_url? : String = default_url,
  proxy? : String? = default_proxy,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=(
    // 启动即导航默认页;init 同步渲染加载页,网络在后台线程进行
    ) => Model::new(proxy~).navigate(initial_url),
    update=(model, message) => update(model, message),
    view~,
    subscriptions=model => {
      if model.loading {
        match environment.timer() {
          Some(source) =>
            source.subscription(
              interval_ms=100.0,
              key="browser:net-poll",
              label="browser network poll",
              map=_ => PollNetwork,
            )
          None => @moui.Subscription::none()
        }
      } else {
        @moui.Subscription::none()
      }
    },
  )
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let theme = @views.default_theme()
  column(
    [header(model, theme), toolbar(model), expanded(content_surface(model))],
    spacing=12.0,
  )
  .padding(16.0)
  .background(theme.palette.background)
}

///|
fn header(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  container(
    row(
      [
        column(
          [
            text("MoUI Browser").font(theme.typography.title),
            text(model.status)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
            if model.console_logs.length() > 0 {
              text(
                "console: " +
                model.console_logs[model.console_logs.length() - 1],
              )
              .font(theme.typography.caption)
              .foreground(theme.palette.muted)
            } else {
              text("").font(theme.typography.caption)
            },
          ],
          spacing=2.0,
        ),
        spacer(min_length=12.0),
      ],
      align=@views.CrossAlign::Center,
    ),
    padding=6.0,
  )
}

///|
fn toolbar(model : Model) -> @moui.View[Msg] {
  container(
    row(
      [
        text_field(
          model.address,
          on_input=value => AddressChanged(value),
          on_submit=Some(LoadAddress),
          variant=@views.TextFieldVariant::Outline,
          width=640.0,
          height=34.0,
        ),
        button(
          "Go",
          on_click=LoadAddress,
          variant=@views.ButtonVariant::Primary,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    padding=4.0,
  )
}

///|
let content_width = 840.0

///|
let content_height = 540.0

///|
fn content_surface(model : Model) -> @moui.View[Msg] {
  container(
    canvas(
      measure=fn(_constraints : @core.Constraints) -> @core.Size {
        { width: content_width, height: content_height }
      },
      draw=fn(ctx : @views.PaintContext, _frame : @core.Rect) -> Unit {
        ctx.commands.push(
          @core.DrawCommand::Clear({ r: 1.0, g: 1.0, b: 1.0, a: 1.0 }),
        )
        for command in model.commands {
          ctx.commands.push(command)
        }
      },
    ),
    padding=0.0,
  )
}
