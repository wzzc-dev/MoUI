// Product message catalogs for Mo Desktop. Catalogs are product data owned
// by this package (see docs/internationalization.md); moui_i18n only owns
// locale parsing, fallback, and interpolation.

///|
/// User-facing UI languages supported by the desktop shell.
pub(all) enum AppLanguage {
  EnglishLanguage
  ChineseLanguage
} derive(Eq, Debug)

///|
fn AppLanguage::tag(self : AppLanguage) -> String {
  match self {
    EnglishLanguage => "en-US"
    ChineseLanguage => "zh-Hans"
  }
}

///|
/// The other supported language, for toggle affordances.
fn AppLanguage::other(self : AppLanguage) -> AppLanguage {
  match self {
    EnglishLanguage => ChineseLanguage
    ChineseLanguage => EnglishLanguage
  }
}

///|
fn AppLanguage::parse(tag : String) -> AppLanguage {
  if tag == "zh-Hans" || tag.has_prefix("zh") {
    ChineseLanguage
  } else {
    EnglishLanguage
  }
}

///|
let desktop_catalog : @i18n.Catalog = @i18n.Catalog::from_entries([
  // Session flow -----------------------------------------------------------
  @i18n.Message::new(
    locale="en-US",
    key="boot.title",
    value="Starting Mo Desktop",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="boot.title",
    value="正在启动 Mo 桌面",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="boot.skip",
    value="Tap anywhere to skip",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="boot.skip",
    value="点按任意位置跳过",
  ),
  @i18n.Message::new(locale="en-US", key="lock.sign_in", value="Sign In"),
  @i18n.Message::new(locale="zh-Hans", key="lock.sign_in", value="登录"),
  @i18n.Message::new(locale="en-US", key="login.unlock", value="Unlock"),
  @i18n.Message::new(locale="zh-Hans", key="login.unlock", value="解锁"),
  @i18n.Message::new(
    locale="en-US",
    key="login.password",
    value="Password (demo: anything)",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="login.password",
    value="密码（演示：任意）",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="login.hint",
    value="Demo account — any password works",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="login.hint",
    value="演示账户：任意密码均可登录",
  ),
  // Menu bar ---------------------------------------------------------------
  @i18n.Message::new(locale="en-US", key="menu.file", value="File"),
  @i18n.Message::new(locale="zh-Hans", key="menu.file", value="文件"),
  @i18n.Message::new(locale="en-US", key="menu.edit", value="Edit"),
  @i18n.Message::new(locale="zh-Hans", key="menu.edit", value="编辑"),
  @i18n.Message::new(locale="en-US", key="menu.view", value="View"),
  @i18n.Message::new(locale="zh-Hans", key="menu.view", value="显示"),
  @i18n.Message::new(locale="en-US", key="menu.go", value="Go"),
  @i18n.Message::new(locale="zh-Hans", key="menu.go", value="前往"),
  @i18n.Message::new(locale="en-US", key="menu.window", value="Window"),
  @i18n.Message::new(locale="zh-Hans", key="menu.window", value="窗口"),
  @i18n.Message::new(locale="en-US", key="menu.help", value="Help"),
  @i18n.Message::new(locale="zh-Hans", key="menu.help", value="帮助"),
  // Menu items -------------------------------------------------------------
  @i18n.Message::new(locale="en-US", key="item.about", value="About This Mac"),
  @i18n.Message::new(locale="zh-Hans", key="item.about", value="关于本机"),
  @i18n.Message::new(
    locale="en-US",
    key="item.settings",
    value="System Settings…",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.settings",
    value="系统设置…",
  ),
  @i18n.Message::new(locale="en-US", key="item.appstore", value="App Store…"),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.appstore",
    value="App Store…",
  ),
  @i18n.Message::new(locale="en-US", key="item.logout", value="Log Out"),
  @i18n.Message::new(locale="zh-Hans", key="item.logout", value="退出登录"),
  @i18n.Message::new(locale="en-US", key="item.lock", value="Lock Screen"),
  @i18n.Message::new(locale="zh-Hans", key="item.lock", value="锁定屏幕"),
  @i18n.Message::new(
    locale="en-US",
    key="item.reset",
    value="Reset All Settings",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.reset",
    value="恢复默认设置",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="item.new_finder",
    value="New Finder Window",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.new_finder",
    value="新建访达窗口",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="item.new_safari",
    value="New Safari Window",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.new_safari",
    value="新建 Safari 窗口",
  ),
  @i18n.Message::new(locale="en-US", key="item.close", value="Close {app}"),
  @i18n.Message::new(locale="zh-Hans", key="item.close", value="关闭{app}"),
  @i18n.Message::new(locale="en-US", key="item.documents", value="Documents"),
  @i18n.Message::new(locale="zh-Hans", key="item.documents", value="文稿"),
  @i18n.Message::new(locale="en-US", key="item.downloads", value="Downloads"),
  @i18n.Message::new(locale="zh-Hans", key="item.downloads", value="下载"),
  @i18n.Message::new(
    locale="en-US",
    key="item.applications",
    value="Applications",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.applications",
    value="应用程序",
  ),
  @i18n.Message::new(locale="en-US", key="item.as_icons", value="as Icons"),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.as_icons",
    value="以图标显示",
  ),
  @i18n.Message::new(locale="en-US", key="item.as_list", value="as List"),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.as_list",
    value="以列表显示",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="item.fullscreen",
    value="Enter Full Screen",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.fullscreen",
    value="进入全屏幕",
  ),
  @i18n.Message::new(locale="en-US", key="item.minimize", value="Minimize"),
  @i18n.Message::new(locale="zh-Hans", key="item.minimize", value="最小化"),
  @i18n.Message::new(locale="en-US", key="item.zoom", value="Zoom"),
  @i18n.Message::new(locale="zh-Hans", key="item.zoom", value="缩放"),
  @i18n.Message::new(
    locale="en-US",
    key="item.bring_finder",
    value="Bring Finder Forward",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.bring_finder",
    value="前置 Finder",
  ),
  @i18n.Message::new(
    locale="en-US",
    key="item.bring_safari",
    value="Bring Safari Forward",
  ),
  @i18n.Message::new(
    locale="zh-Hans",
    key="item.bring_safari",
    value="前置 Safari",
  ),
  @i18n.Message::new(locale="en-US", key="item.undo", value="Undo"),
  @i18n.Message::new(locale="zh-Hans", key="item.undo", value="撤销"),
  @i18n.Message::new(locale="en-US", key="item.redo", value="Redo"),
  @i18n.Message::new(locale="zh-Hans", key="item.redo", value="重做"),
  @i18n.Message::new(locale="en-US", key="item.select_all", value="Select All"),
  @i18n.Message::new(locale="zh-Hans", key="item.select_all", value="全选"),
])

///|
fn desktop_translator(language : AppLanguage) -> @i18n.Translator {
  @i18n.Translator::new(
    catalog=desktop_catalog,
    locale=@i18n.Locale::parse(language.tag()).unwrap(),
    default_locale=@i18n.Locale::parse("en-US").unwrap(),
  )
}

///|
/// Convenience lookup used by every localized surface.
pub fn AppLanguage::text(self : AppLanguage, key : String) -> String {
  desktop_translator(self).translate(key)
}

///|
/// Lookup with named interpolation values.
pub fn AppLanguage::translate(
  self : AppLanguage,
  key : String,
  values? : ArrayView[(String, String)] = [],
) -> String {
  desktop_translator(self).translate(key, values~)
}

///|
/// Menu label for switching to the other language. Shown in the target
/// language itself, per platform convention.
fn AppLanguage::toggle_label(self : AppLanguage) -> String {
  match self {
    EnglishLanguage => "中文"
    ChineseLanguage => "English"
  }
}
