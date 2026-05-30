# Non-Render Component Cookbook

This cookbook collects the app-level patterns that can be built without touching
`moui/render/*`, adding draw commands, or depending on a concrete renderer.
The common rule is: keep state in the app model, use `views` constructors for
composition, use `core` helpers for runtime-neutral contracts, and cross into
`backend/host` only for services that truly belong to the platform.

## Forms

Use `form`, `form_section`, and `form_field` for layout and status surfaces.
Keep field values and validation display controlled by the app model, then use
`@core.FormFieldState`, `required_field`, and `FormController` when multiple
fields need shared validation or first-invalid-field routing.

```moonbit nocheck
using @views {button, form, form_field, form_section, text_field}

enum Msg { NameChanged(String); Submit }

fn profile_form(name : String, error : String?) -> @core.View[Msg] {
  form([
    form_section(
      "Profile",
      [
        form_field(
          "Name",
          text_field(name, on_input=NameChanged, placeholder="Display name"),
          required=true,
          error~,
          helper="Shown in shared workspaces.",
        ),
        button("Save", on_click=Submit),
      ],
    ),
  ])
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/settings/app --target native
```

## Data Tables

Use `table` and `table_column` for display only. Filtering, sorting,
pagination, row selection, and loading/error/empty states should live in the app
model so the table stays renderer-neutral and predictable.

```moonbit nocheck
using @views {error_state, loading_state, table, table_column}

fn project_table(
  rows : Array[Project],
  loading : Bool,
  error : String?,
) -> @core.View[Msg] {
  if loading {
    loading_state("Loading projects")
  } else if error is Some(message) {
    error_state("Unable to load", message=message)
  } else {
    table(
      [
        table_column(id="name", label="Name", width=180.0),
        table_column(id="status", label="Status", width=120.0),
      ],
      rows.map(row => [row.name, row.status]),
      empty=Some(@views.empty_state("No projects", "No projects match the current filter.")),
    )
  }
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test examples/data_table/app --target native
```

## Navigation Shells

Use `sidebar`, `breadcrumb`, `split_view`, `master_detail`, `wizard`, and
`router_stack` to describe navigation structure. Keep the active route in the
app model or in `@core.RouterState`; use `RouteLocation` query params when a
route needs stable restoration.

```moonbit nocheck
using @views {master_detail, sidebar}

enum Msg { SelectSection(String) }

fn settings_shell(current : String, detail : @core.View[Msg]) -> @core.View[Msg] {
  master_detail(
    master=sidebar(
      "Settings",
      [
        @views.SidebarItem::new(id="account", label="Account", message=SelectSection("account")),
        @views.SidebarItem::new(id="appearance", label="Appearance", message=SelectSection("appearance")),
      ],
      selected=current,
    ),
    detail~,
  )
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/showcase/app --target native
```

## Menus And Commands

Use `@core.ActionCommand` as the source of truth for command metadata. Render it
with `command_palette`, `command_menu`, or `menu_bar`; dispatch shortcuts with
`ActionCommandMap`. Disabled commands should stay visible but should not update
the model.

```moonbit nocheck
using @views {command_palette}

enum Msg { Dispatch(@core.CommandIntent) }

fn palette(commands : Array[@core.ActionCommand]) -> @core.View[Msg] {
  command_palette(
    commands,
    query="",
    on_select=Dispatch,
  )
}
```

View-level menus are overlay compositions. Native context menus and focused text
clipboard commands should go through `HostServiceBridge` and `HostAppServices`
instead of `views`.

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/command_palette/app --target native
```

## Host Services

Use `@host.HostAppServices` for clipboard, file dialogs, URL opening, system
theme, and native context menus. Effect-capable apps should return
`Effect::dispatch` from `Program::new` updates, call the service from the effect
runner, and dispatch a typed completion message for `Unavailable`, synchronous
responses, and pending async completions. `views` should only emit messages such
as `BrowseRequested` or `RecordFileDrop(paths)`. When a host-service workflow is
implemented as a child feature, lift the child view with `View::map` and lift
the child effect with `Effect::map` in the parent update so the parent still owns
the top-level message loop.

```moonbit nocheck
fn request_browse(
  services : @host.HostAppServices,
) -> @core.Effect[ImportMsg] {
  @core.Effect::dispatch(dispatch => {
    let response = services.open_file(title="Import files", filters=["csv", "json"])
    dispatch(HostCompleted(file_dialog_completion(response)))
  })
}
```

Web hosts may expose file names or browser handles while native hosts can expose
filesystem paths. Treat returned strings as host-provided import handles unless
the active platform contract says otherwise.

Recommended checks:

```sh
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/file_importer/app --target native
```

## Virtual Lists

Use `virtual_list` and `sectioned_list` when app data is larger than the current
viewport. The helpers compute a visible window plus overscan and still return a
normal `View[Msg]`; renderer behavior does not change. Use `scroll_to_index` to
calculate a controlled offset, then store that offset in the app model.

```moonbit nocheck
using @views {scroll_view, virtual_list}

fn activity_list(
  rows : Array[Activity],
  scroll : @core.ScrollState,
) -> @core.View[Msg] {
  scroll_view(
    virtual_list(
      rows,
      key=row => row.id,
      row=row => @views.text(row.title, height=28.0),
      state=scroll,
      item_height=32.0,
      viewport_height=360.0,
    ),
    state=Some(scroll),
    on_scroll=ActivityScrolled,
  )
}
```

Recommended checks:

```sh
moon test moui/views --target native
sh scripts/conformance-check.sh --layout
```

## Keeping The Layers Honest

- Put reusable state contracts in `core`.
- Put renderer-neutral view constructors in `views`.
- Put platform requests in `backend/host` and active platform backends.
- Demonstrate user-facing workflows in Showcase or a shared `examples/*/app`
  package.
- Update `docs/view-catalog.md` when a public constructor or its semantics
  changes.
- Run `moon info` after public API changes and keep generated interface diffs
  with the implementing commit.
