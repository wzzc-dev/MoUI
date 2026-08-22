///|
/// Deterministic in-memory services for reducer and Program tests.
pub struct FakeAppServices {
  services_value : AppServices
  text_files : Map[String, String]
  settings_values : Map[String, String]
  system_color_scheme_value : Ref[@core.ColorScheme]
  clipboard_text_value : Ref[String]
  open_file_value : Ref[String?]
  save_file_value : Ref[String?]
  directory_value : Ref[String?]
  notifications : Map[String, NotificationRequest]
  tray_items : Map[String, TrayItem]
  permission_values : Map[PermissionKind, PermissionStatus]
  share_requests : Array[ShareRequest]
  print_requests : Array[PrintRequest]
  protocol_associations : Map[String, ProtocolRegistration]
  file_associations : Map[String, FileAssociation]
  window_states : Map[String, String]
  lifecycle_source : AppLifecycleSource
  calls_value : Array[String]
}

///|
pub fn FakeAppServices::new() -> FakeAppServices {
  let text_files : Map[String, String] = Map([])
  let settings_values : Map[String, String] = Map([])
  let system_color_scheme_value = Ref(@core.ColorScheme::Light)
  let clipboard_text_value = Ref("")
  let open_file_value : Ref[String?] = Ref(None)
  let save_file_value : Ref[String?] = Ref(None)
  let directory_value : Ref[String?] = Ref(None)
  let notifications : Map[String, NotificationRequest] = Map([])
  let tray_items : Map[String, TrayItem] = Map([])
  let permission_values : Map[PermissionKind, PermissionStatus] = Map([])
  let share_requests : Array[ShareRequest] = []
  let print_requests : Array[PrintRequest] = []
  let protocol_associations : Map[String, ProtocolRegistration] = Map([])
  let file_associations : Map[String, FileAssociation] = Map([])
  let window_states : Map[String, String] = Map([])
  let lifecycle_source = AppLifecycleSource::new()
  let calls_value : Array[String] = []
  let files = FileServices::new(
    open_file=_options => {
      calls_value.push("file:open")
      match open_file_value.val {
        Some(path) => ServiceTask::succeed(key="fake:file:open", value=path)
        None => ServiceTask::cancelled(key="fake:file:open")
      }
    },
    save_file=_options => {
      calls_value.push("file:save")
      match save_file_value.val {
        Some(path) => ServiceTask::succeed(key="fake:file:save", value=path)
        None => ServiceTask::cancelled(key="fake:file:save")
      }
    },
    pick_directory=_options => {
      calls_value.push("file:pick-directory")
      match directory_value.val {
        Some(path) =>
          ServiceTask::succeed(key="fake:file:pick-directory", value=path)
        None => ServiceTask::cancelled(key="fake:file:pick-directory")
      }
    },
    read_text=path => {
      calls_value.push("file:read-text:" + path)
      match text_files.get(path) {
        Some(text) =>
          ServiceTask::succeed(key="fake:file:read-text:" + path, value=text)
        None =>
          ServiceTask::fail(
            key="fake:file:read-text:" + path,
            error=ServiceError::new(code="not-found", message=path),
          )
      }
    },
    write_text=(path, text) => {
      calls_value.push("file:write-text:" + path)
      text_files[path] = text
      ServiceTask::succeed(key="fake:file:write-text:" + path, value=())
    },
    list_directory=path => {
      calls_value.push("file:list-directory:" + path)
      ServiceTask::succeed(key="fake:file:list-directory:" + path, value=[])
    },
  )
  let clipboard = ClipboardServices::new(
    read_text=() => {
      calls_value.push("clipboard:read-text")
      ServiceTask::succeed(
        key="fake:clipboard:read-text",
        value=clipboard_text_value.val,
      )
    },
    write_text=text => {
      calls_value.push("clipboard:write-text")
      clipboard_text_value.val = text
      ServiceTask::succeed(key="fake:clipboard:write-text", value=())
    },
  )
  let urls = UrlServices::new(open=url => {
    calls_value.push("url:open:" + url)
    ServiceTask::succeed(key="fake:url:open", value=())
  })
  let settings = SettingsServices::new(
    read=key => {
      calls_value.push("settings:read:" + key)
      ServiceTask::succeed(
        key="fake:settings:read:" + key,
        value=settings_values.get(key),
      )
    },
    write=(key, value) => {
      calls_value.push("settings:write:" + key)
      settings_values[key] = value
      ServiceTask::succeed(key="fake:settings:write:" + key, value=())
    },
    remove=key => {
      calls_value.push("settings:remove:" + key)
      ignore(settings_values.remove(key))
      ServiceTask::succeed(key="fake:settings:remove:" + key, value=())
    },
  )
  let appearance = AppearanceServices::new(system_color_scheme=() => {
    calls_value.push("appearance:system-color-scheme")
    ServiceTask::succeed(
      key="fake:appearance:system-color-scheme",
      value=system_color_scheme_value.val,
    )
  })
  let menus = MenuServices::new(
    show_context=commands => {
      calls_value.push("menu:context")
      match commands {
        [command, ..] =>
          ServiceTask::succeed(key="fake:menu:context", value=command)
        [] => ServiceTask::cancelled(key="fake:menu:context")
      }
    },
    install_application=_menus => {
      calls_value.push("menu:application")
      ServiceTask::succeed(key="fake:menu:application", value=())
    },
  )
  let platform = PlatformServices::new(
    notifications=NotificationServices::new(
      notify=request => {
        calls_value.push("notification:send:" + request.id)
        notifications[request.id] = request
        ServiceTask::succeed(key="fake:notification:send", value=())
      },
      cancel=id => {
        calls_value.push("notification:cancel:" + id)
        ignore(notifications.remove(id))
        ServiceTask::succeed(key="fake:notification:cancel", value=())
      },
    ),
    tray=TrayServices::new(
      set=item => {
        calls_value.push("tray:set:" + item.id)
        tray_items[item.id] = item
        ServiceTask::succeed(key="fake:tray:set", value=())
      },
      remove=id => {
        calls_value.push("tray:remove:" + id)
        ignore(tray_items.remove(id))
        ServiceTask::succeed(key="fake:tray:remove", value=())
      },
    ),
    permissions=PermissionServices::new(request=kind => {
      calls_value.push("permission:request")
      ServiceTask::succeed(
        key="fake:permission:request",
        value=permission_values.get(kind).unwrap_or(PermissionStatus::Denied),
      )
    }),
    sharing=ShareServices::new(share=request => {
      calls_value.push("share:open")
      share_requests.push(request)
      ServiceTask::succeed(key="fake:share:open", value=())
    }),
    printing=PrintServices::new(print=request => {
      calls_value.push("print:document")
      print_requests.push(request)
      ServiceTask::succeed(key="fake:print:document", value=())
    }),
    associations=AssociationServices::new(
      register_protocol=registration => {
        calls_value.push("association:protocol:" + registration.scheme)
        protocol_associations[registration.scheme] = registration
        ServiceTask::succeed(key="fake:association:protocol", value=())
      },
      register_file=association => {
        calls_value.push("association:file:" + association.extension)
        file_associations[association.extension] = association
        ServiceTask::succeed(key="fake:association:file", value=())
      },
      unregister=value => {
        calls_value.push("association:remove:" + value)
        ignore(protocol_associations.remove(value))
        ignore(file_associations.remove(value))
        ServiceTask::succeed(key="fake:association:remove", value=())
      },
    ),
    window_state=WindowStateServices::new(
      read=window_id => {
        calls_value.push("window-state:read:" + window_id)
        ServiceTask::succeed(
          key="fake:window-state:read",
          value=window_states.get(window_id),
        )
      },
      write=(window_id, snapshot) => {
        calls_value.push("window-state:write:" + window_id)
        window_states[window_id] = snapshot
        ServiceTask::succeed(key="fake:window-state:write", value=())
      },
      remove=window_id => {
        calls_value.push("window-state:remove:" + window_id)
        ignore(window_states.remove(window_id))
        ServiceTask::succeed(key="fake:window-state:remove", value=())
      },
    ),
    lifecycle=Some(lifecycle_source),
  )
  {
    services_value: AppServices::new(
      files~,
      clipboard~,
      urls~,
      settings~,
      appearance~,
      menus~,
      platform~,
    ),
    text_files,
    settings_values,
    system_color_scheme_value,
    clipboard_text_value,
    open_file_value,
    save_file_value,
    directory_value,
    notifications,
    tray_items,
    permission_values,
    share_requests,
    print_requests,
    protocol_associations,
    file_associations,
    window_states,
    lifecycle_source,
    calls_value,
  }
}

