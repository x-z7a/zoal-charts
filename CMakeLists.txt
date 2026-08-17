cmake_minimum_required(VERSION 3.20)

project(zoal-charts LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Stamped into the binary so a Log.txt line names the build it came from. CI
# passes the tag; a local build says 0.0.0-dev and means it.
set(ZOAL_CHARTS_VERSION "0.0.0-dev" CACHE STRING "Version reported by the plugin")

# Where the dependencies live. scripts/ensure-deps.sh provisions both, and the
# defaults match where it puts them.
set(XPLANE_SDK_ROOT "${CMAKE_SOURCE_DIR}/.cache/sdk" CACHE PATH "X-Plane SDK root")
set(SKYSCRIPT_ROOT "${CMAKE_SOURCE_DIR}/.cache/skyscript/SkyScript-lib" CACHE PATH "SkyScript library bundle")

# Fail here rather than at link time. A missing dependency is a provisioning
# step nobody ran, and saying so is more useful than an unresolved symbol.
if(NOT EXISTS "${XPLANE_SDK_ROOT}/CHeaders/XPLM/XPLMPlugin.h")
    message(FATAL_ERROR
        "X-Plane SDK not found at ${XPLANE_SDK_ROOT}. Run scripts/ensure-deps.sh, "
        "or pass -DXPLANE_SDK_ROOT=/path/to/SDK.")
endif()

if(NOT EXISTS "${SKYSCRIPT_ROOT}/include/skyscript_c.h")
    message(FATAL_ERROR
        "SkyScript library bundle not found at ${SKYSCRIPT_ROOT}. Run "
        "scripts/ensure-deps.sh to fetch the version pinned in "
        "scripts/skyscript-version.txt.")
endif()

if(APPLE)
    set(ZOAL_CHARTS_PLATFORM "mac_x64")
    set(SKYSCRIPT_LIBRARY_NAME "libSkyScriptLib.dylib")
elseif(WIN32)
    set(ZOAL_CHARTS_PLATFORM "win_x64")
    set(SKYSCRIPT_LIBRARY_NAME "SkyScriptLib.lib")
elseif(UNIX)
    set(ZOAL_CHARTS_PLATFORM "lin_x64")
    set(SKYSCRIPT_LIBRARY_NAME "libSkyScriptLib.so")
else()
    message(FATAL_ERROR "Unsupported platform.")
endif()

set(SKYSCRIPT_LIBRARY "${SKYSCRIPT_ROOT}/lib/${ZOAL_CHARTS_PLATFORM}/${SKYSCRIPT_LIBRARY_NAME}")
if(NOT EXISTS "${SKYSCRIPT_LIBRARY}")
    message(FATAL_ERROR "SkyScript library not found: ${SKYSCRIPT_LIBRARY}")
endif()

add_library(zoal-charts MODULE src/main.cpp)

target_include_directories(zoal-charts PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${SKYSCRIPT_ROOT}/include"
    "${XPLANE_SDK_ROOT}/CHeaders/XPLM"
)

# XPLM301 is what src/main.cpp asserts on; the rest opt into the newer APIs the
# SDK gates behind version defines.
target_compile_definitions(zoal-charts PRIVATE
    XPLM200 XPLM210 XPLM300 XPLM301 XPLM303 XPLM400
    ZOAL_CHARTS_VERSION="${ZOAL_CHARTS_VERSION}"
)

target_link_libraries(zoal-charts PRIVATE "${SKYSCRIPT_LIBRARY}")

# X-Plane loads plugins as <name>.xpl regardless of the platform convention, so
# the prefix and suffix are overridden rather than left to CMake.
set_target_properties(zoal-charts PROPERTIES
    PREFIX ""
    OUTPUT_NAME "zoal-charts"
    SUFFIX ".xpl"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${ZOAL_CHARTS_PLATFORM}"
)

# Visual Studio is a multi-config generator: it appends /<Config> to the output
# directory above, which would put the .xpl somewhere packaging does not look.
# Pinning every config to the same directory keeps one path on all platforms.
foreach(config IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "${config}" config_upper)
    set_target_properties(zoal-charts PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY_${config_upper} "${CMAKE_BINARY_DIR}/${ZOAL_CHARTS_PLATFORM}"
        RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${CMAKE_BINARY_DIR}/${ZOAL_CHARTS_PLATFORM}"
    )
endforeach()

if(APPLE)
    target_compile_definitions(zoal-charts PRIVATE APL=1 IBM=0 LIN=0)
    target_link_libraries(zoal-charts PRIVATE
        "-F${XPLANE_SDK_ROOT}/Libraries/Mac"
        "-framework XPLM"
    )
    # The SkyScript dylib is installed beside the .xpl, and its install name is
    # @rpath/libSkyScriptLib.dylib, so @loader_path is what resolves it. Without
    # this the plugin builds and then fails to load in the sim.
    set_target_properties(zoal-charts PROPERTIES
        INSTALL_RPATH "@loader_path"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
elseif(WIN32)
    target_compile_definitions(zoal-charts PRIVATE APL=0 IBM=1 LIN=0)
    target_link_libraries(zoal-charts PRIVATE
        "${XPLANE_SDK_ROOT}/Libraries/Win/XPLM_64.lib"
    )
else()
    target_compile_definitions(zoal-charts PRIVATE APL=0 IBM=0 LIN=1)
    # No XPLM library is linked on Linux: X-Plane resolves those symbols itself
    # when it loads the plugin, and a shared object may leave them undefined.
    set_target_properties(zoal-charts PROPERTIES
        INSTALL_RPATH "$ORIGIN"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
endif()
