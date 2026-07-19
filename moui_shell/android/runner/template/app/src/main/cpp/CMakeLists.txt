cmake_minimum_required(VERSION 3.22)
project(moui_embedding_android LANGUAGES C CXX)

if(NOT DEFINED MOUI_ROOT OR NOT DEFINED MOUI_SHELL_ROOT)
  message(FATAL_ERROR "MOUI_ROOT and MOUI_SHELL_ROOT must point at matching published packages")
endif()

include("${MOUI_SHELL_ROOT}/android/embedder/cmake/MoUIShellAndroid.cmake")
