cmake_minimum_required(VERSION 3.22)
project(component_gallery_android LANGUAGES C CXX)

if(NOT DEFINED MOUI_REPO_ROOT)
  get_filename_component(MOUI_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../.." ABSOLUTE)
endif()

if(NOT DEFINED MOUI_MOON_HOME)
  if(DEFINED ENV{MOON_HOME} AND NOT "$ENV{MOON_HOME}" STREQUAL "")
    set(MOUI_MOON_HOME "$ENV{MOON_HOME}")
  else()
    set(MOUI_MOON_HOME "$ENV{HOME}/.moon")
  endif()
endif()

if(NOT DEFINED MOUI_COMPONENT_GALLERY_ANDROID_MOONBIT_C)
  message(FATAL_ERROR "MOUI_COMPONENT_GALLERY_ANDROID_MOONBIT_C must point at generated android.c")
endif()

set(MOUI_SKIA_STUB_SOURCES
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_common.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_surface_image_data.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_canvas.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_path.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_text_font.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_paragraph.cpp"
  "${MOUI_REPO_ROOT}/moui_skia/native/skia_stub_shader_filter.cpp"
)

add_library(component_gallery_android SHARED
  "component_gallery_jni.cpp"
  "moui_android_compat.c"
  "${MOUI_COMPONENT_GALLERY_ANDROID_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_REPO_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_REPO_ROOT}/moui/backend/android/skia/android_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)

target_include_directories(component_gallery_android PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_REPO_ROOT}/moui_skia/native"
)

target_compile_features(component_gallery_android PRIVATE cxx_std_17)
target_compile_definitions(component_gallery_android PRIVATE __ANDROID__)

set_source_files_properties("${MOUI_COMPONENT_GALLERY_ANDROID_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=moui_component_gallery_android_moonbit_generated_main")

set_source_files_properties("${MOUI_MOON_HOME}/lib/runtime.c" PROPERTIES
  COMPILE_OPTIONS "-include;${CMAKE_CURRENT_LIST_DIR}/moui_android_compat.h")

if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_COMPONENT_GALLERY_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_COMPONENT_GALLERY_SKIA_STUB_FLAGS)
    target_compile_options(component_gallery_android PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()

if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_COMPONENT_GALLERY_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()

target_link_libraries(component_gallery_android
  ${MOUI_COMPONENT_GALLERY_SKIA_LINK_FLAGS}
  android
  log
  m
  dl
)
