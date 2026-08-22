///|
pub(all) struct ClipboardImage {
  mime_type : String
  bytes : Bytes
} derive(Eq, Debug)

///|
pub struct ClipboardServices {
  read_text_fn : () -> ServiceTask[String]
  write_text_fn : (String) -> ServiceTask[Unit]
  read_image_fn : () -> ServiceTask[ClipboardImage]
  write_image_fn : (ClipboardImage) -> ServiceTask[Unit]
}

///|
pub struct UrlServices {
  open_fn : (String) -> ServiceTask[Unit]
}

///|
pub struct SettingsServices {
  read_fn : (String) -> ServiceTask[String?]
  write_fn : (String, String) -> ServiceTask[Unit]
  remove_fn : (String) -> ServiceTask[Unit]
}

///|
pub struct AppearanceServices {
  system_color_scheme_fn : () -> ServiceTask[@core.ColorScheme]
}

///|
pub(all) enum ApplicationMenuItem {
  MenuCommand(@core.ActionCommand)
  MenuSeparator
}

///|
pub(all) enum ApplicationMenuPlacement {
  MenuBar
  ApplicationMenu
} derive(Eq, Debug)

///|
pub(all) struct ApplicationMenu {
  title : String
  items : Array[ApplicationMenuItem]
  placement : ApplicationMenuPlacement
}

///|
pub struct MenuServices {
  show_context_fn : (Array[@core.ActionCommand]) -> ServiceTask[
    @core.ActionCommand,
  ]
  install_application_fn : (Array[ApplicationMenu]) -> ServiceTask[Unit]
}

///|
pub struct AppServices {
  files_value : FileServices
  clipboard_value : ClipboardServices
  urls_value : UrlServices
  settings_value : SettingsServices
  appearance_value : AppearanceServices
  menus_value : MenuServices
  platform_value : PlatformServices
}

///|
pub fn ClipboardServices::new(
  read_text? : () -> ServiceTask[String] = () => {
    unavailable_task("clipboard:read-text", "clipboard read")
  },
  write_text? : (String) -> ServiceTask[Unit] = _text => {
    unavailable_task("clipboard:write-text", "clipboard write")
  },
  read_image? : () -> ServiceTask[ClipboardImage] = () => {
    unavailable_task("clipboard:read-image", "clipboard image read")
  },
  write_image? : (ClipboardImage) -> ServiceTask[Unit] = _image => {
    unavailable_task("clipboard:write-image", "clipboard image write")
  },
) -> ClipboardServices {
  {
    read_text_fn: read_text,
    write_text_fn: write_text,
    read_image_fn: read_image,
    write_image_fn: write_image,
  }
}

///|
pub fn ClipboardServices::read_text(
  self : ClipboardServices,
) -> ServiceTask[String] {
  (self.read_text_fn)()
}

///|
pub fn ClipboardServices::write_text(
  self : ClipboardServices,
  text : String,
) -> ServiceTask[Unit] {
  (self.write_text_fn)(text)
}

///|
pub fn ClipboardServices::read_image(
  self : ClipboardServices,
) -> ServiceTask[ClipboardImage] {
  (self.read_image_fn)()
}

///|
pub fn ClipboardServices::write_image(
  self : ClipboardServices,
  image : ClipboardImage,
) -> ServiceTask[Unit] {
  (self.write_image_fn)(image)
}

///|
pub fn UrlServices::new(
  open? : (String) -> ServiceTask[Unit] = _url => {
    unavailable_task("url:open", "URL open")
  },
) -> UrlServices {
  { open_fn: open }
}

///|
pub fn UrlServices::open(self : UrlServices, url : String) -> ServiceTask[Unit] {
  (self.open_fn)(url)
}

///|
pub fn SettingsServices::new(
  read? : (String) -> ServiceTask[String?] = _key => {
    unavailable_task("settings:read", "settings read")
  },
  write? : (String, String) -> ServiceTask[Unit] = (_key, _value) => {
    unavailable_task("settings:write", "settings write")
  },
  remove? : (String) -> ServiceTask[Unit] = _key => {
    unavailable_task("settings:remove", "settings remove")
  },
) -> SettingsServices {
  { read_fn: read, write_fn: write, remove_fn: remove }
}

