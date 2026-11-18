cmake_minimum_required(VERSION 3.16)
project(TorWorkspaceNative LANGUAGES CXX)

find_package(Qt6 6.7 REQUIRED COMPONENTS Quick Qml)
set(CMAKE_AUTOMOC ON)
option(TOR_BUILD_CIRCUIT "Build the circuit painter" ON)
option(TOR_BUILD_GPU "Build the GPU exit lights" ON)
option(TOR_BUILD_PERFORMANCE "Build the optional frame probe" ON)

function(tor_module target directory source)
    add_library(${target} MODULE ${source})
    target_compile_features(${target} PRIVATE cxx_std_17)
    target_link_libraries(${target} PRIVATE Qt6::Quick Qt6::Qml)
    set_target_properties(${target} PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts/${directory}")
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE -O2)
    endif()
    configure_file(build-info.json.in
        "${CMAKE_BINARY_DIR}/artifacts/${directory}/build-info.json" @ONLY)
endfunction()

if(TOR_BUILD_CIRCUIT)
    tor_module(torcircuit circuit circuit/circuit.cpp)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        # Preserve the reference JavaScript operation order, including pixels.
        target_compile_options(torcircuit PRIVATE -ffp-contract=off)
    endif()
endif()

if(TOR_BUILD_GPU)
    find_package(Qt6 REQUIRED COMPONENTS ShaderTools)
    set(gpu "${CMAKE_CURRENT_SOURCE_DIR}/gpu")
    tor_module(torsparks gpu "${gpu}/Sparks.cpp")
    qt_add_shaders(torsparks sparks PREFIX "/sparks" BASE "${gpu}"
        GLSL "100 es,120,150" HLSL 50 MSL 12
        FILES "${gpu}/sparks.vert" "${gpu}/sparks.frag")
endif()

if(TOR_BUILD_PERFORMANCE)
    tor_module(torperformance performance performance/frameprobe.cpp)
endif()
