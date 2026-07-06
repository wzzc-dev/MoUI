///|
fn skia_typeface_from_font_files(
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  for family in font.families.families {
    for family_name in skia_font_family_candidates(family) {
      match skia_typeface_from_font_file_family(family_name, font) {
        Some(typeface) => return Some(typeface)
        None => ()
      }
    }
  }
  None
}

///|
fn skia_typeface_from_font_file_family(
  family_name : String,
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  if family_name == "Open Sans" {
    skia_open_sans_typeface_from_file(font)
  } else {
    None
  }
}

///|
fn skia_open_sans_typeface_from_file(
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  let file_names = skia_open_sans_font_file_names(font)
  let directories = skia_open_sans_font_directories()
  for directory in directories {
    for file_name in file_names {
      let path = skia_join_font_path(directory, file_name)
      if @fs.path_exists(path) {
        match
          @skia_native.Typeface::from_file(@utf8.encode(path[:], bom=false)) {
          Some(typeface) => return Some(typeface)
          None => ()
        }
      }
    }
  }
  None
}

///|
fn skia_open_sans_font_file_names(font : @core.FontSpec) -> Array[String] {
  let file_names : Array[String] = []
  let bold = font.weight >= 600
  let italic = font.style == @core.FontStyle::Italic
  if bold && italic {
    skia_push_unique_string(
      file_names, "open-sans-v17-latin-ext_latin-700italic.woff2",
    )
  }
  if italic {
    skia_push_unique_string(
      file_names, "open-sans-v17-latin-ext_latin-italic.woff2",
    )
  }
  if bold {
    skia_push_unique_string(
      file_names, "open-sans-v17-latin-ext_latin-700.woff2",
    )
  }
  skia_push_unique_string(
    file_names, "open-sans-v17-latin-ext_latin-regular.woff2",
  )
  file_names
}

///|
fn skia_open_sans_font_directories() -> Array[String] {
  let directories : Array[String] = []
  match @env.get_env_var("MOUI_SKIA_OPEN_SANS_DIR") {
    Some(directory) => skia_push_font_directory(directories, directory)
    None => ()
  }
  match @env.get_env_var("MOUI_SKIA_FONT_DIRS") {
    Some(value) => skia_push_font_directories_from_env(directories, value)
    None => ()
  }
  match @env.current_dir() {
    Some(directory) => {
      skia_push_font_directory(
        directories,
        skia_join_font_path(directory, "assets/fonts/open-sans"),
      )
      skia_push_font_directory(
        directories,
        skia_join_font_path(
          directory, "examples/markdown_editor/app/assets/fonts/open-sans",
        ),
      )
    }
    None => ()
  }
  match @env.get_env_var("HOME") {
    Some(home) =>
      skia_push_font_directory(
        directories,
        skia_join_font_path(
          home, "Library/Application Support/abnerworks.Typora/themes/github",
        ),
      )
    None => ()
  }
  skia_push_font_directory(
    directories, "/Applications/Typora.app/Contents/Resources/TypeMark/style/themes/github",
  )
  directories
}

///|
fn skia_push_font_directories_from_env(
  directories : Array[String],
  value : String,
) -> Unit {
  let separator = if value.contains(";") { ";" } else { ":" }
  for entry in value.split(separator) {
    skia_push_font_directory(directories, entry.to_owned())
  }
}

///|
fn skia_push_font_directory(
  directories : Array[String],
  directory : String,
) -> Unit {
  if directory != "" && !directories.contains(directory) {
    directories.push(directory)
  }
}

///|
fn skia_push_unique_string(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn skia_join_font_path(directory : String, file_name : String) -> String {
  if directory == "" {
    file_name
  } else if directory.has_suffix("/") || directory.has_suffix("\\") {
    directory + file_name
  } else {
    directory + "/" + file_name
  }
}
