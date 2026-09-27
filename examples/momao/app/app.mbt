///|
/// MoMao Studio 应用装配：Program 组合根 + 文件服务流（保存/打开/导出）
/// + 真实 provider 派发。平台入口只负责把 provider_submit 与 timer 接上。

///|
/// 提案 system prompt（真实 provider 用；从领域包转出，入口只认 app）。
pub fn proposal_system_prompt() -> String {
  @proposals.proposal_system_prompt()
}

///|
/// 讲解 system prompt（真实 provider 的「解释这个程序」）。
pub fn explanation_system_prompt() -> String {
  "You explain a MoMao program to a beginner in Chinese or English (match the source). Walk through it step by step in plain words: what each statement does, why the order matters, and what the user can try changing. Never rewrite the program; only explain."
}

///|
/// 语言持久化键（SettingsServices）。
pub const LANGUAGE_SETTINGS_KEY : String = "momao.language"

///|
/// 真实 provider 请求规格：由 app 组装（面板里的模型名 + 按请求类型
/// 选择的 system 提示），平台入口只负责投递，不再自行拼提示。
pub(all) struct ProviderRequestSpec {
  endpoint : String
  key : String
  model : String
  system : String
  prompt : String
}

///|
/// 真实 provider 提交签名：入口注入，UI 线程从不等待网络。
pub type ProviderSubmit = (
  ProviderRequestSpec,
  (Result[String, String]) -> Unit,
) -> Unit

///|
fn noop_provider_submit(
  _spec : ProviderRequestSpec,
  callback : (Result[String, String]) -> Unit,
) -> Unit {
  callback(Err("真实 provider 未接入"))
}

