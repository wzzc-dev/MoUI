if(NOT DEFINED MOUI_MOBILE_NATIVE_CONFIG)
  if(DEFINED ENV{MOUI_MOBILE_NATIVE_CONFIG} AND NOT "$ENV{MOUI_MOBILE_NATIVE_CONFIG}" STREQUAL "")
    set(MOUI_MOBILE_NATIVE_CONFIG "$ENV{MOUI_MOBILE_NATIVE_CONFIG}")
  else()
    message(FATAL_ERROR "MOUI_MOBILE_NATIVE_CONFIG must point at generated moui-mobile-harmonyos.cmake")
  endif()
endif()

include("${MOUI_MOBILE_NATIVE_CONFIG}")

if(NOT DEFINED MOUI_MOBILE_MOONBIT_C OR NOT EXISTS "${MOUI_MOBILE_MOONBIT_C}")
  message(FATAL_ERROR "MOUI_MOBILE_MOONBIT_C must point at generated MoonBit C")
endif()

if(NOT DEFINED MOUI_HARMONYOS_FALLBACK)
  if(DEFINED ENV{MOUI_HARMONYOS_FALLBACK} AND NOT "$ENV{MOUI_HARMONYOS_FALLBACK}" STREQUAL "")
    set(MOUI_HARMONYOS_FALLBACK "$ENV{MOUI_HARMONYOS_FALLBACK}" CACHE BOOL "Build host-checkable fallback native glue")
  else()
    set(MOUI_HARMONYOS_FALLBACK ON CACHE BOOL "Build host-checkable fallback native glue")
  endif()
endif()

if(NOT DEFINED MOUI_HARMONYOS_LEGACY_SHELL)
  if(DEFINED ENV{MOUI_HARMONYOS_LEGACY_SHELL} AND
     NOT "$ENV{MOUI_HARMONYOS_LEGACY_SHELL}" STREQUAL "")
    set(MOUI_HARMONYOS_LEGACY_SHELL
      "$ENV{MOUI_HARMONYOS_LEGACY_SHELL}"
      CACHE BOOL "Build Release N app-owned HarmonyOS shell"
    )
  else()
    set(MOUI_HARMONYOS_LEGACY_SHELL OFF CACHE BOOL "Build Release N app-owned HarmonyOS shell")
  endif()
endif()

set(MOUI_MOBILE_SHARED_HARMONYOS_DIR "${MOUI_ROOT}/mobile/harmonyos")
if(NOT EXISTS "${MOUI_ROOT}/mobile/include/moui_mobile_runtime_v1.h" OR
   NOT EXISTS "${MOUI_ROOT}/mobile/runtime/moui_mobile_runtime_v1.cpp")
  message(FATAL_ERROR "HarmonyOS shell requires the MoUI Mobile Runtime ABI v1 adapter")
endif()
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

add_library(${MOUI_MOBILE_LIBRARY_NAME} SHARED
  "${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/src/main/cpp/moui_mobile_harmonyos_napi.cpp"
  "${MOUI_ROOT}/mobile/runtime/moui_mobile_runtime_v1.cpp"
  "${MOUI_MOBILE_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_ROOT}/backend/harmonyos/skia/harmonyos_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)

target_include_directories(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_ROOT}/mobile/include"
  "${MOUI_SKIA_ROOT}/native"
)

target_compile_features(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE cxx_std_17)
set_target_properties(${MOUI_MOBILE_LIBRARY_NAME} PROPERTIES
  OUTPUT_NAME "${MOUI_MOBILE_LIBRARY_NAME}"
  SUFFIX ".so"
)

target_compile_definitions(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
  "MOUI_MOBILE_APP_ARG=\"${MOUI_MOBILE_APP_ARG}\""
  "MOUI_MOBILE_APP_ID=\"${MOUI_MOBILE_APP_ID}\""
  "MOUI_MOBILE_RENDERER_REQUESTED=\"${MOUI_MOBILE_RENDERER_REQUESTED}\""
  "MOUI_MOBILE_RENDERER_SELECTED=\"${MOUI_MOBILE_RENDERER_SELECTED}\""
  "MOUI_MOBILE_SMOKE_ATTACH_SURFACE=${MOUI_MOBILE_LIBRARY_NAME}_attach_surface_for_smoke"
  "MOUI_MOBILE_SMOKE_RENDER_FRAME=${MOUI_MOBILE_LIBRARY_NAME}_render_frame_for_smoke"
  "NODE_GYP_MODULE_NAME=${MOUI_MOBILE_LIBRARY_NAME}"
  # Ensure Skia EGL stubs see the HarmonyOS platform even if a compile unit
  # misses toolchain predefines through an unusual flag path.
  __OHOS__=1
)

