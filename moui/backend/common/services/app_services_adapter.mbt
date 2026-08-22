///|
fn[T] HostServicesAdapter::service_task(
  self : HostServicesAdapter,
  key~ : String,
  label~ : String,
  request~ : @backend_host.HostServiceRequest,
  decode~ : (@backend_host.HostServiceResponse) -> @app_services.ServiceTaskResult[
    T,
  ],
) -> @app_services.ServiceTask[T] {
  @app_services.ServiceTask::new(key~, label~, start=complete => {
    match self.dispatch(request) {
      Pending(id) => {
        let active = Ref(true)
        let (registered, cleanup) = self.on_completed_with_cleanup(id, completion => {
          if active.val {
            active.val = false
            complete(decode(completion.response))
          }
        })
        if !registered {
          active.val = false
          complete(
            @app_services.ServiceTaskResult::Failure(
              @app_services.ServiceError::new(
                code="completion-unavailable",
                message="host service completion could not be registered",
              ),
            ),
          )
          None
        } else {
          Some(() => {
            active.val = false
            match cleanup {
              Some(cancel) => cancel()
              None => ()
            }
          })
        }
      }
      response => {
        complete(decode(response))
        None
      }
    }
  })
}

///|
fn[T] host_failure(
  response : @backend_host.HostServiceResponse,
) -> @app_services.ServiceTaskResult[T] {
  match response {
    Unavailable(message) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::unavailable(message),
      )
    _ =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::new(
          code="unexpected-response",
          message="host service returned an unexpected response",
        ),
      )
  }
}

///|
fn[T] HostServicesAdapter::platform_task(
  self : HostServicesAdapter,
  operation~ : String,
  payload~ : String,
  decode~ : (@backend_host.PlatformChannelResponse) -> @app_services.ServiceTaskResult[
    T,
  ],
) -> @app_services.ServiceTask[T] {
  self.service_task(
    key="platform:" + operation,
    label="Platform " + operation,
    request=@backend_host.HostServiceRequest::PlatformChannel(
      @backend_host.PlatformChannelRequest::new(
        channel="moui.platform",
        operation~,
        payload~,
      ),
    ),
    decode=response => {
      match response {
        @backend_host.HostServiceResponse::PlatformChannel(platform_response) =>
          decode(platform_response)
        other => host_failure(other)
      }
    },
  )
}

///|
fn platform_unit_result(
  response : @backend_host.PlatformChannelResponse,
) -> @app_services.ServiceTaskResult[Unit] {
  match response {
    @backend_host.PlatformChannelResponse::Ok(_) =>
      @app_services.ServiceTaskResult::Success(())
    @backend_host.PlatformChannelResponse::Unavailable(message) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::unavailable(message),
      )
    @backend_host.PlatformChannelResponse::Error(message) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::new(code="platform-error", message~),
      )
  }
}

///|
fn platform_permission_result(
  response : @backend_host.PlatformChannelResponse,
) -> @app_services.ServiceTaskResult[@app_services.PermissionStatus] {
  match response {
    @backend_host.PlatformChannelResponse::Ok("granted") =>
      @app_services.ServiceTaskResult::Success(
        @app_services.PermissionStatus::Granted,
      )
    @backend_host.PlatformChannelResponse::Ok("denied") =>
      @app_services.ServiceTaskResult::Success(
        @app_services.PermissionStatus::Denied,
      )
    @backend_host.PlatformChannelResponse::Ok("restricted") =>
      @app_services.ServiceTaskResult::Success(
        @app_services.PermissionStatus::Restricted,
      )
    @backend_host.PlatformChannelResponse::Ok(_) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::new(
          code="invalid-platform-response",
          message="permission service returned an unknown status",
        ),
      )
    @backend_host.PlatformChannelResponse::Unavailable(message) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::unavailable(message),
      )
    @backend_host.PlatformChannelResponse::Error(message) =>
      @app_services.ServiceTaskResult::Failure(
        @app_services.ServiceError::new(code="platform-error", message~),
      )
  }
}

