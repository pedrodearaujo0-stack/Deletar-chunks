cmake_minimum_required(VERSION 3.18.1)
project(chunktool_leveldb)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# A pasta leveldb-mcpe eh clonada pelo workflow do GitHub Actions antes
# do Gradle rodar (ver .github/workflows/build-apk.yml).
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/leveldb-mcpe ${CMAKE_CURRENT_BINARY_DIR}/leveldb-mcpe-build)

add_library(chunktool_leveldb SHARED
    leveldb_jni.cpp
)

target_include_directories(chunktool_leveldb PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/leveldb-mcpe/include
)

find_library(log-lib log)
find_library(z-lib z)

target_link_libraries(chunktool_leveldb
    leveldb-mcpe
    ${log-lib}
    ${z-lib}
)
