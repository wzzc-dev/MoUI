///|
/// 左栏「工程」页(M0-6a):导入的 MoonBit 工程列表 + 当前工程的包/文件树。
///
/// M0-6a 是**只读导航**:导入(复用 M0-5 消息链)、选中工程/文件、折叠包、
/// 会话内移除工程。文件删除走宿主协议扩展(M0-6b),文件内容查看接代码
/// 编辑面(M1)。
///
/// 数据全部来自 `active_project_of` / `model.projects` 的**派生视图**:
/// 包树由 `ScannedModule.packages` 投影,文件列表随扫描快照,不单独存储
/// ——重新导入即刷新,与「扫描是真源」的口径一致。

///|
/// 左栏「工程」页主体(ide_shell 的 body 分派)。
pub fn project_explorer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  // 导入按钮:空态是主入口,非空态是追加入口——永远可见
  rows.push(
    @views.container(
      @views.padding_xy(
        @views.row(
          [
            @views.icon(FolderOpen, size=14.0, color=ide_accent()),
            @views.text(
              text(t, "app.project.import"),
              theme=studio_theme(),
              width=(width - 60.0).max(60.0),
              height=18.0,
              align=TextStart,
            ).foreground(ide_accent()),
          ],
          spacing=6.0,
          align=Center,
        ),
        horizontal=12.0,
        vertical=6.0,
      ),
      width~,
      height=30.0,
      padding=0.0,
    ).on_tap(ImportProjectRequested),
  )
  // 工程列表(每个:模块名 + 根目录,选中高亮,尾部 × 移除)
  let mut index = 0
  for project in model.projects {
    let active = index == model.active_project
    rows.push(
      tree_row(
        project.module_name,
        project.root,
        0,
        active,
        true,
        active,
        Some(SetActiveProject(index)),
        Some(SetActiveProject(index)),
        width,
        trailing=Some(
          @views.container(
            @views.center(@views.icon(Trash, size=12.0, color=ide_text_faint())),
            width=18.0,
            height=16.0,
          ).on_tap(RemoveProject(index)),
        ),
        trailing_width=18.0,
      ),
    )
    index = index + 1
  }
  // 当前工程的包/文件树
  match active_project_of(model) {
    None =>
      if model.projects.length() == 0 {
        rows.push(
          @views.padding_xy(
            @views.text(
              text(t, "app.project.empty"),
              theme=studio_theme(),
              width=(width - 24.0).max(60.0),
              height=34.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            horizontal=12.0,
            vertical=8.0,
          ),
        )
      }
    Some(project) => {
      // 根行:模块名 + 入口概要
      let entries = project_entry_meta(project)
      rows.push(
        tree_row(
          project.module_name,
          entries,
          0,
          false,
          true,
          true,
          None,
          None,
          width,
        ),
      )
      for pkg in project.scanned.packages {
        let expanded = !project_package_collapsed(model, pkg.rel_path)
        rows.push(
          tree_row(
            project_package_label(pkg.rel_path),
            project_kind_label(pkg.kind, t),
            1,
            false,
            true,
            expanded,
            None,
            Some(ToggleProjectPackage(pkg.rel_path)),
            width,
          ),
        )
        if expanded {
          for name in pkg.files {
            let file_rel = if pkg.rel_path == "" {
              name
            } else {
              "\{pkg.rel_path}/\{name}"
            }
            rows.push(
              tree_row(
                name,
                "",
                2,
                model.selected_project_file is Some(_),
                false,
                false,
                Some(SelectProjectFile(file_rel)),
                None,
                width,
                trailing=Some(
                  @views.container(
                    @views.center(
                      @views.icon(Trash, size=12.0, color=ide_text_faint()),
                    ),
                    width=18.0,
                    height=16.0,
                  ).on_tap(RequestConfirm(CkDeleteProjectFile(file_rel))),
                ),
                trailing_width=18.0,
              ),
            )
          }
        }
      }
    }
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 包是否处于折叠态(默认全展开)。
fn project_package_collapsed(model : Model, rel : String) -> Bool {
  model.project_tree_collapsed.contains(rel)
}

///|
/// 包行标签:目录名(与 dir_name 同口径;根包显示 "(模块根)")。
fn project_package_label(rel : String) -> String {
  if rel == "" {
    "(模块根)"
  } else {
    let chars : Array[Char] = []
    for c in rel {
      chars.push(c)
    }
    let mut last = -1
    let mut i = 0
    for c in chars {
      if c == '/' {
        last = i
      }
      i = i + 1
    }
    rel[last + 1:].to_owned()
  }
}

///|
/// 包类别标签:入口(web / native)或普通包。
fn project_kind_label(
  kind : @project.PackageKind,
  t : @i18n.Translator,
) -> String {
  match kind {
    @project.PkWebEntry => text(t, "app.project.kind.web")
    @project.PkNativeEntry => text(t, "app.project.kind.native")
    @project.PkPlain => text(t, "app.project.kind.plain")
  }
}

///|
/// 根行的概要:web / native 入口与逻辑包数量。
fn project_entry_meta(project : ProjectRecord) -> String {
  let parts : Array[String] = []
  if project.scanned.web_entry != "" {
    parts.push("web:\{project.scanned.web_entry}")
  }
  if project.scanned.native_entry != "" {
    parts.push("native:\{project.scanned.native_entry}")
  }
  parts.push("program:\{project.scanned.program_packages.length()}")
  let mut out = ""
  let mut i = 0
  for part in parts {
    if i > 0 {
      out = out + " · "
    }
    out = out + part
    i = i + 1
  }
  out
}
