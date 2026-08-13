cmake_minimum_required(VERSION 3.14)

project(runner LANGUAGES CXX)

# Flutter build configuration.
set(BINARY_NAME "pass_managers")
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# The Flutter tool provides these variables during the build.
# Keep this file in the repository; do not regenerate or delete it in CI.

# Configuration provided by the Flutter tool.
set(FLUTTER_EPHEMERAL_DIR "${FLUTTER_MANAGED_DIR}/ephemeral")

if(EXISTS "${FLUTTER_EPHEMERAL_DIR}/generated_config.cmake")
  include("${FLUTTER_EPHEMERAL_DIR}/generated_config.cmake")
endif()

# Flutter library and generated build rules.
add_subdirectory("${FLUTTER_MANAGED_DIR}")

# Application runner.
add_subdirectory("runner")

# Generated plugin build rules.
if(EXISTS "${FLUTTER_MANAGED_DIR}/generated_plugins.cmake")
  include("${FLUTTER_MANAGED_DIR}/generated_plugins.cmake")
endif()

# The Flutter tool normally supplies these variables. Define safe defaults for
# configuration parsing before the first generated build.
if(NOT DEFINED FLUTTER_VERSION)
  set(FLUTTER_VERSION "unknown")
endif()
if(NOT DEFINED FLUTTER_VERSION_MAJOR)
  set(FLUTTER_VERSION_MAJOR 0)
endif()
if(NOT DEFINED FLUTTER_VERSION_MINOR)
  set(FLUTTER_VERSION_MINOR 0)
endif()
if(NOT DEFINED FLUTTER_VERSION_PATCH)
  set(FLUTTER_VERSION_PATCH 0)
endif()
if(NOT DEFINED FLUTTER_VERSION_BUILD)
  set(FLUTTER_VERSION_BUILD 0)
endif()

# Standard installation/bundle layout used by Flutter Windows builds.
if(DEFINED BUILD_BUNDLE_DIR)
  set(_bundle_dir "${BUILD_BUNDLE_DIR}")
else()
  set(_bundle_dir "$<TARGET_FILE_DIR:${BINARY_NAME}>")
endif()

set(INSTALL_BUNDLE_DATA_DIR "${_bundle_dir}/data")
set(INSTALL_BUNDLE_LIB_DIR "${_bundle_dir}")

if(DEFINED FLUTTER_ICU_DATA_FILE)
  install(FILES "${FLUTTER_ICU_DATA_FILE}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)
endif()

if(DEFINED FLUTTER_LIBRARY)
  install(FILES "${FLUTTER_LIBRARY}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
if(DEFINED PROJECT_BUILD_DIR)
  install(CODE "
    file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)

  install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)
endif()

if(DEFINED AOT_LIBRARY)
  install(FILES "${AOT_LIBRARY}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    CONFIGURATIONS Profile;Release
    COMPONENT Runtime)
endif()
