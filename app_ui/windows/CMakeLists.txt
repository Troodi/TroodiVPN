# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(xray_desktop_ui LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "xray_desktop_ui")
set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(CORE_MANAGER_DIR "${REPO_ROOT}/core_manager")
set(CORE_MANAGER_BINARY "${CORE_MANAGER_DIR}/bin/core-manager.exe")
set(XRAY_RUNTIME_DIR "${REPO_ROOT}/xray_runtime/bin/windows")
set(XRAY_BINARY "${XRAY_RUNTIME_DIR}/xray.exe")
set(WINTUN_BINARY "${XRAY_RUNTIME_DIR}/wintun.dll")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

execute_process(
  COMMAND go build -ldflags -H=windowsgui -o "${CORE_MANAGER_BINARY}" .\\cmd\\core-manager
  WORKING_DIRECTORY "${CORE_MANAGER_DIR}"
  RESULT_VARIABLE CORE_MANAGER_BUILD_RESULT
)
if(NOT CORE_MANAGER_BUILD_RESULT EQUAL 0)
  message(FATAL_ERROR "Failed to build core-manager.exe")
endif()

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# CMake's file(INSTALL) often hits "Permission denied" overwriting locked EXEs/DLLs.
# Use taskkill + delete + cmake -E copy into the same prefix as the app binary.
if(WIN32)
  install(CODE "
    execute_process(COMMAND \"\$ENV{SYSTEMROOT}/System32/taskkill.exe\" /F /IM \"${BINARY_NAME}.exe\" /T ERROR_QUIET OUTPUT_QUIET)
    execute_process(COMMAND \"\$ENV{SYSTEMROOT}/System32/taskkill.exe\" /F /IM core-manager.exe /T ERROR_QUIET OUTPUT_QUIET)
    execute_process(COMMAND \"\$ENV{SYSTEMROOT}/System32/taskkill.exe\" /F /IM xray.exe /T ERROR_QUIET OUTPUT_QUIET)
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E remove -f \"\${CMAKE_INSTALL_PREFIX}/core-manager.exe\")
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E remove -f \"\${CMAKE_INSTALL_PREFIX}/xray.exe\")
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E remove -f \"\${CMAKE_INSTALL_PREFIX}/wintun.dll\")
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy \"${CORE_MANAGER_BINARY}\" \"\${CMAKE_INSTALL_PREFIX}/core-manager.exe\")
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy \"${XRAY_BINARY}\" \"\${CMAKE_INSTALL_PREFIX}/xray.exe\")
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy \"${WINTUN_BINARY}\" \"\${CMAKE_INSTALL_PREFIX}/wintun.dll\")
  " COMPONENT Runtime)
else()
  install(FILES
    "${CORE_MANAGER_BINARY}"
    "${XRAY_BINARY}"
    "${WINTUN_BINARY}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
