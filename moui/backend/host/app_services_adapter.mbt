///|
fn[T] HostServicesAdapter::service_task(
  self : HostServicesAdapter,
  key~ : String,
  label~ : String,
  request~ : HostServiceRequest,
  decode~ : (HostServiceResponse) -> @services.ServiceTaskResult[T],
) -> @services.ServiceTask[T] {
  @services.ServiceTask::new(key~, label~, start=complete => {
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
            @services.ServiceTaskResult::Failure(
              @services.ServiceError::new(
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
  response : HostServiceResponse,
) -> @services.ServiceTaskResult[T] {
  match response {
    Unavailable(message) =>
      @services.ServiceTaskResult::Failure(
        @services.ServiceError::unavailable(message),
      )
    _ =>
      @services.ServiceTaskResult::Failure(
        @services.ServiceError::new(
          code="unexpected-response",
          message="host service returned an unexpected response",
        ),
      )
  }
}

///|
fn HostServicesAdapter::app_file_services(
  self : HostServicesAdapter,
) -> @services.FileServices {
  @services.FileServices::new(
    open_file=options => {
      self.service_task(
        key="file:open",
        label="Open file",
        request=HostServiceRequest::FileDialog(
          HostFileDialogOptions::new(
            kind=HostFileDialogKind::OpenFile,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) => @services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    save_file=options => {
      self.service_task(
        key="file:save",
        label="Save file",
        request=HostServiceRequest::FileDialog(
          HostFileDialogOptions::new(
            kind=HostFileDialogKind::SaveFile,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) => @services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    pick_directory=options => {
      self.service_task(
        key="file:pick-directory",
        label="Pick directory",
        request=HostServiceRequest::FileDialog(
          HostFileDialogOptions::new(
            kind=HostFileDialogKind::PickDirectory,
            title=options.title,
            filters=options.filters,
            default_name=options.default_name,
          ),
        ),
        decode=response => {
          match response {
            FileDialogSelection([path, ..]) =>
              @services.ServiceTaskResult::Success(path)
            FileDialogSelection([]) => @services.ServiceTaskResult::Cancelled
            other => host_failure(other)
          }
        },
      )
    },
    read_text=path => {
      self.service_task(
        key="file:read-text:" + path,
        label="Read text file",
        request=HostServiceRequest::TextFile(
          HostTextFileRequest::ReadText(path),
        ),
        decode=response => {
          match response {
            TextFileContent(_path, text) =>
              @services.ServiceTaskResult::Success(text)
            other => host_failure(other)
          }
        },
      )
    },
    write_text=(path, text) => {
      self.service_task(
        key="file:write-text:" + path,
        label="Write text file",
        request=HostServiceRequest::TextFile(
          HostTextFileRequest::WriteText(path, text),
        ),
        decode=response => {
          match response {
            TextFileWritten(_) => @services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    read_bytes=path => {
      self.service_task(
        key="file:read-bytes:" + path,
        label="Read binary file",
        request=HostServiceRequest::BinaryFile(
          HostBinaryFileRequest::ReadBytes(path),
        ),
        decode=response => {
          match response {
            BinaryFileContent(_path, bytes) =>
              @services.ServiceTaskResult::Success(bytes)
            other => host_failure(other)
          }
        },
      )
    },
    write_bytes=(path, bytes) => {
      self.service_task(
        key="file:write-bytes:" + path,
        label="Write binary file",
        request=HostServiceRequest::BinaryFile(
          HostBinaryFileRequest::WriteBytes(path, bytes),
        ),
        decode=response => {
          match response {
            BinaryFileWritten(_) => @services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    list_directory=path => {
      self.service_task(
        key="file:list-directory:" + path,
        label="List directory",
        request=HostServiceRequest::ListDirectory(path),
        decode=response => {
          match response {
            DirectoryListing(_path, entries) =>
              @services.ServiceTaskResult::Success(
                entries.map(entry => @services.DirectoryEntry::{
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
) -> @services.ClipboardServices {
  @services.ClipboardServices::new(
    read_text=() => {
      self.service_task(
        key="clipboard:read-text",
        label="Read clipboard text",
        request=HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
        decode=response => {
          match response {
            ClipboardText(text) => @services.ServiceTaskResult::Success(text)
            other => host_failure(other)
          }
        },
      )
    },
    write_text=text => {
      self.service_task(
        key="clipboard:write-text",
        label="Write clipboard text",
        request=HostServiceRequest::Clipboard(
          HostClipboardRequest::WriteText(text),
        ),
        decode=response => {
          match response {
            ClipboardWritten => @services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
    read_image=() => {
      self.service_task(
        key="clipboard:read-image",
        label="Read clipboard image",
        request=HostServiceRequest::Clipboard(HostClipboardRequest::ReadImage),
        decode=response => {
          match response {
            ClipboardImage(bytes) =>
              @services.ServiceTaskResult::Success(@services.ClipboardImage::{
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
        request=HostServiceRequest::Clipboard(
          HostClipboardRequest::WriteImage(image.mime_type, image.bytes),
        ),
        decode=response => {
          match response {
            ClipboardWritten => @services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    },
  )
}

///|
fn app_menu_to_host(
  menus : Array[@services.ApplicationMenu],
) -> Array[HostApplicationMenu] {
  let next_action_id = Ref(1)
  menus.map(menu => {
    HostApplicationMenu::new(
      title=menu.title,
      items=menu.items.map(item => {
        match item {
          @services.ApplicationMenuItem::MenuSeparator =>
            HostApplicationMenuItem::separator()
          @services.ApplicationMenuItem::MenuCommand(command) => {
            let action_id = next_action_id.val
            next_action_id.val = action_id + 1
            HostApplicationMenuItem::new(
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
) -> @services.MenuServices {
  @services.MenuServices::new(
    show_context=commands => {
      self.service_task(
        key="menu:context",
        label="Show context menu",
        request=HostServiceRequest::ShowMenu(commands),
        decode=response => {
          match response {
            MenuAction(command) => @services.ServiceTaskResult::Success(command)
            MenuCommand(intent) =>
              match
                commands.iter().find_first(command => command.intent == intent) {
                Some(command) => @services.ServiceTaskResult::Success(command)
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
        request=HostServiceRequest::SetApplicationMenu(app_menu_to_host(menus)),
        decode=response => {
          match response {
            ApplicationMenuInstalled => @services.ServiceTaskResult::Success(())
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
) -> @services.AppServices {
  @services.AppServices::new(
    files=self.app_file_services(),
    clipboard=self.app_clipboard_services(),
    urls=@services.UrlServices::new(open=url => {
      self.service_task(
        key="url:open",
        label="Open URL",
        request=HostServiceRequest::OpenUrl(url),
        decode=response => {
          match response {
            UrlOpened => @services.ServiceTaskResult::Success(())
            other => host_failure(other)
          }
        },
      )
    }),
    settings=@services.SettingsServices::new(
      read=key => {
        self.service_task(
          key="settings:read:" + key,
          label="Read setting",
          request=HostServiceRequest::Settings(HostSettingsRequest::Read(key)),
          decode=response => {
            match response {
              SettingValue(value) => @services.ServiceTaskResult::Success(value)
              other => host_failure(other)
            }
          },
        )
      },
      write=(key, value) => {
        self.service_task(
          key="settings:write:" + key,
          label="Write setting",
          request=HostServiceRequest::Settings(
            HostSettingsRequest::Write(key, value),
          ),
          decode=response => {
            match response {
              SettingWritten => @services.ServiceTaskResult::Success(())
              other => host_failure(other)
            }
          },
        )
      },
      remove=key => {
        self.service_task(
          key="settings:remove:" + key,
          label="Remove setting",
          request=HostServiceRequest::Settings(HostSettingsRequest::Remove(key)),
          decode=response => {
            match response {
              SettingRemoved => @services.ServiceTaskResult::Success(())
              other => host_failure(other)
            }
          },
        )
      },
    ),
    appearance=@services.AppearanceServices::new(system_color_scheme=() => {
      self.service_task(
        key="appearance:system-color-scheme",
        label="Read system color scheme",
        request=HostServiceRequest::QuerySystemTheme,
        decode=response => {
          match response {
            SystemTheme(scheme) => @services.ServiceTaskResult::Success(scheme)
            other => host_failure(other)
          }
        },
      )
    }),
    menus=self.app_menu_services(),
  )
}

///|
fn HostServicesAdapter::app_environment(
  self : HostServicesAdapter,
  timer? : @services.TimerSource? = None,
  routes? : @services.RouteSource? = None,
) -> @services.AppEnvironment {
  @services.AppEnvironment::new(
    services=self.as_app_services(),
    timer~,
    routes~,
  )
}

///|
/// Adapt the host wire protocol to the typed app-facing services boundary.
/// Request ids and completion queues remain private to this package.
pub fn app_services(
  bridge~ : HostServiceBridge,
  async_queue? : HostServiceAsyncQueue? = None,
) -> @services.AppServices {
  HostServicesAdapter::new(bridge~, async_queue~).as_app_services()
}

///|
/// Build the app-facing environment supplied to a Program closure.
pub fn app_environment(
  bridge~ : HostServiceBridge,
  async_queue? : HostServiceAsyncQueue? = None,
  timer? : @services.TimerSource? = None,
  routes? : @services.RouteSource? = None,
) -> @services.AppEnvironment {
  HostServicesAdapter::new(bridge~, async_queue~).app_environment(
    timer~,
    routes~,
  )
}
