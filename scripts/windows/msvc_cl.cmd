@echo off
setlocal EnableExtensions

set "MOUI_CL_ORIGINAL_ARGS=%*"
set "MOUI_CL_NEEDS_C11="
set "MOUI_CL_HAS_CPP="

:scan
if "%~1"=="" goto invoke
set "MOUI_CL_EXT=%~x1"
if /I "%MOUI_CL_EXT%"==".c" set "MOUI_CL_NEEDS_C11=1"
if /I "%MOUI_CL_EXT%"==".cc" set "MOUI_CL_HAS_CPP=1"
if /I "%MOUI_CL_EXT%"==".cpp" set "MOUI_CL_HAS_CPP=1"
if /I "%MOUI_CL_EXT%"==".cxx" set "MOUI_CL_HAS_CPP=1"
shift
goto scan

:invoke
if defined MOUI_CL_NEEDS_C11 if not defined MOUI_CL_HAS_CPP (
  cl /std:c11 /experimental:c11atomics %MOUI_CL_ORIGINAL_ARGS%
) else (
  cl %MOUI_CL_ORIGINAL_ARGS%
)
exit /b %ERRORLEVEL%
