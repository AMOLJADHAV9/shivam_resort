# ================================
#  Project Configuration
# ================================
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
cmake_minimum_required(VERSION 3.14)
project(shivam_resorts LANGUAGES CXX)

# Use modern CMake policies
cmake_policy(SET CMP0012 NEW)
cmake_policy(VERSION 3.14)

# Executable name
set(BINARY_NAME "shivam_resorts")

# ================================
#  Build Configuration
# ================================

# Detect multi-config generators (Visual Studio)
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
      CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug"
        CACHE STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
                 "Debug" "Profile" "Release")
  endif()
endif()

# Profile mode settings (same as Release)
set(CMAKE_EXE_LINKER_FLAGS_PROFILE   "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE            "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE          "${CMAKE_CXX_FLAGS_RELEASE}")

# ================================
#  Global Definitions
# ================================

# Enable Unicode
add_definitions(-DUNICODE -D_UNICODE)

# ================================
#  Standard Target Settings
# ================================

function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)

  # Compiler warnings
  target_compile_options(${TARGET} PRIVATE
    /W4
    /wd4100
    /EHsc
  )

  # Disable C++ exceptions (Flutter default)
  target_compile_definitions(${TARGET} PRIVATE
    "_HAS_EXCEPTIONS=0"
    "$<$<CONFIG:Debug>:_DEBUG>"
  )
endfunction()

# ================================
#  Flutter Build Rules
# ================================

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application runner
add_subdirectory("runner")

# Generated plugin rules
include(flutter/generated_plugins.cmake)

# ================================
#  Installation Configuration
# ================================

# Bundle directory
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")

# Make install step default for Visual Studio
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}"
      CACHE PATH "Install path" FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR  "${CMAKE_INSTALL_PREFIX}")

# Install executable
install(TARGETS ${BINARY_NAME}
        RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

# Install Flutter ICU data
install(FILES "${FLUTTER_ICU_DATA_FILE}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        COMPONENT Runtime)

# Install Flutter engine library
install(FILES "${FLUTTER_LIBRARY}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

# Install plugin bundled libraries
if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
          DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
          COMPONENT Runtime)
endif()

# Native assets
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

# Re-copy Flutter assets to avoid stale files
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")

install(CODE "
  file(REMOVE_RECURSE
  \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
" COMPONENT Runtime)

install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        COMPONENT Runtime)

# Install AOT library (Profile & Release only)
install(FILES "${AOT_LIBRARY}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        CONFIGURATIONS Profile;Release
        COMPONENT Runtime)