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
  surface,
  text,
}

///|
pub struct FileImporterApp {
  unit : Unit
}

///|
pub(all) enum FileImporterStatus {
  Ready
  Pending(@host.HostServiceRequestId)
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
pub(all) enum FileImporterMsg {
  FilesDropped(Array[String])
  BrowseRequested
  HostCompleted(@host.HostCompletedServiceResponse)
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
  self.update_with_services(message, @host.HostAppServices::unavailable())
}

///|
pub fn FileImporterModel::update_with_services(
  self : FileImporterModel,
  message : FileImporterMsg,
  services : @host.HostAppServices,
) -> FileImporterModel {
  match message {
    FilesDropped(paths) => self.with_paths(paths, source="Drop")
    BrowseRequested => self.request_file_dialog(services)
    HostCompleted(completion) => self.apply_host_completion(completion)
    ClearSelection => { ..self, files: [], last_event: "Selection cleared" }
  }
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
    FileImporterStatus::Pending(_) => @views.FileImportAvailability::Pending
    FileImporterStatus::Unavailable(reason) =>
      @views.FileImportAvailability::Unavailable(reason)
  }
}

///|
pub fn view(model : FileImporterModel) -> @core.View[FileImporterMsg] {
  model.view()
}

///|
pub fn FileImporterModel::view(
  self : FileImporterModel,
) -> @core.View[FileImporterMsg] {
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
  surface(
    shell,
    width=820.0,
    height=560.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn FileImporterApp::runtime(
  self : FileImporterApp,
  width? : Double = 860.0,
  height? : Double = 620.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime(width~, height~)
}

///|
pub fn runtime(
  width? : Double = 860.0,
  height? : Double = 620.0,
) -> @core.AppRuntime {
  FileImporterModel::new().runtime(width~, height~)
}

///|
pub fn FileImporterModel::runtime(
  self : FileImporterModel,
  width? : Double = 860.0,
  height? : Double = 620.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple(init=self, update~, view~),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn FileImporterModel::request_file_dialog(
  self : FileImporterModel,
  services : @host.HostAppServices,
) -> FileImporterModel {
  match
    services.open_file(title="Import files", filters=["csv", "json", "txt"]) {
    @host.HostServiceResponse::Pending(id) =>
      {
        ..self,
        status: FileImporterStatus::Pending(id),
        last_event: "Waiting for file picker",
        availability_reason: "",
      }
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.with_paths(paths, source="Dialog")
    @host.HostServiceResponse::Unavailable(reason) =>
      {
        ..self,
        status: FileImporterStatus::Unavailable(reason),
        last_event: "File dialog unavailable",
        availability_reason: reason,
      }
    _ =>
      {
        ..self,
        status: FileImporterStatus::Unavailable(
          "unexpected file dialog response",
        ),
        last_event: "File dialog unavailable",
        availability_reason: "unexpected file dialog response",
      }
  }
}

///|
fn FileImporterModel::apply_host_completion(
  self : FileImporterModel,
  completion : @host.HostCompletedServiceResponse,
) -> FileImporterModel {
  match completion.response {
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.with_paths(paths, source="Dialog")
    @host.HostServiceResponse::Unavailable(reason) =>
      {
        ..self,
        status: FileImporterStatus::Unavailable(reason),
        last_event: "File dialog unavailable",
        availability_reason: reason,
      }
    _ => self
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
  theme : @core.Theme,
) -> @core.View[FileImporterMsg] {
  let rows : Array[@core.View[FileImporterMsg]] = [
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
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=@views.CrossAlign::Start),
    width=372.0,
    height=292.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn FileImporterModel::platform_note(
  self : FileImporterModel,
  theme : @core.Theme,
) -> @core.View[FileImporterMsg] {
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
    FileImporterStatus::Pending(_) => "Pending"
    FileImporterStatus::Unavailable(reason) => "Unavailable: " + reason
  }
}