///|
pub fn SettingsServices::read(
  self : SettingsServices,
  key : String,
) -> ServiceTask[String?] {
  (self.read_fn)(key)
}

///|
pub fn SettingsServices::write(
  self : SettingsServices,
  key : String,
  value : String,
) -> ServiceTask[Unit] {
  (self.write_fn)(key, value)
}

///|
pub fn SettingsServices::remove(
  self : SettingsServices,
  key : String,
) -> ServiceTask[Unit] {
  (self.remove_fn)(key)
}

///|
pub fn AppearanceServices::new(
  system_color_scheme? : () -> ServiceTask[@core.ColorScheme] = () => {
    unavailable_task("appearance:system-color-scheme", "system color scheme")
  },
) -> AppearanceServices {
  { system_color_scheme_fn: system_color_scheme }
}

///|
pub fn AppearanceServices::system_color_scheme(
  self : AppearanceServices,
) -> ServiceTask[@core.ColorScheme] {
  (self.system_color_scheme_fn)()
}

///|
pub fn ApplicationMenu::new(
  title~ : String,
  items~ : Array[ApplicationMenuItem],
  placement? : ApplicationMenuPlacement = ApplicationMenuPlacement::MenuBar,
) -> ApplicationMenu {
  { title, items, placement }
}

///|
/// Commands placed in the platform's standard application menu. On macOS,
/// these appear after About and before Services.
pub fn ApplicationMenu::application(
  items~ : Array[ApplicationMenuItem],
) -> ApplicationMenu {
  { title: "", items, placement: ApplicationMenuPlacement::ApplicationMenu }
}

///|
pub fn MenuServices::new(
  show_context? : (Array[@core.ActionCommand]) -> ServiceTask[
    @core.ActionCommand,
  ] = _commands => unavailable_task("menu:context", "context menu"),
  install_application? : (Array[ApplicationMenu]) -> ServiceTask[Unit] = _menus => {
    unavailable_task("menu:application", "application menu")
  },
) -> MenuServices {
  { show_context_fn: show_context, install_application_fn: install_application }
}

///|
pub fn MenuServices::show_context(
  self : MenuServices,
  commands : Array[@core.ActionCommand],
) -> ServiceTask[@core.ActionCommand] {
  (self.show_context_fn)(commands)
}

///|
pub fn MenuServices::install_application(
  self : MenuServices,
  menus : Array[ApplicationMenu],
) -> ServiceTask[Unit] {
  (self.install_application_fn)(menus)
}

///|
pub fn AppServices::new(
  files? : FileServices = FileServices::unavailable(),
  clipboard? : ClipboardServices = ClipboardServices::new(),
  urls? : UrlServices = UrlServices::new(),
  settings? : SettingsServices = SettingsServices::new(),
  appearance? : AppearanceServices = AppearanceServices::new(),
  menus? : MenuServices = MenuServices::new(),
  platform? : PlatformServices = PlatformServices::unavailable(),
) -> AppServices {
  {
    files_value: files,
    clipboard_value: clipboard,
    urls_value: urls,
    settings_value: settings,
    appearance_value: appearance,
    menus_value: menus,
    platform_value: platform,
  }
}

///|
pub fn AppServices::unavailable() -> AppServices {
  AppServices::new()
}

///|
pub fn AppServices::files(self : AppServices) -> FileServices {
  self.files_value
}

///|
pub fn AppServices::clipboard(self : AppServices) -> ClipboardServices {
  self.clipboard_value
}

///|
pub fn AppServices::urls(self : AppServices) -> UrlServices {
  self.urls_value
}

///|
pub fn AppServices::settings(self : AppServices) -> SettingsServices {
  self.settings_value
}

///|
pub fn AppServices::appearance(self : AppServices) -> AppearanceServices {
  self.appearance_value
}

///|
pub fn AppServices::menus(self : AppServices) -> MenuServices {
  self.menus_value
}

///|
pub fn AppServices::platform(self : AppServices) -> PlatformServices {
  self.platform_value
}
