///|
using @views {
  banner,
  button,
  column,
  description_item,
  description_list,
  file_import_panel,
  row,
  stat_card,
  status_bar,
  container,
  text,
}

///|
pub struct FileImporterApp {
  unit : Unit
}

///|
pub(all) enum FileImporterStatus {
  Ready
  Requesting
  Unavailable(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ImportedFile {
  path : String
  source : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FileImporterModel {
  files : Array[ImportedFile]
  status : FileImporterStatus
  last_event : String
  availability_reason : String
}

///|
pub(all) struct FileImporterUpdate {
  model : FileImporterModel
  effect : @moui.Effect[FileImporterMsg]
}

///|
pub(all) enum FileImporterMsg {
  FilesDropped(Array[String])
  BrowseRequested
  FileDialogCompleted(@services.ServiceTaskResult[String])
  ClearSelection
}

///|
pub fn FileImporterApp::new() -> FileImporterApp {
  { unit: () }
}

///|
pub fn ImportedFile::new(path~ : String, source~ : String) -> ImportedFile {
  { path, source }
}

///|
pub fn FileImporterModel::new() -> FileImporterModel {
  {
    files: [],
    status: FileImporterStatus::Ready,
    last_event: "Waiting for files",
    availability_reason: "",
  }
}

///|
pub fn FileImporterModel::update(
  self : FileImporterModel,
  message : FileImporterMsg,
) -> FileImporterModel {
  match message {
    FilesDropped(paths) => self.with_paths(paths, source="Drop")
    BrowseRequested =>
      {
        ..self,
        status: FileImporterStatus::Unavailable(
          "file dialog service is unavailable",
        ),
        last_event: "File dialog unavailable",
        availability_reason: "file dialog service is unavailable",
      }
    FileDialogCompleted(result) => self.apply_file_dialog_result(result)
    ClearSelection => { ..self, files: [], last_event: "Selection cleared" }
  }
}

///|
pub fn FileImporterModel::update_with_services(
  self : FileImporterModel,
  message : FileImporterMsg,
  services : @services.AppServices,
) -> FileImporterUpdate {
  match message {
    BrowseRequested => self.request_file_dialog(services)
    _ => FileImporterUpdate::new(self.update(message))
  }
}

///|
pub fn FileImporterUpdate::new(
  model : FileImporterModel,
  effect? : @moui.Effect[FileImporterMsg] = @moui.Effect::none(),
) -> FileImporterUpdate {
  { model, effect }
}

///|
pub fn FileImporterUpdate::as_tuple(
  self : FileImporterUpdate,
) -> (FileImporterModel, @moui.Effect[FileImporterMsg]) {
  (self.model, self.effect)
}

///|
pub fn update(
  model : FileImporterModel,
  message : FileImporterMsg,
) -> FileImporterModel {
  model.update(message)
}

///|
pub fn FileImporterModel::selection(
  self : FileImporterModel,
) -> @views.FileSelection {
  @views.FileSelection::new(paths=self.files.map(file => file.path))
}

///|
pub fn FileImporterModel::availability(
  self : FileImporterModel,
) -> @views.FileImportAvailability {
  match self.status {
    FileImporterStatus::Ready => @views.FileImportAvailability::Available
    FileImporterStatus::Requesting => @views.FileImportAvailability::Pending
    FileImporterStatus::Unavailable(reason) =>
      @views.FileImportAvailability::Unavailable(reason)
  }
}

///|
pub fn view(model : FileImporterModel) -> @moui.View[FileImporterMsg] {
  model.view()
}

///|
pub fn FileImporterModel::view(
  self : FileImporterModel,
) -> @moui.View[FileImporterMsg] {
  let theme = @views.light_theme()
  let shell = column(
    [
      row(
        [
          column(
            [
              text(
                "File Importer",
                role=@views.TextRole::Title,
                theme~,
                width=260.0,
                height=34.0,
              ),
              text(
                "Drop files or request a host file dialog.",
                role=@views.TextRole::Caption,
                theme~,
                width=360.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          button(
            "Clear",
            on_click=ClearSelection,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=82.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Center,
      ),
      row(
        [
          file_import_panel(
            selection=self.selection(),
            on_drop=paths => FilesDropped(paths),
            on_browse=Some(BrowseRequested),
            availability=self.availability(),
            title="Import Files",
            drop_title="Drop files here",
            empty_message="No files selected",
            theme~,
            width=380.0,
          ),
          self.import_summary(theme),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      self.platform_note(theme),
      status_bar([self.last_event, self.status_label()], theme~, width=760.0),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
  container(
    shell,
    width=820.0,
    height=560.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn FileImporterApp::program(
  self : FileImporterApp,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[FileImporterModel, FileImporterMsg] {
  ignore(self)
  program(environment~)
}

///|
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[FileImporterModel, FileImporterMsg] {
  FileImporterModel::new().program(environment~)
}

///|
pub fn FileImporterModel::program(
  self : FileImporterModel,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[FileImporterModel, FileImporterMsg] {
  let services = environment.services()
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => {
      model.update_with_services(message, services).as_tuple()
    },
    view~,
  )
}

///|
fn FileImporterModel::request_file_dialog(
  self : FileImporterModel,
  services : @services.AppServices,
) -> FileImporterUpdate {
  FileImporterUpdate::new(
    {
      ..self,
      status: FileImporterStatus::Requesting,
      last_event: "Waiting for file picker",
      availability_reason: "",
    },
    effect=services
      .files()
      .open_file(
        options=@services.FileDialogOptions::new(title="Import files", filters=[
          "csv", "json", "txt",
        ]),
      )
      .effect(map=result => FileDialogCompleted(result)),
  )
}

///|
fn FileImporterModel::apply_file_dialog_result(
  self : FileImporterModel,
  result : @services.ServiceTaskResult[String],
) -> FileImporterModel {
  match result {
    Success(path) => self.with_paths([path], source="Dialog")
    Failure(error) =>
      {
        ..self,
        status: FileImporterStatus::Unavailable(error.message),
        last_event: "File dialog unavailable",
        availability_reason: error.message,
      }
    Cancelled => self.with_paths([], source="Dialog")
  }
}

///|
fn FileImporterModel::with_paths(
  self : FileImporterModel,
  paths : Array[String],
  source~ : String,
) -> FileImporterModel {
  if paths.is_empty() {
    {
      ..self,
      status: FileImporterStatus::Ready,
      last_event: "No files selected",
    }
  } else {
    {
      files: paths.map(path => ImportedFile::new(path~, source~)),
      status: FileImporterStatus::Ready,
      last_event: "Imported \{paths.length()} file(s) from " + source,
      availability_reason: "",
    }
  }
}

///|
fn FileImporterModel::import_summary(
  self : FileImporterModel,
  theme : @moui.Theme,
) -> @moui.View[FileImporterMsg] {
  let rows : Array[@moui.View[FileImporterMsg]] = [
    stat_card(
      "Selected files",
      self.files.length().to_string(),
      caption=self.status_label(),
      tone=@views.FeedbackTone::Info,
      theme~,
      width=340.0,
      height=116.0,
    ),
  ]
  if self.files.is_empty() {
    rows.push(
      text(
        "Selection list is empty",
        role=@views.TextRole::Caption,
        theme~,
        width=340.0,
        height=26.0,
      ),
    )
  } else {
    rows.push(
      description_list(
        self.files.map(file => description_item(file.source, file.path)),
        theme~,
        width=340.0,
        term_width=72.0,
      ),
    )
  }
  container(
    column(rows, spacing=theme.spacing_scale.sm, align=@views.CrossAlign::Start),
    width=372.0,
    height=292.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn FileImporterModel::platform_note(
  self : FileImporterModel,
  theme : @moui.Theme,
) -> @moui.View[FileImporterMsg] {
  ignore(self)
  banner(
    "Platform paths",
    "Web hosts normally expose file names while native hosts can expose paths.",
    tone=@views.FeedbackTone::Info,
    theme~,
    width=760.0,
  )
}

///|
fn FileImporterModel::status_label(self : FileImporterModel) -> String {
  match self.status {
    FileImporterStatus::Ready => "Ready"
    FileImporterStatus::Requesting => "Pending"
    FileImporterStatus::Unavailable(reason) => "Unavailable: " + reason
  }
}
