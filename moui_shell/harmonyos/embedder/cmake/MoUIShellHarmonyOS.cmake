cmake_minimum_required(VERSION 3.22)
project(moui_embedding_harmonyos LANGUAGES C CXX)

if(NOT DEFINED MOUI_ROOT OR NOT DEFINED MOUI_SHELL_ROOT)
  message(FATAL_ERROR "MOUI_ROOT and MOUI_SHELL_ROOT are required")
endif()
if(NOT DEFINED MOUI_EMBEDDING_NATIVE_CONFIG)
  if(DEFINED ENV{MOUI_EMBEDDING_NATIVE_CONFIG} AND
     NOT "$ENV{MOUI_EMBEDDING_NATIVE_CONFIG}" STREQUAL "")
    set(MOUI_EMBEDDING_NATIVE_CONFIG "$ENV{MOUI_EMBEDDING_NATIVE_CONFIG}")
  else()
    message(FATAL_ERROR "MOUI_EMBEDDING_NATIVE_CONFIG must point at generated moui-shell-harmonyos.cmake")
  endif()
endif()
include("${MOUI_EMBEDDING_NATIVE_CONFIG}")
if(NOT DEFINED MOUI_EMBEDDING_MOONBIT_C OR NOT EXISTS "${MOUI_EMBEDDING_MOONBIT_C}")
  message(FATAL_ERROR "MOUI_EMBEDDING_MOONBIT_C must point at generated MoonBit C")
endif()
if(NOT EXISTS "${MOUI_SHELL_ROOT}/include/moui_embedding_api_v1.h" OR
   NOT EXISTS "${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp")
  message(FATAL_ERROR "moui_shell embedding API v1 sources are required")
endif()
if(NOT "${MOUI_EMBEDDING_LIBRARY_NAME}" STREQUAL "moui_embedding_harmonyos")
  message(FATAL_ERROR "HarmonyOS shell requires native library moui_embedding_harmonyos")
endif()

set(MOUI_EMBEDDING_SHARED_HARMONYOS_DIR "${MOUI_SHELL_ROOT}/harmonyos/embedder")
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
  "${MOUI_SKIA_ROOT}/native/skia_stub_gpu_worker.cpp"
)
add_library(${MOUI_EMBEDDING_LIBRARY_NAME} SHARED
  "${MOUI_EMBEDDING_SHARED_HARMONYOS_DIR}/src/main/cpp/moui_embedding_harmonyos_napi.cpp"
  "${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp"
  "${MOUI_EMBEDDING_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_ROOT}/backend/harmonyos/skia/harmonyos_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)
target_include_directories(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_SHELL_ROOT}/include"
  "${MOUI_SKIA_ROOT}/native"
)
target_compile_features(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE cxx_std_17)
set_target_properties(${MOUI_EMBEDDING_LIBRARY_NAME} PROPERTIES
  OUTPUT_NAME "${MOUI_EMBEDDING_LIBRARY_NAME}"
  SUFFIX ".so"
)
target_compile_definitions(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE
  "MOUI_EMBEDDING_APP_ARG=\"${MOUI_EMBEDDING_APP_ARG}\""
  "MOUI_EMBEDDING_APP_ID=\"${MOUI_EMBEDDING_APP_ID}\""
  "MOUI_EMBEDDING_RENDERER_REQUESTED=\"${MOUI_EMBEDDING_RENDERER_REQUESTED}\""
  "MOUI_EMBEDDING_RENDERER_SELECTED=\"${MOUI_EMBEDDING_RENDERER_SELECTED}\""
  "MOUI_EMBEDDING_API_APP_MAIN=${MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS}"
  "MOUI_EMBEDDING_SMOKE_ATTACH_SURFACE=${MOUI_EMBEDDING_LIBRARY_NAME}_attach_surface_for_smoke"
  "MOUI_EMBEDDING_SMOKE_RENDER_FRAME=${MOUI_EMBEDDING_LIBRARY_NAME}_render_frame_for_smoke"
  "NODE_GYP_MODULE_NAME=${MOUI_EMBEDDING_LIBRARY_NAME}"
  __OHOS__=1
)
set_source_files_properties("${MOUI_EMBEDDING_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS}"
)
if(NOT DEFINED MOUI_HARMONYOS_FALLBACK)
  if(DEFINED ENV{MOUI_HARMONYOS_FALLBACK} AND
     NOT "$ENV{MOUI_HARMONYOS_FALLBACK}" STREQUAL "")
    set(MOUI_HARMONYOS_FALLBACK
      "$ENV{MOUI_HARMONYOS_FALLBACK}"
      CACHE BOOL "Build host-checkable fallback native glue"
    )
  else()
    set(MOUI_HARMONYOS_FALLBACK ON CACHE BOOL "Build host-checkable fallback native glue")
  endif()
endif()
if(MOUI_HARMONYOS_FALLBACK)
  target_compile_definitions(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE MOUI_HARMONYOS_FALLBACK=1)
else()
  target_compile_definitions(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE
    MOUI_HARMONYOS_ENABLE_NAPI=1
    MOUI_HARMONYOS_ENABLE_XCOMPONENT=1
    MOUI_HARMONYOS_USE_NATIVE_WINDOW=1
  )
endif()
if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_HARMONYOS_SKIA_STUB_FLAGS)
    target_compile_options(${MOUI_EMBEDDING_LIBRARY_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()
if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()
target_link_libraries(${MOUI_EMBEDDING_LIBRARY_NAME} ${MOUI_HARMONYOS_SKIA_LINK_FLAGS} m)
if(NOT MOUI_HARMONYOS_FALLBACK)
  target_link_libraries(${MOUI_EMBEDDING_LIBRARY_NAME}
    ace_napi.z ace_ndk.z hilog_ndk.z native_window native_buffer native_display_manager)
endif()
if(UNIX AND NOT APPLE)
  target_link_libraries(${MOUI_EMBEDDING_LIBRARY_NAME} dl)
endif()
