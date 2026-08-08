///|
fn runtime_consumer_roots() -> Array[String] {
  [
    "benchmarks", "examples", "moui/backend", "moui_tests", "moui/views", "moui_devtools",
    "website",
  ]
}

///|
fn backend_runtime_interface_paths() -> Array[String] {
  [
    "moui/backend/pkg.generated.mbti", "moui/backend/web/pkg.generated.mbti", "moui/backend/macos/pkg.generated.mbti",
    "moui/backend/windows/pkg.generated.mbti", "moui/backend/linux/pkg.generated.mbti",
    "moui/backend/android/pkg.generated.mbti", "moui/backend/ios/pkg.generated.mbti",
    "moui/backend/harmonyos/pkg.generated.mbti",
  ]
}

///|
fn max_shared_app_runtime_imports() -> Int {
  0
}

///|
fn max_shared_app_core_imports() -> Int {
  20
}

///|
/// Post-domain-sugar refactor, `@core` is a first-class shared-app dependency;
/// this list is retained only for tests that assert the guard still tracks paths.
fn allowed_shared_app_core_imports() -> Array[String] {
  [
    "examples/browser/app/moon.pkg", "examples/markdown_editor/app/moon.pkg",
    "examples/mo_workbench/app/moon.pkg", "examples/pdf_workbench/app/moon.pkg",
    "examples/showcase/app/moon.pkg", "website/app/moon.pkg",
  ]
}

///|
/// Shared apps are pure TEA packages. Runtime, host wire protocol, renderer,
/// and concrete backend imports belong in composition or integration packages.
fn allowed_shared_app_runtime_imports() -> Array[String] {
  []
}
