cmake_minimum_required(VERSION 3.16)
project(atlas LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Gui Qml Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBDRM REQUIRED libdrm)

add_executable(atlas main.cpp)

target_include_directories(atlas PRIVATE ${LIBDRM_INCLUDE_DIRS})
target_link_libraries(atlas PRIVATE
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    ${LIBDRM_LIBRARIES}
)