///|
fn HostServicesAdapter::app_platform_services(
  self : HostServicesAdapter,
  lifecycle? : @app_services.AppLifecycleSource? = None,
) -> @app_services.PlatformServices {
  @app_services.PlatformServices::new(
    notifications=@app_services.NotificationServices::new(
      notify=request => {
        self.platform_task(
          operation="notification.send",
          payload=@json.to_json(request).stringify(),
          decode=platform_unit_result,
        )
      },
      cancel=id => {
        self.platform_task(
          operation="notification.cancel",
          payload=@json.to_json(id).stringify(),
          decode=platform_unit_result,
        )
      },
    ),
    tray=@app_services.TrayServices::new(
      set=item => {
        self.platform_task(
          operation="tray.set",
          payload=@json.to_json(item).stringify(),
          decode=platform_unit_result,
        )
      },
      remove=id => {
        self.platform_task(
          operation="tray.remove",
          payload=@json.to_json(id).stringify(),
          decode=platform_unit_result,
        )
      },
    ),
    permissions=@app_services.PermissionServices::new(request=kind => {
      self.platform_task(
        operation="permission.request",
        payload=@json.to_json(kind).stringify(),
        decode=platform_permission_result,
      )
    }),
    sharing=@app_services.ShareServices::new(share=request => {
      self.platform_task(
        operation="share.open",
        payload=@json.to_json(request).stringify(),
        decode=platform_unit_result,
      )
    }),
    printing=@app_services.PrintServices::new(print=request => {
      self.platform_task(
        operation="print.document",
        payload=@json.to_json(request).stringify(),
        decode=platform_unit_result,
      )
    }),
    associations=@app_services.AssociationServices::new(
      register_protocol=registration => {
        self.platform_task(
          operation="association.protocol.register",
          payload=@json.to_json(registration).stringify(),
          decode=platform_unit_result,
        )
      },
      register_file=association => {
        self.platform_task(
          operation="association.file.register",
          payload=@json.to_json(association).stringify(),
          decode=platform_unit_result,
        )
      },
      unregister=value => {
        self.platform_task(
          operation="association.remove",
          payload=@json.to_json(value).stringify(),
          decode=platform_unit_result,
        )
      },
    ),
    window_state=@app_services.WindowStateServices::new(
      read=window_id => {
        self.platform_task(
          operation="window-state.read",
          payload=@json.to_json(window_id).stringify(),
          decode=response => {
            match response {
              @backend_host.PlatformChannelResponse::Ok(snapshot) =>
                @app_services.ServiceTaskResult::Success(Some(snapshot))
              @backend_host.PlatformChannelResponse::Unavailable(message) =>
                @app_services.ServiceTaskResult::Failure(
                  @app_services.ServiceError::unavailable(message),
                )
              @backend_host.PlatformChannelResponse::Error(message) =>
                @app_services.ServiceTaskResult::Failure(
                  @app_services.ServiceError::new(
                    code="platform-error",
                    message~,
                  ),
                )
            }
          },
        )
      },
      write=(window_id, snapshot) => {
        self.platform_task(
          operation="window-state.write",
          payload=@json.to_json({ "windowId": window_id, "snapshot": snapshot }).stringify(),
          decode=platform_unit_result,
        )
      },
      remove=window_id => {
        self.platform_task(
          operation="window-state.remove",
          payload=@json.to_json(window_id).stringify(),
          decode=platform_unit_result,
        )
      },
    ),
    lifecycle~,
  )
}

