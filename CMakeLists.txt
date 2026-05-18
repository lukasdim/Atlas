cmake_minimum_required(VERSION 3.16)

project(Atlas VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick VirtualKeyboard)

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(appAtlas
    main.cpp
)

qt_policy(SET QTP0001 NEW)

qt_add_qml_module(appAtlas
    URI Atlas
    QML_FILES
        Main.qml
    RESOURCES
        images/gradient.png
        fonts/bodonimoda-variable.ttf
        fonts/jetbrainsmono-variable.ttf
        fonts/outfit-variable.ttf
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appAtlas PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appAtlas
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appAtlas
    PRIVATE Qt6::Quick Qt6::VirtualKeyboard
)

install(TARGETS appAtlas
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