if(MOUI_HARMONYOS_LEGACY_SHELL)
  target_compile_definitions(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
    "MOUI_MOBILE_RUNTIME_ENABLE_SCROLL=$<IF:$<BOOL:${MOUI_MOBILE_ENABLE_SCROLL}>,1,0>"
    "MOUI_MOBILE_RUNTIME_ATTACH_SURFACE=${MOUI_MOBILE_ATTACH_SURFACE_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_RESIZE=${MOUI_MOBILE_RESIZE_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_DISPATCH_POINTER=${MOUI_MOBILE_DISPATCH_POINTER_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_DISPATCH_SCROLL=${MOUI_MOBILE_DISPATCH_SCROLL_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_FRAME_TICK=${MOUI_MOBILE_FRAME_TICK_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_RENDER_FRAME=${MOUI_MOBILE_RENDER_FRAME_SYMBOL}"
    "MOUI_MOBILE_RUNTIME_DETACH_SURFACE=${MOUI_MOBILE_DETACH_SURFACE_SYMBOL}"
  )
else()
  if(NOT "${MOUI_MOBILE_LIBRARY_NAME}" STREQUAL "moui_mobile_harmonyos")
    message(FATAL_ERROR "managed HarmonyOS shell requires native library moui_mobile_harmonyos")
  endif()
  set(MOUI_HARMONYOS_FIXED_SYMBOLS
    "MOUI_MOBILE_ATTACH_SURFACE_SYMBOL=moui_mobile_attach_surface"
    "MOUI_MOBILE_RESIZE_SYMBOL=moui_mobile_resize"
    "MOUI_MOBILE_DISPATCH_POINTER_SYMBOL=moui_mobile_dispatch_pointer"
    "MOUI_MOBILE_DISPATCH_SCROLL_SYMBOL=moui_mobile_dispatch_scroll"
    "MOUI_MOBILE_FRAME_TICK_SYMBOL=moui_mobile_frame_tick"
    "MOUI_MOBILE_RENDER_FRAME_SYMBOL=moui_mobile_render_frame"
    "MOUI_MOBILE_DETACH_SURFACE_SYMBOL=moui_mobile_detach_surface"
  )
  foreach(symbol_pair IN LISTS MOUI_HARMONYOS_FIXED_SYMBOLS)
    string(REPLACE "=" ";" symbol_parts "${symbol_pair}")
    list(GET symbol_parts 0 symbol_name)
    list(GET symbol_parts 1 expected_symbol)
    if(DEFINED ${symbol_name} AND
       NOT "${${symbol_name}}" STREQUAL "${expected_symbol}")
      message(FATAL_ERROR
        "managed HarmonyOS shell rejects app-specific symbol ${symbol_name}=${${symbol_name}}"
      )
    endif()
  endforeach()
  set(MOUI_MOBILE_MOONBIT_MAIN_ALIAS moui_mobile_moonbit_generated_main)
endif()

set_source_files_properties("${MOUI_MOBILE_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MOUI_MOBILE_MOONBIT_MAIN_ALIAS}"
)

if(MOUI_HARMONYOS_FALLBACK)
  target_compile_definitions(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE MOUI_HARMONYOS_FALLBACK=1)
else()
  target_compile_definitions(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
    MOUI_HARMONYOS_ENABLE_NAPI=1
    MOUI_HARMONYOS_ENABLE_XCOMPONENT=1
    MOUI_HARMONYOS_USE_NATIVE_WINDOW=1
  )
endif()

if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_HARMONYOS_SKIA_STUB_FLAGS)
    target_compile_options(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()

if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_HARMONYOS_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()

target_link_libraries(${MOUI_MOBILE_LIBRARY_NAME}
  ${MOUI_HARMONYOS_SKIA_LINK_FLAGS}
  m
)

if(NOT MOUI_HARMONYOS_FALLBACK)
  target_link_libraries(${MOUI_MOBILE_LIBRARY_NAME}
    ace_napi.z
    ace_ndk.z
    hilog_ndk.z
    native_window
    native_buffer
    native_display_manager
  )
endif()

if(UNIX AND NOT APPLE)
  target_link_libraries(${MOUI_MOBILE_LIBRARY_NAME} dl)
endif()
