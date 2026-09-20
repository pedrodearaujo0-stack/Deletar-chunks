cmake_minimum_required(VERSION 3.18.1)
project(chunktool_leveldb)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# A pasta leveldb-mcpe eh clonada pelo workflow do GitHub Actions antes
# do Gradle rodar (ver .github/workflows/build-apk.yml).
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/leveldb-mcpe ${CMAKE_CURRENT_BINARY_DIR}/leveldb-mcpe-build)

# A cubiomes nao tem CMakeLists proprio usavel aqui, entao compilamos os
# arquivos .c dela direto como parte da nossa biblioteca.
file(GLOB CUBIOMES_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/cubiomes/*.c")

add_library(chunktool_leveldb SHARED
    leveldb_jni.cpp
    ${CUBIOMES_SOURCES}
)

target_include_directories(chunktool_leveldb PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/leveldb-mcpe/include
    ${CMAKE_CURRENT_SOURCE_DIR}/cubiomes
)

find_library(log-lib log)
find_library(z-lib z)

target_link_libraries(chunktool_leveldb
    leveldb-mcpe
    ${log-lib}
    ${z-lib}
)