///|
/// 文件服务流：保存 / 打开 / 导出独立应用。
pub fn update_with_services(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    SaveRequested => {
      let options = @services.FileDialogOptions::new(
        title="保存 MoMao 项目",
        filters=["json"],
        default_name=Some("project.momao.json"),
      )
      (
        model,
        services.files().save_file(options~).effect(map=r => SavePathPicked(r)),
      )
    }
    SavePathPicked(result) =>
      match result {
        Success(path) =>
          (
            { ..model, notice: path, },
            services
            .files()
            .write_text(path, @codec.encode_program(model.program))
            .effect(map=r => SaveCompleted(r)),
          )
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    SaveCompleted(result) =>
      match result {
        Success(_) =>
          (
            { ..model, notice: text(translator(model), "app.status.saved"), },
            @moui.Effect::none(),
          )
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    OpenRequested => {
      let options = @services.FileDialogOptions::new(
        title="打开 MoMao 项目",
        filters=["json"],
      )
      (
        model,
        services.files().open_file(options~).effect(map=r => OpenPathPicked(r)),
      )
    }
    OpenPathPicked(result) =>
      match result {
        Success(path) =>
          (
            { ..model, notice: path, },
            services
            .files()
            .read_text(path)
            .effect(map=r => OpenReadCompleted(r)),
          )
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    OpenReadCompleted(result) =>
      match result {
        Success(source) =>
          match @codec.decode_program(source) {
            Ok(program) => {
              let next = {
                ..model,
                program,
                pending: None,
                run: None,
                mode: ModeDesign,
                runtime_values: @momao_lang.initial_values(program),
                runtime_texts: @momao_lang.initial_texts(program),
                selected_control: first_control_name(program.controls),
                selected_handler: first_handler_key(program.handlers),
                notice: text(translator(model), "app.status.opened"),
              }
              (sync_code_draft(next), @moui.Effect::none())
            }
            Err(_) =>
              (
                {
                  ..model,
                  notice: text(translator(model), "app.status.open_failed"),
                },
                @moui.Effect::none(),
              )
          }
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    ExportRequested => {
      let options = @services.FileDialogOptions::new(
        title="选择导出目录",
        filters=[],
      )
      (
        model,
        services
        .files()
        .pick_directory(options~)
        .effect(map=r => ExportDirPicked(r)),
      )
    }
    ExportDirPicked(result) =>
      match result {
        Success(dir) => {
          let bundle = bundle_files(
            @codec.encode_program(model.program),
            sanitize_export_name(model),
          )
          let effects : Array[@moui.Effect[Msg]] = []
          for pair in bundle {
            let path = "\{dir}/\{pair.0}"
            effects.push(
              services
              .files()
              .write_text(path, pair.1)
              .effect(map=r => ExportFileWritten(r)),
            )
          }
          (
            { ..model, notice: path_hint(dir, bundle), },
            @moui.Effect::batch(effects),
          )
        }
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    ExportFileWritten(result) =>
      match result {
        Success(_) =>
          (
            { ..model, notice: text(translator(model), "app.status.exported"), },
            @moui.Effect::none(),
          )
        Failure(error) =>
          ({ ..model, notice: error.message, }, @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    _ => update_pure(model, msg)
  }
}

///|
/// 导出目录名：窗口标题净化（小写 ASCII + 连字符，首尾去连字符）。
fn sanitize_export_name(model : Model) -> String {
  let chars : Array[Char] = []
  let mut last_was_dash = false
  for c in model.program.window.title {
    let code = c.to_int()
    if (code >= 0x61 && code <= 0x7A) || (code >= 0x30 && code <= 0x39) {
      chars.push(c)
      last_was_dash = false
    } else if code >= 0x41 && code <= 0x5A {
      chars.push((code + 0x20).unsafe_to_char())
      last_was_dash = false
    } else if chars.length() > 0 && !last_was_dash {
      chars.push('-')
      last_was_dash = true
    }
  }
  let mut begin = 0
  let mut finish = chars.length()
  while begin < finish && chars[begin] == '-' {
    begin = begin + 1
  }
  while finish > begin && chars[finish - 1] == '-' {
    finish = finish - 1
  }
  let buf = StringBuilder()
  let mut i = begin
  while i < finish {
    buf.write_char(chars[i])
    i = i + 1
  }
  let name = buf.to_string()
  if name == "" {
    "momao-app"
  } else {
    name
  }
}

///|
/// 导出 bundle 文件清单（services/export 的薄封装）。
pub fn bundle_files(
  program_json : String,
  name : String,
) -> Array[(String, String)] {
  @export.export_bundle(program_json, name)
}

///|
fn path_hint(dir : String, bundle : Array[(String, String)]) -> String {
  "\{dir}（\{bundle.length()} 个文件）"
}

///|
/// 设置读取结果 → 语言 tag（无值/失败 = 空串 → 回退中文）。
fn language_tag_of(result : @services.ServiceTaskResult[String?]) -> String {
  match result {
    Success(tag) =>
      match tag {
        Some(text) => text
        None => ""
      }
    _ => ""
  }
}

///|
/// 运行推进的计时器订阅：仅运行中激活。
fn run_subscription(
  model : Model,
  timer : @services.TimerSource?,
) -> @moui.Subscription[Msg] {
  match (model.run, timer) {
    (Some(run), Some(source)) =>
      if run.state.status is @momao_lang.Running {
        source.subscription(interval_ms=30.0, map=_frame => RunTick)
      } else {
        @moui.Subscription::none()
      }
    _ => @moui.Subscription::none()
  }
}

///|
/// Program 组合根。provider_submit 由平台入口注入（macOS 真实 worker；
/// Web 入口注入 noop——浏览器只用离线假模型）。
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  provider_submit? : ProviderSubmit = noop_provider_submit,
  provider_config? : ProviderConfig,
  apply_locale? : (String) -> Unit = _tag => (),
) -> @moui.Program[Model, Msg] {
  let services = environment.services()
  let timer = environment.timer()
  let submit = provider_submit
  let on_locale = apply_locale
  @moui.Program::new(
    init=() => {
      (
        initial_model(provider_config?),
        services
        .settings()
        .read(LANGUAGE_SETTINGS_KEY)
        .effect(map=result => LanguageLoaded(language_tag_of(result))),
      )
    },
    update=(model, msg) => {
      match msg {
        SaveRequested
        | SavePathPicked(_)
        | SaveCompleted(_)
        | OpenRequested
        | OpenPathPicked(_)
        | OpenReadCompleted(_)
        | ExportRequested
        | ExportDirPicked(_)
        | ExportFileWritten(_)
        | GenerateProposal
        | RealGenerationFinished(_)
        | ExplainHandler
        | RealExplanationFinished(_)
        | SwitchLanguage
        | LanguageLoaded(_) =>
          update_with_provider(model, msg, services, submit, on_locale)
        _ => update_pure(model, msg)
      }
    },
    view~,
    subscriptions=model => run_subscription(model, timer),
  )
}

///|
/// 带真实 provider 的服务流（GenerateProposal 走网络）。
fn update_with_provider(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
  submit : ProviderSubmit,
  apply_locale : (String) -> Unit,
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    SwitchLanguage => {
      let (switched, effect) = update_pure(model, SwitchLanguage)
      let tag = switched.language.tag()
      apply_locale(tag)
      (
        switched,
        @moui.Effect::batch([
          effect,
          services
          .settings()
          .write(LANGUAGE_SETTINGS_KEY, tag)
          .effect(map=_ => SetNotice("")),
        ]),
      )
    }
    LanguageLoaded(tag) => {
      let wanted = ui_language_from_tag(tag)
      let next = sync_code_draft({ ..model, language: wanted, })
      apply_locale(next.language.tag())
      (next, @moui.Effect::none())
    }
    ExplainHandler =>
      if model.provider_mode is Fake || model.provider_key == "" {
        update_pure(model, ExplainHandler)
      } else {
        match current_handler(model) {
          None => (model, @moui.Effect::none())
          Some(handler) =>
            (
              { ..model, explanation: "", ai_busy: true, },
              @moui.Effect::dispatch(emit => {
                submit(
                  {
                    endpoint: model.provider_endpoint,
                    key: model.provider_key,
                    model: model.provider_model,
                    system: explanation_system_prompt(),
                    prompt: @momao_lang.render_handler(
                      handler,
                      model.language.dsl_language(),
                    ),
                  },
                  result => emit(RealExplanationFinished(result)),
                )
              }),
            )
        }
      }
    GenerateProposal =>
      if model.provider_mode is Fake {
        update_pure(model, GenerateProposal)
      } else if model.provider_key == "" {
        (
          { ..model, prompt_error: text(translator(model), "app.ai.key"), },
          @moui.Effect::none(),
        )
      } else {
        (
          { ..model, prompt_error: "", ai_busy: true, },
          @moui.Effect::dispatch(emit => {
            submit(
              {
                endpoint: model.provider_endpoint,
                key: model.provider_key,
                model: model.provider_model,
                system: @proposals.proposal_system_prompt(),
                prompt: model.prompt_draft,
              },
              result => emit(RealGenerationFinished(result)),
            )
          }),
        )
      }
    _ => update_with_services(model, msg, services)
  }
}
