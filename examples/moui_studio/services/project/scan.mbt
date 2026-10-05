///|
/// 工程树扫描(纯)。
///
/// 输入是适配层(后续接 `@x/fs`)收集好的目录条目与 moon.pkg 文本,本文件
/// 不做任何 IO——扫描与入口判定因此可以完全单测。约定来自仓库全部实例:
/// web 入口目录名 `web_wasm`,native 入口目录名 `macos_skia`(导出 bundle
/// 用 `native_app`,一并识别;`macos_skia` 优先);逻辑入口 = 含
/// `pub fn program` 的包(`pub fn program() -> @moui.Program[...]`)。

///|
/// 包类别:入口按目录命名约定识别,其余是普通包。
pub(all) enum PackageKind {
  PkPlain
  PkWebEntry
  PkNativeEntry
}

///|
pub(all) struct ScannedPackage {
  rel_path : String
  manifest : PackageManifest
  has_program : Bool
  kind : PackageKind
  /// 该包目录下的**全部文件名**(资源管理器文件树用;不含子目录)
  files : Array[String]
}

///|
pub(all) struct ScannedModule {
  manifest : ModuleManifest
  packages : Array[ScannedPackage]
  /// web 入口包的相对路径("web_wasm");无则空串
  web_entry : String
  /// native 入口包的相对路径(macos_skia 优先于 native_app);无则空串
  native_entry : String
  /// 含 `pub fn program` 的包(逻辑/预览 harness 的挂载点)
  program_packages : Array[String]
}

///|
/// 目录树条目(相对模块根;根目录 rel_path = "")。
/// `files` 是该目录下的文件名列表(is_dir 为假时可为空)。
pub(all) struct LayoutEntry {
  rel_path : String
  is_dir : Bool
  files : Array[String]
}

///|
/// 布局扫描:返回「含 moon.pkg 的目录」相对路径(包候选,顺序保持)。
pub fn scan_package_paths(entries : Array[LayoutEntry]) -> Array[String] {
  let paths : Array[String] = []
  for entry in entries {
    if entry.is_dir && entry.files.contains("moon.pkg") {
      paths.push(entry.rel_path)
    }
  }
  paths
}

///|
/// 组装扫描结果:逐包解析 moon.pkg + 入口判定。
/// `package_sources` 每项 = (rel_path, moon.pkg 文本, 是否含 `pub fn program`)。
/// 任何一个包解析失败,整次扫描**结构化报错**(带包相对路径)——资源管理器
/// 要能指着说「这个包的清单坏了」,而不是悄悄跳过造成入口误判。
pub fn scan_module(
  manifest : ModuleManifest,
  package_sources : Array[(String, String, Bool, Array[String])],
) -> Result[ScannedModule, String] {
  let packages : Array[ScannedPackage] = []
  let mut web_entry = ""
  let mut native_entry = ""
  let program_packages : Array[String] = []
  for input in package_sources {
    let (rel_path, pkg_source, has_program, files) = input
    let parsed = match parse_package_manifest(rel_path~, pkg_source) {
      Ok(m) => m
      Err(msg) => return Err(msg)
    }
    let name = dir_name(rel_path)
    let kind = match name {
      "web_wasm" => PkWebEntry
      "macos_skia" | "native_app" => PkNativeEntry
      _ => PkPlain
    }
    if kind is PkWebEntry && web_entry == "" {
      web_entry = rel_path
    }
    if kind is PkNativeEntry && (native_entry == "" || name == "macos_skia") {
      native_entry = rel_path
    }
    if has_program {
      program_packages.push(rel_path)
    }
    packages.push(ScannedPackage::{
      rel_path,
      manifest: parsed,
      has_program,
      kind,
      files,
    })
  }
  Ok(ScannedModule::{
    manifest,
    packages,
    web_entry,
    native_entry,
    program_packages,
  })
}

///|
/// 目录名:rel_path 最后一段(根包为空串)。
fn dir_name(rel_path : String) -> String {
  let chars = chars_of(rel_path)
  let mut last = -1
  let mut i = 0
  for c in chars {
    if c == '/' {
      last = i
    }
    i = i + 1
  }
  rel_path[last + 1:].to_owned()
}
