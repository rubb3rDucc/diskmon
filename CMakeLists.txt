cmake_minimum_required(VERSION 3.25)

project(diskmon
    VERSION 0.1.0
    DESCRIPTION "Disk-usage watchdog that pauses qBittorrent when a disk fills up"
    LANGUAGES CXX
)

set(CMAKE_CXX_EXTENSIONS OFF)

option(DISKMON_SANITIZE "Enable Address + UndefinedBehavior sanitizers" OFF)

add_executable(diskmon src/main.cpp)

target_compile_features(diskmon PRIVATE cxx_std_20)

target_compile_options(diskmon PRIVATE
    -Wall -Wextra -Wpedantic
    -Wshadow
    -Wconversion
    -Wsign-conversion
)

if(DISKMON_SANITIZE)
    target_compile_options(diskmon PRIVATE
        -fsanitize=address,undefined
        -fno-omit-frame-pointer
        -g
    )
    target_link_options(diskmon PRIVATE -fsanitize=address,undefined)
endif()
