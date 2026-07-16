cmake_minimum_required(VERSION 3.22)
project(showcase_android LANGUAGES C CXX)

if(NOT DEFINED MOUI_ROOT)
  message(FATAL_ERROR "MOUI_ROOT must point at the published MoUI package root")
endif()

include("${MOUI_ROOT}/mobile/android/cmake/MoUIMobileAndroid.cmake")