///|
pub fn FakeAppServices::set_permission_status(
  self : FakeAppServices,
  kind : PermissionKind,
  status : PermissionStatus,
) -> Unit {
  self.permission_values[kind] = status
}

///|
pub fn FakeAppServices::publish_lifecycle(
  self : FakeAppServices,
  event : AppLifecycleEvent,
) -> Int {
  self.calls_value.push("lifecycle:publish")
  self.lifecycle_source.publish(event)
}

///|
pub fn FakeAppServices::notification(
  self : FakeAppServices,
  id : String,
) -> NotificationRequest? {
  self.notifications.get(id)
}

///|
pub fn FakeAppServices::tray_item(
  self : FakeAppServices,
  id : String,
) -> TrayItem? {
  self.tray_items.get(id)
}

///|
pub fn FakeAppServices::share_requests(
  self : FakeAppServices,
) -> Array[ShareRequest] {
  self.share_requests.copy()
}

///|
pub fn FakeAppServices::print_requests(
  self : FakeAppServices,
) -> Array[PrintRequest] {
  self.print_requests.copy()
}

///|
pub fn FakeAppServices::set_system_color_scheme(
  self : FakeAppServices,
  scheme : @core.ColorScheme,
) -> Unit {
  self.system_color_scheme_value.val = scheme
}

///|
pub fn FakeAppServices::services(self : FakeAppServices) -> AppServices {
  self.services_value
}

///|
pub fn FakeAppServices::set_text_file(
  self : FakeAppServices,
  path : String,
  text : String,
) -> Unit {
  self.text_files[path] = text
}

///|
pub fn FakeAppServices::set_open_file_selection(
  self : FakeAppServices,
  path : String?,
) -> Unit {
  self.open_file_value.val = path
}

///|
pub fn FakeAppServices::set_save_file_selection(
  self : FakeAppServices,
  path : String?,
) -> Unit {
  self.save_file_value.val = path
}

///|
pub fn FakeAppServices::set_directory_selection(
  self : FakeAppServices,
  path : String?,
) -> Unit {
  self.directory_value.val = path
}

///|
pub fn FakeAppServices::clipboard_text(self : FakeAppServices) -> String {
  self.clipboard_text_value.val
}

///|
pub fn FakeAppServices::calls(self : FakeAppServices) -> Array[String] {
  self.calls_value.copy()
}
