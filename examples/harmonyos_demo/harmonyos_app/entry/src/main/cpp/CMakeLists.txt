cmake_minimum_required(VERSION 3.22)
project(moui_harmonyos_demo LANGUAGES C CXX)

if(NOT DEFINED MOUI_HARMONYOS_FALLBACK)
  if(DEFINED ENV{MOUI_HARMONYOS_FALLBACK} AND NOT "$ENV{MOUI_HARMONYOS_FALLBACK}" STREQUAL "")
    set(MOUI_HARMONYOS_FALLBACK "$ENV{MOUI_HARMONYOS_FALLBACK}" CACHE BOOL "Build host-checkable fallback native glue")
  else()
    set(MOUI_HARMONYOS_FALLBACK ON CACHE BOOL "Build host-checkable fallback native glue")
  endif()
endif()

if(NOT DEFINED MOUI_REPO_ROOT)
  if(DEFINED ENV{MOUI_REPO_ROOT} AND NOT "$ENV{MOUI_REPO_ROOT}" STREQUAL "")
    set(MOUI_REPO_ROOT "$ENV{MOUI_REPO_ROOT}")
  else()
    get_filename_component(MOUI_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../../.." ABSOLUTE)
  endif()
endif()

if(NOT DEFINED MOUI_MOON_HOME)
  if(DEFINED ENV{MOON_HOME} AND NOT "$ENV{MOON_HOME}" STREQUAL "")
    set(MOUI_MOON_HOME "$ENV{MOON_HOME}")
  elseif(DEFINED ENV{MOUI_MOON_HOME} AND NOT "$ENV{MOUI_MOON_HOME}" STREQUAL "")
    set(MOUI_MOON_HOME "$ENV{MOUI_MOON_HOME}")
  else()
    set(MOUI_MOON_HOME "$ENV{HOME}/.moon")
  endif()
endif()

if(NOT DEFINED MOUI_HARMONYOS_DEMO_MOONBIT_C)
  if(DEFINED ENV{MOUI_HARMONYOS_DEMO_MOONBIT_C} AND NOT "$ENV{MOUI_HARMONYOS_DEMO_MOONBIT_C}" STREQUAL "")
    set(MOUI_HARMONYOS_DEMO_MOONBIT_C "$ENV{MOUI_HARMONYOS_DEMO_MOONBIT_C}")
  else()
    message(FATAL_ERROR "MOUI_HARMONYOS_DEMO_MOONBIT_C must point at generated harmonyos_skia.c")
  endif()
endif()

if(NOT DEFINED MOUI_SKIA_STUB_CC_FLAGS AND DEFINED ENV{MOUI_SKIA_STUB_CC_FLAGS})
  set(MOUI_SKIA_STUB_CC_FLAGS "$ENV{MOUI_SKIA_STUB_CC_FLAGS}")
endif()

if(NOT DEFINED MOUI_SKIA_CC_LINK_FLAGS AND DEFINED ENV{MOUI_SKIA_CC_LINK_FLAGS})
  set(MOUI_SKIA_CC_LINK_FLAGS "$ENV{MOUI_SKIA_CC_LINK_FLAGS}")
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

add_library(moui_harmonyos_demo SHARED
  "harmonyos_demo_napi.cpp"
  "${MOUI_HARMONYOS_DEMO_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_REPO_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_REPO_ROOT}/moui/backend/harmonyos/skia/harmonyos_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)

target_include_directories(moui_harmonyos_demo PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_REPO_ROOT}/moui_skia/native"
)

target_compile_features(moui_harmonyos_demo PRIVATE cxx_std_17)
set_target_properties(moui_harmonyos_demo PROPERTIES
  OUTPUT_NAME "moui_harmonyos_demo"
  SUFFIX ".so"
)

set_source_files_properties("${MOUI_HARMONYOS_DEMO_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=moui_harmonyos_moonbit_generated_main")

if(MOUI_HARMONYOS_FALLBACK)
  target_compile_definitions(moui_harmonyos_demo PRIVATE MOUI_HARMONYOS_FALLBACK=1)
else()
  target_compile_definitions(moui_harmonyos_demo PRIVATE
    MOUI_HARMONYOS_ENABLE_NAPI=1
    MOUI_HARMONYOS_ENABLE_XCOMPONENT=1
    MOUI_HARMONYOS_USE_NATIVE_WINDOW=1
  )
endif()

if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_HARMONYOS_SKIA_STUB_FLAGS)
    target_compile_options(moui_harmonyos_demo PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()

if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()

target_link_libraries(moui_harmonyos_demo
  ${MOUI_HARMONYOS_SKIA_LINK_FLAGS}
  m
)

if(NOT MOUI_HARMONYOS_FALLBACK)
  target_link_libraries(moui_harmonyos_demo
    ace_napi.z
    ace_ndk.z
    hilog_ndk.z
    native_window
    native_buffer
  )
endif()

if(UNIX AND NOT APPLE)
  target_link_libraries(moui_harmonyos_demo dl)
endif()
