cmake_minimum_required(VERSION 3.22)
project(showcase_harmonyos LANGUAGES C CXX)

if(NOT DEFINED MOUI_ROOT)
  if(DEFINED ENV{MOUI_PACKAGE_ROOT} AND NOT "$ENV{MOUI_PACKAGE_ROOT}" STREQUAL "")
    set(MOUI_ROOT "$ENV{MOUI_PACKAGE_ROOT}")
  else()
    get_filename_component(MOUI_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../.mooncakes/wzzc-dev/moui" ABSOLUTE)
  endif()
endif()

include("${MOUI_ROOT}/mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake")
