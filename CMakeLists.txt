cmake_minimum_required(VERSION 3.16)

project(Atlas VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# VirtualKeyboard is only needed at link-time when the Qt Creator module
# build is used.  On Pi the QML plugin is loaded dynamically at runtime, so
# the dev package is not required for a successful cmake/make.
find_package(Qt6 REQUIRED COMPONENTS Quick)
find_package(Qt6 OPTIONAL_COMPONENTS VirtualKeyboard)

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(appAtlas
    main.cpp
    fileio.h
)

qt_policy(SET QTP0001 NEW)

qt_add_qml_module(appAtlas
    URI Atlas
    QML_FILES
        Main.qml
        Test.qml
        drinks.js
    RESOURCES
        images/gradient.png
        fonts/bodonimoda-variable.ttf
        fonts/jetbrainsmono-variable.ttf
        fonts/outfit-variable.ttf
)

set_target_properties(appAtlas PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appAtlas PRIVATE Qt6::Quick)
if(Qt6VirtualKeyboard_FOUND)
    target_link_libraries(appAtlas PRIVATE Qt6::VirtualKeyboard)
endif()

install(TARGETS appAtlas
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
