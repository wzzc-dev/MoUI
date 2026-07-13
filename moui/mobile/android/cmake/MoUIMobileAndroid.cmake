if(NOT DEFINED MOUI_MOBILE_NATIVE_CONFIG)
  message(FATAL_ERROR "MOUI_MOBILE_NATIVE_CONFIG must point at generated moui-mobile-native.cmake")
endif()

include("${MOUI_MOBILE_NATIVE_CONFIG}")

if(NOT DEFINED MOUI_MOBILE_MOONBIT_C OR NOT EXISTS "${MOUI_MOBILE_MOONBIT_C}")
  message(FATAL_ERROR "MOUI_MOBILE_MOONBIT_C must point at generated MoonBit C")
endif()

set(MOUI_MOBILE_SHARED_ANDROID_DIR "${MOUI_ROOT}/mobile/android")
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

add_library(${MOUI_MOBILE_LIBRARY_NAME} SHARED
  "${MOUI_MOBILE_SHARED_ANDROID_DIR}/src/main/cpp/moui_mobile_jni.cpp"
  "${MOUI_MOBILE_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.c"
  "${MOUI_MOBILE_MOONBIT_C}"
  "${MOUI_MOON_HOME}/lib/runtime.c"
  "${MOUI_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MOUI_ROOT}/backend/android/skia/android_skia_presenter.cpp"
  ${MOUI_SKIA_STUB_SOURCES}
)

target_include_directories(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
  "${MOUI_MOON_HOME}/include"
  "${MOUI_SKIA_ROOT}/native"
)

target_compile_features(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE
  __ANDROID__
  "MOUI_MOBILE_APP_ARG=\"${MOUI_MOBILE_APP_ARG}\""
  "MOUI_MOBILE_APP_ID=\"${MOUI_MOBILE_APP_ID}\""
  "MOUI_MOBILE_RENDERER_REQUESTED=\"${MOUI_MOBILE_RENDERER_REQUESTED}\""
  "MOUI_MOBILE_RENDERER_SELECTED=\"${MOUI_MOBILE_RENDERER_SELECTED}\""
  "MOUI_MOBILE_ENABLE_SCROLL=$<IF:$<BOOL:${MOUI_MOBILE_ENABLE_SCROLL}>,1,0>"
  "MOUI_MOBILE_ATTACH_SURFACE=${MOUI_MOBILE_ATTACH_SURFACE_SYMBOL}"
  "MOUI_MOBILE_RESIZE=${MOUI_MOBILE_RESIZE_SYMBOL}"
  "MOUI_MOBILE_DISPATCH_POINTER=${MOUI_MOBILE_DISPATCH_POINTER_SYMBOL}"
  "MOUI_MOBILE_DISPATCH_SCROLL=${MOUI_MOBILE_DISPATCH_SCROLL_SYMBOL}"
  "MOUI_MOBILE_FRAME_TICK=${MOUI_MOBILE_FRAME_TICK_SYMBOL}"
  "MOUI_MOBILE_RENDER_FRAME=${MOUI_MOBILE_RENDER_FRAME_SYMBOL}"
  "MOUI_MOBILE_DETACH_SURFACE=${MOUI_MOBILE_DETACH_SURFACE_SYMBOL}"
)

set_source_files_properties("${MOUI_MOBILE_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MOUI_MOBILE_MOONBIT_MAIN_ALIAS}")

set_source_files_properties("${MOUI_MOON_HOME}/lib/runtime.c" PROPERTIES
  COMPILE_OPTIONS "-include;${MOUI_MOBILE_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.h")

if(DEFINED MOUI_SKIA_STUB_CC_FLAGS AND NOT "${MOUI_SKIA_STUB_CC_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_MOBILE_SKIA_STUB_FLAGS UNIX_COMMAND "${MOUI_SKIA_STUB_CC_FLAGS}")
  foreach(flag IN LISTS MOUI_MOBILE_SKIA_STUB_FLAGS)
    target_compile_options(${MOUI_MOBILE_LIBRARY_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${flag}>")
  endforeach()
endif()

if(DEFINED MOUI_SKIA_CC_LINK_FLAGS AND NOT "${MOUI_SKIA_CC_LINK_FLAGS}" STREQUAL "")
  separate_arguments(MOUI_MOBILE_SKIA_LINK_FLAGS UNIX_COMMAND "${MOUI_SKIA_CC_LINK_FLAGS}")
endif()

target_link_libraries(${MOUI_MOBILE_LIBRARY_NAME}
  ${MOUI_MOBILE_SKIA_LINK_FLAGS}
  android
  log
  m
  dl
)
