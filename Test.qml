// Test.qml — isolated scrolling test bed for diagnosing touchscreen input lag.
//
// To run instead of Main.qml, edit main.cpp:
//     engine.loadFromModule("Atlas", "Test");
// (and remember to change it back when done).
//
// What this strips away vs Main.qml:
//   • No custom fonts, FontLoader, or NativeRendering text
//   • No background image, no gradient
//   • No virtual keyboard, no TapHandler, no TextField
//   • No nested ListViews, no filtering, no data model
//   • No animations / Behaviors
// What it KEEPS (matching Main.qml's scroll setup exactly):
//   • ListView with cacheBuffer, clip, hidden scroll bars
//   • Same window dimensions
//   • spacing / topMargin / bottomMargin
//   • Variable-height delegates so layout work resembles real cards
//
// If scrolling feels laggy here, the bottleneck is your touchscreen
// driver / Qt event pipeline, not the Atlas UI.

import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: testRoot
    width: 1024
    height: 600
    visible: true
    title: "Scroll Test"
    color: "#0d0a08"

    // 80 dummy items. Enough to scroll for a while; alternating heights
    // and bright HSL colors so flicker / dropped frames are obvious.
    readonly property int itemCount: 80

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: testRoot.itemCount
        spacing: 12
        topMargin: 24
        bottomMargin: 24
        cacheBuffer: testRoot.height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

        delegate: Rectangle {
            width: list.width - 48
            x: 24
            // Vary heights so the scroll position isn't perfectly uniform —
            // real card layout is non-uniform too.
            height: 90 + (index % 4) * 35
            radius: 4
            // Rotate hue across all 80 so motion is unmistakable.
            color: Qt.hsla((index * 13 % 360) / 360, 0.55, 0.45, 1.0)
            border.color: "#ffffff"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Item " + (index + 1) + " / " + testRoot.itemCount
                color: "white"
                font.pixelSize: 28
                font.bold: true
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            // Index label in the corner, useful for spotting jitter or
            // missed frames as numbers fly past.
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 8
                text: "#" + (index + 1)
                color: "white"
                opacity: 0.7
                font.pixelSize: 14
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }
        }
    }
}
