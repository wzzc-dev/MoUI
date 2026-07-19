cmake_minimum_required(VERSION 3.22)
project(moui_embedding_android LANGUAGES C CXX)

# This module is owned by wzzc-dev/moui_shell.  It consumes only the public
# embedding table and provider implementation from the shell package. MoUI
# contributes only registered MoonBit runtime callbacks.
if(NOT DEFINED MOUI_ROOT OR NOT DEFINED MOUI_SHELL_ROOT)
  message(FATAL_ERROR "MOUI_ROOT and MOUI_SHELL_ROOT are required")
endif()
if(NOT DEFINED MOUI_EMBEDDING_NATIVE_CONFIG)
  message(FATAL_ERROR "MOUI_EMBEDDING_NATIVE_CONFIG must point at generated moui-shell-native.cmake")
endif()
include("${MOUI_EMBEDDING_NATIVE_CONFIG}")

if(NOT DEFINED MOUI_EMBEDDING_MOONBIT_C OR NOT EXISTS "${MOUI_EMBEDDING_MOONBIT_C}")
  message(FATAL_ERROR "MOUI_EMBEDDING_MOONBIT_C must point at generated MoonBit C")
endif()
if(NOT EXISTS "${MOUI_SHELL_ROOT}/include/moui_embedding_api_v1.h" OR
   NOT EXISTS "${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp")
  message(FATAL_ERROR "moui_shell embedding API v1 sources are required")
endif()

set(MOUI_EMBEDDING_SHARED_ANDROID_DIR "${MOUI_SHELL_ROOT}/android/embedder")
set(MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS moui_embedding_moonbit_generated_main)
set(MOUI_SKIA_STUB_SOURCES
  "${MOUI_SKIA_ROOT}/native/skia_stub.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_common.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_surface_image_data.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_canvas.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_path.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_text_font.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_paragraph.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_shader_filter.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_picture.cpp"
  "${MOUI_SKIA_ROOT}/native/android_vulkan_loader.cpp"
  "${MOUI_SKIA_ROOT}/native/skia_stub_gpu_worker.cpp"
)

add_library(${MOUI_EMBEDDING_LIBRARY_NAME} SHARED
  "${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_embedding_jni.cpp"
  "${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.c"
  "${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp"
  "${MOUI_EMBEDDING_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_ROOT}/backend/android/skia/android_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)

target_include_directories(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_SHELL_ROOT}/include"
  "${MOUI_SKIA_ROOT}/native"
)
target_compile_features(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE
  __ANDROID__
  "MOUI_EMBEDDING_APP_ARG=\"${MOUI_EMBEDDING_APP_ARG}\""
  "MOUI_EMBEDDING_APP_ID=\"${MOUI_EMBEDDING_APP_ID}\""
  "MOUI_EMBEDDING_RENDERER_REQUESTED=\"${MOUI_EMBEDDING_RENDERER_REQUESTED}\""
  "MOUI_EMBEDDING_RENDERER_SELECTED=\"${MOUI_EMBEDDING_RENDERER_SELECTED}\""
  "MOUI_EMBEDDING_API_APP_MAIN=${MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS}"
)
set_source_files_properties("${MOUI_EMBEDDING_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS}"
)
set_source_files_properties("${MOUI_MOON_HOME}/lib/runtime.c" PROPERTIES
  COMPILE_OPTIONS "-include;${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.h"
)

if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_EMBEDDING_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_EMBEDDING_SKIA_STUB_FLAGS)
    target_compile_options(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()
if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_EMBEDDING_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()
target_link_libraries(${MOUI_EMBEDDING_LIBRARY_NAME}
  ${MOUI_EMBEDDING_SKIA_LINK_FLAGS}
  android log m dl
)