///|
fn HostServicesAdapter::app_file_services(
  self : HostServicesAdapter,
) -> @app_services.FileServices {
  @app_services.FileServices::new(
    open_file=options => {
      self.service_task(
        key="file:open",
        label="Open file",
        request=@backend_host.HostServiceRequest::FileDialog(
          @backend_host.HostFileDialogOptions::new(
            kind=@backend_host.HostFileDialogKind::OpenFile,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @app_services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) =>
              @app_services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    save_file=options => {
      self.service_task(
        key="file:save",
        label="Save file",
        request=@backend_host.HostServiceRequest::FileDialog(
          @backend_host.HostFileDialogOptions::new(
            kind=@backend_host.HostFileDialogKind::SaveFile,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @app_services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) =>
              @app_services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    pick_directory=options => {
      self.service_task(
        key="file:pick-directory",
        label="Pick directory",
        request=@backend_host.HostServiceRequest::FileDialog(
          @backend_host.HostFileDialogOptions::new(
            kind=@backend_host.HostFileDialogKind::PickDirectory,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @app_services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) =>
              @app_services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    read_text=path => {
      self.service_task(
        key="file:read-text:" + path,
        label="Read text file",
        request=@backend_host.HostServiceRequest::TextFile(
          @backend_host.HostTextFileRequest::ReadText(path),
        ),
        decode=response => {
          match response {
            TextFileContent(_path, text) =>
              @app_services.ServiceTaskResult::Success(text)
            other => host_failure(other)
          }
        },
      )
    },
    write_text=(path, text) => {
      self.service_task(
        key="file:write-text:" + path,
        label="Write text file",
        request=@backend_host.HostServiceRequest::TextFile(
          @backend_host.HostTextFileRequest::WriteText(path, text),
        ),
        decode=response => {
          match response {
            TextFileWritten(_) => @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    read_bytes=path => {
      self.service_task(
        key="file:read-bytes:" + path,
        label="Read binary file",
        request=@backend_host.HostServiceRequest::BinaryFile(
          @backend_host.HostBinaryFileRequest::ReadBytes(path),
        ),
        decode=response => {
          match response {
            BinaryFileContent(_path, bytes) =>
              @app_services.ServiceTaskResult::Success(bytes)
            other => host_failure(other)
          }
        },
      )
    },
    write_bytes=(path, bytes) => {
      self.service_task(
        key="file:write-bytes:" + path,
        label="Write binary file",
        request=@backend_host.HostServiceRequest::BinaryFile(
          @backend_host.HostBinaryFileRequest::WriteBytes(path, bytes),
        ),
        decode=response => {
          match response {
            BinaryFileWritten(_) => @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    list_directory=path => {
      self.service_task(
        key="file:list-directory:" + path,
        label="List directory",
        request=@backend_host.HostServiceRequest::ListDirectory(path),
        decode=response => {
          match response {
            DirectoryListing(_path, entries) =>
              @app_services.ServiceTaskResult::Success(
                entries.map(entry => @app_services.DirectoryEntry::{
                  name: entry.name(),
                  path: entry.path(),
                  is_directory: entry.is_directory(),
                }),
              )
            other => host_failure(other)
          }
        },
      )
    },
  )
}

///|
fn HostServicesAdapter::app_clipboard_services(
  self : HostServicesAdapter,
) -> @app_services.ClipboardServices {
  @app_services.ClipboardServices::new(
    read_text=() => {
      self.service_task(
        key="clipboard:read-text",
        label="Read clipboard text",
        request=@backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadText,
        ),
        decode=response => {
          match response {
            ClipboardText(text) =>
              @app_services.ServiceTaskResult::Success(text)
            other => host_failure(other)
          }
        },
      )
    },
    write_text=text => {
      self.service_task(
        key="clipboard:write-text",
        label="Write clipboard text",
        request=@backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::WriteText(text),
        ),
        decode=response => {
          match response {
            ClipboardWritten => @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    read_image=() => {
      self.service_task(
        key="clipboard:read-image",
        label="Read clipboard image",
        request=@backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadImage,
        ),
        decode=response => {
          match response {
            ClipboardImage(bytes) =>
              @app_services.ServiceTaskResult::Success(@app_services.ClipboardImage::{
                mime_type: "application/octet-stream",
                bytes,
              })
            other => host_failure(other)
          }
        },
      )
    },
    write_image=image => {
      self.service_task(
        key="clipboard:write-image",
        label="Write clipboard image",
        request=@backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::WriteImage(
            image.mime_type,
            image.bytes,
          ),
        ),
        decode=response => {
          match response {
            ClipboardWritten => @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
  )
}

///|
fn app_menu_to_host(
  menus : Array[@app_services.ApplicationMenu],
) -> Array[@backend_host.HostApplicationMenu] {
  let next_action_id = Ref(1)
  menus.map(menu => {
    @backend_host.HostApplicationMenu::new(
      title=menu.title,
      placement=match menu.placement {
        @app_services.ApplicationMenuPlacement::MenuBar =>
          @backend_host.HostApplicationMenuPlacement::MenuBar
        @app_services.ApplicationMenuPlacement::ApplicationMenu =>
          @backend_host.HostApplicationMenuPlacement::ApplicationMenu
      },
      items=menu.items.map(item => {
        match item {
          @app_services.ApplicationMenuItem::MenuSeparator =>
            @backend_host.HostApplicationMenuItem::separator()
          @app_services.ApplicationMenuItem::MenuCommand(command) => {
            let action_id = next_action_id.val
            next_action_id.val = action_id + 1
            @backend_host.HostApplicationMenuItem::new(
              title=command.display_label(),
              action_id~,
              enabled=command.enabled,
            )
          }
        }
      }),
    )
  })
}

///|
fn HostServicesAdapter::app_menu_services(
  self : HostServicesAdapter,
) -> @app_services.MenuServices {
  @app_services.MenuServices::new(
    show_context=commands => {
      self.service_task(
        key="menu:context",
        label="Show context menu",
        request=@backend_host.HostServiceRequest::ShowMenu(commands),
        decode=response => {
          match response {
            MenuAction(command) =>
              @app_services.ServiceTaskResult::Success(command)
            MenuCommand(intent) =>
              match
                commands.iter().find_first(command => command.intent == intent) {
                Some(command) =>
                  @app_services.ServiceTaskResult::Success(command)
                None => host_failure(response)
              }
            other => host_failure(other)
          }
        },
      )
    },
    install_application=menus => {
      self.service_task(
        key="menu:application",
        label="Install application menu",
        request=@backend_host.HostServiceRequest::SetApplicationMenu(
          app_menu_to_host(menus),
        ),
        decode=response => {
          match response {
            ApplicationMenuInstalled =>
              @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
  )
}

///|
fn HostServicesAdapter::as_app_services(
  self : HostServicesAdapter,
  lifecycle? : @app_services.AppLifecycleSource? = None,
) -> @app_services.AppServices {
  @app_services.AppServices::new(
    files=self.app_file_services(),
    clipboard=self.app_clipboard_services(),
    urls=@app_services.UrlServices::new(open=url => {
      self.service_task(
        key="url:open",
        label="Open URL",
        request=@backend_host.HostServiceRequest::OpenUrl(url),
        decode=response => {
          match response {
            UrlOpened => @app_services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    }),
    settings=@app_services.SettingsServices::new(
      read=key => {
        self.service_task(
          key="settings:read:" + key,
          label="Read setting",
          request=@backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Read(key),
          ),
          decode=response => {
            match response {
              SettingValue(value) =>
                @app_services.ServiceTaskResult::Success(value)
              other => host_failure(other)
            }
          },
        )
      },
      write=(key, value) => {
        self.service_task(
          key="settings:write:" + key,
          label="Write setting",
          request=@backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Write(key, value),
          ),
          decode=response => {
            match response {
              SettingWritten => @app_services.ServiceTaskResult::Success(())
              other => host_failure(other)
            }
          },
        )
      },
      remove=key => {
        self.service_task(
          key="settings:remove:" + key,
          label="Remove setting",
          request=@backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Remove(key),
          ),
          decode=response => {
            match response {
              SettingRemoved => @app_services.ServiceTaskResult::Success(())
              other => host_failure(other)
            }
          },
        )
      },
    ),
    appearance=@app_services.AppearanceServices::new(system_color_scheme=() => {
      self.service_task(
        key="appearance:system-color-scheme",
        label="Read system color scheme",
        request=@backend_host.HostServiceRequest::QuerySystemTheme,
        decode=response => {
          match response {
            SystemTheme(scheme) =>
              @app_services.ServiceTaskResult::Success(scheme)
            other => host_failure(other)
          }
        },
      )
    }),
    menus=self.app_menu_services(),
    platform=self.app_platform_services(lifecycle~),
  )
}

///|
fn HostServicesAdapter::app_environment(
  self : HostServicesAdapter,
  timer? : @app_services.TimerSource? = None,
  routes? : @app_services.RouteSource? = None,
  lifecycle? : @app_services.AppLifecycleSource? = None,
) -> @app_services.AppEnvironment {
  @app_services.AppEnvironment::new(
    services=self.as_app_services(lifecycle~),
    timer~,
    routes~,
  )
}

///|
/// Adapt the host wire protocol to the typed app-facing services boundary.
/// Request ids and completion queues remain private to this package.
pub fn app_services(
  bridge~ : @backend_host.HostServiceBridge,
  async_queue? : ServiceAsyncQueue? = None,
  lifecycle? : @app_services.AppLifecycleSource? = None,
) -> @app_services.AppServices {
  HostServicesAdapter::new(bridge~, async_queue~).as_app_services(lifecycle~)
}

///|
/// Build the app-facing environment supplied to a Program closure.
pub fn app_environment(
  bridge~ : @backend_host.HostServiceBridge,
  async_queue? : ServiceAsyncQueue? = None,
  timer? : @app_services.TimerSource? = None,
  routes? : @app_services.RouteSource? = None,
  lifecycle? : @app_services.AppLifecycleSource? = None,
) -> @app_services.AppEnvironment {
  HostServicesAdapter::new(bridge~, async_queue~).app_environment(
    timer~,
    routes~,
    lifecycle~,
  )
}
