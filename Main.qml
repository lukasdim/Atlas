import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import "drinks.js" as DrinksDB

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Cocktail Atlas"

    background: Image {
        source: "images/gradient.png"
        fillMode: Image.Stretch
        asynchronous: true
        cache: true
    }
    
    // ===================== THEME =====================
    readonly property color bgDark:     "#0d0a08"
    readonly property color cream:      "#e8ddc7"
    readonly property color creamHi:    "#f5ead0"
    readonly property color gold:       "#d4a85f"
    readonly property color goldFaint:  Qt.rgba(0.83, 0.66, 0.37, 0.25)
    readonly property color goldGhost:  Qt.rgba(0.83, 0.66, 0.37, 0.15)
    readonly property color goldBright: Qt.rgba(0.83, 0.66, 0.37, 0.85)
    readonly property color creamWash:  Qt.rgba(0.91, 0.87, 0.78, 0.04)
    readonly property color hairline:   Qt.rgba(0.91, 0.87, 0.78, 0.10)
    readonly property color orange:     "#d4622a"

    FontLoader { id: displayFont; source: "fonts/bodonimoda-variable.ttf" }
    FontLoader { id: bodyFont;    source: "fonts/outfit-variable.ttf" }
    FontLoader { id: monoFont;    source: "fonts/jetbrainsmono-variable.ttf" }

    readonly property string fontDisplay:     displayFont.status === FontLoader.Ready ? displayFont.name : "Times New Roman"
    readonly property string fontDisplayBold: fontDisplay
    readonly property string fontBody:        bodyFont.status    === FontLoader.Ready ? bodyFont.name    : "Helvetica"
    readonly property string fontMono:        monoFont.status    === FontLoader.Ready ? monoFont.name    : "Courier New"

    // ===================== STATE =====================
    property string activeCategory: "All"
    property string searchText: ""
    property bool   categoriesExpanded: false
    readonly property var currentGroups: filteredGroups()
    readonly property int cardCols: root.width > 720 ? 2 : 1
    readonly property int firstRowCount: 5

    // Drink data and altered-recipe state
    property var drinks: []
    property var alteredRecipes: ({})
    property var preferredVersions: ({})
    property var openDrink: null

    // Add-new-cocktail panel state
    property bool   addPanelOpen:      false
    property string newDrinkCategory:  ""

    // File I/O helper (C++ QML_ELEMENT registered to the Atlas module)
    FileIO { id: io }

    // Working model for editable ingredients while the detail panel is open
    ListModel { id: alteredIngredientsModel }

    // Working model for ingredient rows in the "add new cocktail" panel
    ListModel { id: newDrinkIngredientsModel }

    // Debounce search input so filteredGroups() (which also runs
    // buildCardRows for every category) fires at most once per 200 ms
    // instead of on every keystroke — critical on the Pi's single-core.
    Timer {
        id: searchDebounce
        interval: 200
        repeat: false
        onTriggered: root.searchText = searchField.text
    }

    // ===================== STARTUP =====================
    // On first run: drinks.json doesn't exist yet → use bundled defaults.
    // On subsequent runs: load from the saved file so alterations persist.
    Component.onCompleted: {
        var saved = io.read(io.drinksPath)
        if (saved.length > 0)
            loadDrinksJson(saved)
        else
            drinks = DrinksDB.data
    }

    // Parses a full drinks JSON string (which may include "altered"/"pref"
    // fields added by saveDetailPanel) and restores all state.
    function loadDrinksJson(jsonText) {
        var raw = JSON.parse(jsonText)
        var loadedDrinks  = []
        var loadedAltered = {}
        var loadedPrefs   = {}
        for (var i = 0; i < raw.length; i++) {
            var d = raw[i]
            loadedDrinks.push({ n: d.n, s: d.s, c: d.c, p: d.p, i: d.i })
            if (d.altered) loadedAltered[d.n] = d.altered
            if (d.pref)    loadedPrefs[d.n]   = d.pref
        }
        drinks           = loadedDrinks
        alteredRecipes   = loadedAltered
        preferredVersions = loadedPrefs
    }

    // ===================== DATA =====================
    readonly property var categoryOrder: [
        "Spritz & Bubbles", "Margaritas & Agave", "Tropical & Tiki",
        "Sours & Citrus",   "Floral & Botanical", "Stirred & Spirit-Forward",
        "Dessert & Cream",  "Coffee",             "Spirited Coffee",
        "Aperitifs (Neat)"
    ]

    readonly property var categoryBlurbs: ({
        "Spritz & Bubbles":          "Prosecco-led, low-ABV, aperitif builds. Light, fizzy, citrus-driven.",
        "Margaritas & Agave":        "Tequila & mezcal forward. Lime, agave, occasional heat or smoke.",
        "Tropical & Tiki":           "Rum-led, coconut, pineapple, passionfruit. Beach-leaning.",
        "Sours & Citrus":            "Vodka or gin shaken with citrus and a fruit or floral modifier.",
        "Floral & Botanical":        "Gin-forward, elderflower, violet, bergamot. Restrained sweetness.",
        "Stirred & Spirit-Forward":  "Boozy, undiluted by juice. Old Fashioned and Martini families.",
        "Dessert & Cream":           "Chocolate, hazelnut, caramel, cream. Drink-as-dessert.",
        "Coffee":                    "Lavazza espresso drinks, non-alcoholic.",
        "Spirited Coffee":           "Espresso plus a spirit or liqueur.",
        "Aperitifs (Neat)":          "Bitter Italian aperitivos served straight."
    })

    // ===================== FILTER / GROUP LOGIC =====================
    function filteredGroups() {
        // Reading cardCols here registers it as a binding dependency so
        // currentGroups automatically recomputes on a window-width change.
        var cols = cardCols

        var list = drinks
        if (activeCategory !== "All")
            list = list.filter(function(d) { return d.c === activeCategory })

        // Trim once; calling trim() + toLowerCase() inside the hot filter
        // loop would allocate a new string per drink per keystroke.
        var trimmed = searchText.trim()
        if (trimmed.length > 0) {
            var q = trimmed.toLowerCase()
            list = list.filter(function(d) {
                if (d.n.toLowerCase().indexOf(q) >= 0) return true
                for (var k = 0; k < d.i.length; k++)
                    if (d.i[k][0].toLowerCase().indexOf(q) >= 0) return true
                return false
            })
        }

        var groups = {}
        for (var j = 0; j < list.length; j++) {
            var d = list[j]
            if (!groups[d.c]) groups[d.c] = []
            groups[d.c].push(d)
        }

        // Build cardRows here (once, at filter time) rather than inside
        // each ListView delegate (scroll time).  Delegates then do a
        // simple property read: modelData.cardRows — zero JS per scroll.
        var out = []
        for (var ci = 0; ci < categoryOrder.length; ci++) {
            var cat = categoryOrder[ci]
            if (groups[cat]) out.push({
                category: cat,
                drinks:   groups[cat],
                cardRows: buildCardRows(groups[cat], cols)
            })
        }
        return out
    }

    readonly property var categoryCounts: {
        var counts = { "All": drinks.length }
        for (var i = 0; i < drinks.length; i++) {
            var c = drinks[i].c
            counts[c] = (counts[c] || 0) + 1
        }
        return counts
    }

    function buildCardRows(rowDrinks, cols) {
        var rows = []
        for (var i = 0; i < rowDrinks.length; i += cols) {
            var batch = []
            var maxIng = 0
            for (var j = 0; j < cols && (i + j) < rowDrinks.length; j++) {
                batch.push(rowDrinks[i + j])
                if (rowDrinks[i + j].i.length > maxIng)
                    maxIng = rowDrinks[i + j].i.length
            }
            rows.push({ drinks: batch, maxIngredients: maxIng })
        }
        return rows
    }

    // ===================== ALTERED RECIPE HELPERS =====================
    function setPreferredVersion(drinkName, version) {
        var v = Object.assign({}, preferredVersions)
        v[drinkName] = version
        preferredVersions = v
    }

    // Serialises the current drinks + any altered/pref metadata to a JS
    // array ready for JSON.stringify().  Shared by saveDetailPanel and
    // saveNewDrink so the file format stays consistent.
    function buildSaveOutput() {
        var output = []
        for (var j = 0; j < drinks.length; j++) {
            var d    = drinks[j]
            var entry = { n: d.n, s: d.s, c: d.c, p: d.p, i: d.i }
            var alt  = alteredRecipes[d.n]
            var pref = preferredVersions[d.n]
            if (alt)  entry.altered = alt
            if (pref && pref !== "default") entry.pref = pref
            output.push(entry)
        }
        return output
    }

    // Opens the detail panel and seeds the editable model.
    // Closes the add panel first if it happens to be open.
    function openDetailPanel(drink) {
        if (addPanelOpen) addPanelOpen = false
        alteredIngredientsModel.clear()
        var src = alteredRecipes[drink.n] || drink.i
        for (var i = 0; i < src.length; i++)
            alteredIngredientsModel.append({ ingName: src[i][0], ingAmount: src[i][1] })
        openDrink = drink
    }

    // Save: persist altered edits to memory + write the full dataset to
    // drinks.json next to the executable.
    function saveDetailPanel() {
        var drinkName = openDrink.n
        var newIngredients = []
        for (var i = 0; i < alteredIngredientsModel.count; i++) {
            var item = alteredIngredientsModel.get(i)
            newIngredients.push([item.ingName, item.ingAmount])
        }
        var newAltered = Object.assign({}, alteredRecipes)
        newAltered[drinkName] = newIngredients
        alteredRecipes = newAltered
        io.write(io.drinksPath, JSON.stringify(buildSaveOutput(), null, 2))
        openDrink = null
    }

    // Cancel: discard unsaved edits and close.
    function cancelDetailPanel() {
        openDrink = null
    }

    // ===================== ADD NEW COCKTAIL HELPERS =====================
    function openAddPanel() {
        if (openDrink !== null) openDrink = null   // close detail panel first
        searchField.focus = false
        Qt.inputMethod.hide()
        newDrinkCategory = root.categoryOrder[0]
        newDrinkIngredientsModel.clear()
        newDrinkIngredientsModel.append({ ingName: "", ingAmount: "" })
        newDrinkIngredientsModel.append({ ingName: "", ingAmount: "" })
        newDrinkIngredientsModel.append({ ingName: "", ingAmount: "" })
        addPanelOpen = true
    }

    function cancelAddPanel() {
        Qt.inputMethod.hide()
        addPanelOpen = false
    }

    // Called by the Add Drink button inside the panel; receives validated
    // values already read from the TextFields.
    function saveNewDrink(name, source, price, ingredients) {
        var newDrinkObj = {
            n: name, s: source,
            c: newDrinkCategory,
            p: price,
            i: ingredients
        }
        var newDrinks = drinks.slice()
        newDrinks.push(newDrinkObj)
        drinks = newDrinks                                         // triggers currentGroups + categoryCounts
        io.write(io.drinksPath, JSON.stringify(buildSaveOutput(), null, 2))
        Qt.inputMethod.hide()
        addPanelOpen = false
    }

    // ===================== INLINE COMPONENTS =====================

    component CategoryChip: Rectangle {
        id: chip
        property string label: ""
        property int chipCount: 0
        property bool active: false
        property bool hovered: false
        signal clicked()

        radius: 2
        color: active ? (chipMA.pressed ? Qt.darker(root.gold, 1.15) : root.gold)
                      : (chipMA.pressed ? root.goldFaint : "transparent")
        border.color: active ? root.gold : ((hovered || chipMA.pressed) ? root.gold : root.goldFaint)
        border.width: 1
        implicitHeight: 44
        implicitWidth: chipRow.implicitWidth + 24

        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: chip.label
                font.family: root.fontDisplayBold
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
                color: chip.active ? root.bgDark : root.cream
            }
            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: chip.chipCount
                font.family: root.fontDisplayBold
                font.pixelSize: 12
                font.weight: Font.Bold
                color: chip.active ? root.bgDark : root.cream
                opacity: 0.55
            }
        }

        MouseArea {
            id: chipMA
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                chip.clicked()
                Qt.inputMethod.hide()
            }
            onEntered: chip.hovered = true
            onExited:  chip.hovered = false
        }
    }

    component ExpandToggle: Rectangle {
        id: toggle
        property bool expanded: false
        property bool hovered: false
        signal clicked()

        radius: 2
        implicitHeight: 44
        implicitWidth: toggleRow.implicitWidth + 22

        color: toggleMA.pressed ? Qt.darker(root.gold, 1.15) : (hovered ? root.creamHi : root.gold)
        border.color: root.gold
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            id: toggleRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: toggle.expanded ? "Less" : "More"
                font.family: root.fontDisplayBold
                font.pixelSize: 14
                font.weight: Font.Bold
                font.italic: true
                color: root.bgDark
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: toggle.expanded ? "−" : "+"
                font.family: root.fontDisplayBold
                font.pixelSize: 16
                font.weight: Font.Bold
                color: root.bgDark
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: toggleMA
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                toggle.clicked()
                Qt.inputMethod.hide()
            }
            onEntered: toggle.hovered = true
            onExited:  toggle.hovered = false
        }
    }

    component DrinkCard: Rectangle {
        id: card
        property var drink: ({})
        property int forcedIngredients: 0
        property bool hovered: false
        signal clicked()

        // Shows altered or default ingredients based on user preference
        readonly property var effectiveIngredients: {
            if (!drink.n) return []
            var pref = root.preferredVersions[drink.n] || "default"
            if (pref === "altered") {
                var alt = root.alteredRecipes[drink.n]
                if (alt) return alt
            }
            return drink.i || []
        }

        readonly property int actualIngredients: effectiveIngredients.length
        readonly property int rowH: 42
        readonly property int padV: 22
        readonly property int padH: 22

        radius: 2
        color: root.creamWash
        border.color: hovered ? Qt.rgba(0.83, 0.66, 0.37, 0.45) : root.goldGhost
        border.width: 1

        implicitHeight: {
            var n = Math.max(actualIngredients, forcedIngredients)
            return padV
                 + cardHeader.implicitHeight
                 + 6
                 + sourceText.implicitHeight + sourceText.bottomPadding
                 + (n * rowH)
                 + padV
        }

        Behavior on border.color { ColorAnimation { duration: 250 } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: card.hovered = true
            onExited:  card.hovered = false
            onClicked: card.clicked()
        }

        // Gold dot when the altered version is set as the active view
        Rectangle {
            visible: (root.preferredVersions[card.drink.n] || "default") === "altered"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            width: 7; height: 7; radius: 4
            color: root.gold
            opacity: 0.85
        }

        Column {
            id: cardCol
            x: card.padH; y: card.padV
            width: parent.width - 2 * card.padH
            spacing: 6

            Item {
                id: cardHeader
                width: parent.width
                implicitHeight: Math.max(nameText.implicitHeight, priceText.implicitHeight + 4)

                Text {
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    id: nameText
                    anchors.left: parent.left
                    anchors.right: priceText.left
                    anchors.rightMargin: 14
                    text: card.drink.n || ""
                    font.family: root.fontDisplayBold
                    font.weight: Font.Bold
                    font.pixelSize: 28
                    color: root.creamHi
                    wrapMode: Text.WordWrap
                }
                Text {
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    id: priceText
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    text: "$" + (card.drink.p || 0)
                    font.family: root.fontMono
                    font.pixelSize: 14
                    color: root.gold
                }
            }

            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                id: sourceText
                width: parent.width
                height: 0
                property int implicitHeight: 16
                property int bottomPadding: 24
            }

            Repeater {
                model: card.effectiveIngredients
                delegate: Item {
                    width: cardCol.width
                    height: card.rowH

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.hairline
                        visible: index < (card.effectiveIngredients.length - 1)
                    }
                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        font.family: root.fontBody
                        font.pixelSize: 18
                        color: root.cream
                    }
                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.family: root.fontMono
                        font.pixelSize: 18
                        color: modelData[1] ? root.gold : root.cream
                        opacity: 0.78
                    }
                }
            }
        }
    }

    // ===================== LAYOUT =====================
    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: inputPanel.active ? inputPanel.height : 0
        spacing: 0

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        // ---------- Header ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: headerCol.implicitHeight + 32

            Column {
                id: headerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 28
                spacing: 16
                Text {
                    text: "The <i>Cocktail</i> Atlas"
                    textFormat: Text.RichText
                    font.family: root.fontDisplay
                    font.pixelSize: 48
                    lineHeight: 0.92
                    color: root.creamHi
                }
                Text {
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    text: root.drinks.length + " drinks · " + root.categoryOrder.length + " categories"
                    font.family: root.fontDisplayBold
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.italic: true
                    color: root.cream
                    opacity: 0.55
                }
            }

            // Text items don't consume pointer events, so this MouseArea
            // receives every tap on the banner and dismisses the keyboard.
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    searchField.focus = false
                    Qt.inputMethod.hide()
                }
            }

            // Orange "Add" button — sits on top of the dismiss MouseArea so
            // it captures its own clicks without triggering the dismiss.
            Rectangle {
                id: addDrinkHeaderBtn
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                width: addDrinkHeaderLabel.implicitWidth + 28
                height: 38
                radius: 2
                color: addDrinkHeaderMA.pressed        ? Qt.darker(root.orange, 1.2)
                     : addDrinkHeaderMA.containsMouse  ? Qt.lighter(root.orange, 1.12)
                     : root.orange
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: addDrinkHeaderLabel
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: "+ Add"
                    font.family: root.fontDisplayBold
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "white"
                }
                MouseArea {
                    id: addDrinkHeaderMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAddPanel()
                }
            }
        }

        // ---------- Search + chips ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: stickyCol.implicitHeight + 32

            Column {
                id: stickyCol
                x: 28; y: 14
                width: parent.width - 56
                spacing: 12

                TextField {
                    id: searchField
                    width: parent.width
                    placeholderText: "Search drinks or ingredients…"
                    color: root.cream
                    placeholderTextColor: Qt.rgba(0.91, 0.87, 0.78, 0.4)
                    font.family: root.fontBody
                    font.pixelSize: 14
                    selectByMouse: true
                    padding: 12
                    background: Rectangle {
                        color: root.creamWash
                        border.color: Qt.rgba(0.83, 0.66, 0.37, 0.2)
                        radius: 2
                    }
                    onTextChanged: searchDebounce.restart()
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    CategoryChip {
                        label: "All"
                        chipCount: root.categoryCounts["All"] || 0
                        active: root.activeCategory === "All"
                        onClicked: root.activeCategory = "All"
                    }
                    Repeater {
                        model: root.categoryOrder.slice(0, root.firstRowCount)
                        delegate: CategoryChip {
                            label: modelData
                            chipCount: root.categoryCounts[modelData] || 0
                            active: root.activeCategory === modelData
                            onClicked: root.activeCategory = modelData
                        }
                    }
                    ExpandToggle {
                        expanded: root.categoriesExpanded
                        onClicked: root.categoriesExpanded = !root.categoriesExpanded
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 7
                    visible: root.categoriesExpanded

                    Repeater {
                        model: root.categoryOrder.slice(root.firstRowCount)
                        delegate: CategoryChip {
                            label: modelData
                            chipCount: root.categoryCounts[modelData] || 0
                            active: root.activeCategory === modelData
                            onClicked: root.activeCategory = modelData
                        }
                    }
                }
            }
        }

        // ---------- Scrollable content ----------
        ListView {
            id: mainList
            Layout.preferredWidth: Math.min(parent.width - 32, 1226)
	    Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            clip: true
            model: root.currentGroups
            spacing: 44
            topMargin: 32
            bottomMargin: 72
            // Keep ~one card-height's worth of pre-built delegates on each
            // side of the viewport.  root.height (800 px) was twice as
            // much as needed and doubled the Pi's delegate-creation work.
            cacheBuffer: 360
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

            TapHandler {
                onTapped: {
                    searchField.focus = false
                    Qt.inputMethod.hide()
                }
            }

            delegate: Column {
                width: mainList.width - 56
                x: 28
                spacing: 12

                Item {
                    width: parent.width
                    height: 56
                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        text: modelData.category
                        font.family: root.fontDisplay
                        font.pixelSize: 36
                        color: root.creamHi
                    }
                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        text: modelData.drinks.length + (modelData.drinks.length === 1 ? " DRINK" : " DRINKS")
                        font.family: root.fontDisplayBold
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 1.6
                        color: root.cream
                        opacity: 0.55
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.goldFaint
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.categoryBlurbs[modelData.category] || ""
                    font.family: root.fontBody
                    font.italic: true
                    font.pixelSize: 13
                    color: root.cream
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                    bottomPadding: 12
                }

                ListView {
                    id: cardsListView
                    width: parent.width
                    height: contentHeight
                    spacing: 16
                    interactive: false
                    // cardRows is pre-computed inside filteredGroups() so
                    // no JS runs here at scroll time — pure property read.
                    model: modelData.cardRows

                    delegate: Row {
                        id: cardRow
                        width: ListView.view.width
                        spacing: 16
                        property var rowData: modelData

                        Repeater {
                            model: cardRow.rowData.drinks
                            delegate: DrinkCard {
                                width: (cardRow.width - cardRow.spacing * (root.cardCols - 1)) / root.cardCols
                                drink: modelData
                                forcedIngredients: cardRow.rowData.maxIngredients
                                onClicked: root.openDetailPanel(modelData)
                            }
                        }
                    }
                }
            }

            footer: Column {
                width: mainList.width
                spacing: 0

                Item {
                    x: 28
                    width: mainList.width - 56
                    height: root.currentGroups.length === 0 ? 220 : 0
                    visible: root.currentGroups.length === 0
                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "Nothing matches. Try another search."
                        font.family: root.fontDisplay
                        font.italic: true
                        font.pixelSize: 24
                        color: root.cream
                        opacity: 0.5
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    x: 28
                    width: mainList.width - 56
                    text: "Portions are estimates based on standard bartending conventions —\nactual ship pours vary by bar and bartender."
                    font.family: root.fontDisplayBold
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.italic: true
                    color: root.cream
                    opacity: 0.45
                    topPadding: 28
                }
            }
        }
    }

    // ===================== DETAIL OVERLAY =====================
    Shortcut {
        sequence: "Escape"
        enabled: root.openDrink !== null
        onActivated: root.cancelDetailPanel()
    }

    Item {
        id: detailOverlay
        anchors.fill: parent
        z: 20
        opacity: root.openDrink !== null ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        // Backdrop — clicking outside cancels (discards unsaved edits)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.05, 0.04, 0.03, 0.88)
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Qt.inputMethod.hide()
                    root.cancelDetailPanel()
                }
            }
        }

        // Panel
        Rectangle {
            id: detailPanel
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 980)
            color: Qt.rgba(0.09, 0.07, 0.05, 0.98)
            border.color: root.goldFaint
            border.width: 1
            radius: 3
            clip: true

            // header + two-col area + footer row
            property int ingCount: root.openDrink ? root.openDrink.i.length : 0
            height: Math.min(72 + 24 + 44 + ingCount * 42 + 28 + 64, parent.height * 0.92)

            // Swallow clicks so they don't reach the backdrop.
            // onClicked also hides the keyboard when the user taps any
            // non-input area inside the panel (header, read-only column, etc.).
            MouseArea {
                anchors.fill: parent
                onClicked: Qt.inputMethod.hide()
            }

            Column {
                width: parent.width

                // ---- Header ----
                Item {
                    width: parent.width
                    height: 72

                    Text {
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.right: panelPrice.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.openDrink ? root.openDrink.n : ""
                        font.family: root.fontDisplayBold
                        font.weight: Font.Bold
                        font.pixelSize: 30
                        color: root.creamHi
                        elide: Text.ElideRight
                    }

                    Text {
                        id: panelPrice
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        anchors.right: panelCloseBtn.left
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.openDrink ? "$" + root.openDrink.p : ""
                        font.family: root.fontMono
                        font.pixelSize: 18
                        color: root.gold
                    }

                    Rectangle {
                        id: panelCloseBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; radius: 18
                        color: panelCloseBtnMA.containsMouse ? root.goldFaint : "transparent"
                        border.color: panelCloseBtnMA.containsMouse ? root.gold : root.goldGhost
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            renderType: Text.NativeRendering
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 22
                            color: root.cream
                        }
                        MouseArea {
                            id: panelCloseBtnMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelDetailPanel()
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.goldFaint
                    }
                }

                // ---- Two-column area ----
                Item {
                    width: parent.width
                    height: 24 + 44 + detailPanel.ingCount * 42 + 28

                    // Default column (read-only)
                    Column {
                        id: defaultPanelCol
                        x: 32; y: 24
                        width: parent.width / 2 - 56
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 44

                            Text {
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DEFAULT"
                                font.family: root.fontDisplayBold
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 1.4
                                color: root.cream
                                opacity: 0.5
                            }

                            Rectangle {
                                id: useDefaultBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                property bool isActive: root.openDrink
                                    ? (root.preferredVersions[root.openDrink.n] || "default") === "default"
                                    : true
                                width: useDefaultLabel.implicitWidth + 20
                                height: 28; radius: 2
                                color: isActive ? root.gold
                                               : (useDefaultMA.containsMouse ? root.goldFaint : "transparent")
                                border.color: isActive ? root.gold : root.goldGhost
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: useDefaultLabel
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                    anchors.centerIn: parent
                                    text: useDefaultBtn.isActive ? "✓ My View" : "Use as View"
                                    font.family: root.fontDisplayBold
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: useDefaultBtn.isActive ? root.bgDark : root.cream
                                }
                                MouseArea {
                                    id: useDefaultMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPreferredVersion(root.openDrink.n, "default")
                                }
                            }
                        }

                        Repeater {
                            model: root.openDrink ? root.openDrink.i : []
                            delegate: Item {
                                width: defaultPanelCol.width
                                height: 42

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: root.hairline
                                    visible: index < (root.openDrink ? root.openDrink.i.length - 1 : 0)
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[0]
                                    font.family: root.fontBody
                                    font.pixelSize: 16
                                    color: root.cream
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    font.family: root.fontMono
                                    font.pixelSize: 16
                                    color: modelData[1] ? root.gold : root.cream
                                    opacity: 0.78
                                }
                            }
                        }
                    }

                    // Vertical divider
                    Rectangle {
                        x: parent.width / 2; y: 0
                        width: 1; height: parent.height
                        color: root.goldFaint
                    }

                    // Altered column (editable)
                    Column {
                        id: alteredPanelCol
                        x: parent.width / 2 + 24; y: 24
                        width: parent.width / 2 - 56
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 44

                            Text {
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ALTERED"
                                font.family: root.fontDisplayBold
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 1.4
                                color: root.cream
                                opacity: 0.5
                            }

                            Rectangle {
                                id: useAlteredBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                property bool isActive: root.openDrink
                                    ? (root.preferredVersions[root.openDrink.n] || "default") === "altered"
                                    : false
                                width: useAlteredLabel.implicitWidth + 20
                                height: 28; radius: 2
                                color: isActive ? root.gold
                                               : (useAlteredMA.containsMouse ? root.goldFaint : "transparent")
                                border.color: isActive ? root.gold : root.goldGhost
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: useAlteredLabel
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                    anchors.centerIn: parent
                                    text: useAlteredBtn.isActive ? "✓ My View" : "Use as View"
                                    font.family: root.fontDisplayBold
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: useAlteredBtn.isActive ? root.bgDark : root.cream
                                }
                                MouseArea {
                                    id: useAlteredMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPreferredVersion(root.openDrink.n, "altered")
                                }
                            }
                        }

                        Repeater {
                            model: alteredIngredientsModel
                            delegate: Item {
                                width: alteredPanelCol.width
                                height: 42

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: root.hairline
                                    visible: index < alteredIngredientsModel.count - 1
                                }

                                TextField {
                                    id: nameField
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * 0.58
                                    height: 32
                                    text: model.ingName
                                    color: root.cream
                                    font.family: root.fontBody
                                    font.pixelSize: 16
                                    leftPadding: 4; rightPadding: 4
                                    topPadding: 0; bottomPadding: 0
                                    background: Rectangle {
                                        color: nameField.activeFocus ? Qt.rgba(0.91, 0.87, 0.78, 0.06) : "transparent"
                                        border.color: nameField.activeFocus ? root.goldGhost : "transparent"
                                        radius: 2
                                    }
                                    onTextEdited: alteredIngredientsModel.setProperty(index, "ingName", text)
                                }

                                TextField {
                                    id: amtField
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * 0.38
                                    height: 32
                                    text: model.ingAmount
                                    color: root.gold
                                    font.family: root.fontMono
                                    font.pixelSize: 16
                                    horizontalAlignment: Text.AlignRight
                                    leftPadding: 4; rightPadding: 4
                                    topPadding: 0; bottomPadding: 0
                                    background: Rectangle {
                                        color: amtField.activeFocus ? Qt.rgba(0.91, 0.87, 0.78, 0.06) : "transparent"
                                        border.color: amtField.activeFocus ? root.goldGhost : "transparent"
                                        radius: 2
                                    }
                                    onTextEdited: alteredIngredientsModel.setProperty(index, "ingAmount", text)
                                }
                            }
                        }
                    }
                }

                // ---- Footer: Cancel / Save ----
                Item {
                    width: parent.width
                    height: 64

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 1
                        color: root.goldFaint
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        // Cancel button
                        Rectangle {
                            id: cancelBtn
                            width: cancelBtnText.implicitWidth + 28
                            height: 38; radius: 2
                            color: cancelBtnMA.containsMouse ? root.goldFaint : "transparent"
                            border.color: cancelBtnMA.containsMouse ? root.gold : root.goldGhost
                            border.width: 1
                            Behavior on color       { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                id: cancelBtnText
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                anchors.centerIn: parent
                                text: "Cancel"
                                font.family: root.fontDisplayBold
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.cream
                            }
                            MouseArea {
                                id: cancelBtnMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelDetailPanel()
                            }
                        }

                        // Save button
                        Rectangle {
                            id: saveBtn
                            width: saveBtnText.implicitWidth + 28
                            height: 38; radius: 2
                            color: saveBtnMA.pressed  ? Qt.darker(root.gold, 1.15)
                                 : saveBtnMA.containsMouse ? root.creamHi
                                 : root.gold
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: saveBtnText
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                anchors.centerIn: parent
                                text: "Save Changes"
                                font.family: root.fontDisplayBold
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.bgDark
                            }
                            MouseArea {
                                id: saveBtnMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveDetailPanel()
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================== ADD COCKTAIL OVERLAY =====================
    Shortcut {
        sequence: "Escape"
        enabled: root.addPanelOpen
        onActivated: root.cancelAddPanel()
    }

    Item {
        id: addOverlay
        anchors.fill: parent
        z: 20
        opacity: root.addPanelOpen ? 1.0 : 0.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }

        // Backdrop
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.05, 0.04, 0.03, 0.88)
            MouseArea {
                anchors.fill: parent
                onClicked: { Qt.inputMethod.hide(); root.cancelAddPanel() }
            }
        }

        // Panel
        Rectangle {
            id: addPanel
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 980)
            // Height grows with ingredient rows up to 92 % of screen height
            height: Math.min(addFlickable.contentHeight, parent.height * 0.92)
            color: Qt.rgba(0.09, 0.07, 0.05, 0.98)
            border.color: root.goldFaint
            border.width: 1
            radius: 3
            clip: true

            // Swallow clicks + hide keyboard on any dead-zone tap
            MouseArea { anchors.fill: parent; onClicked: Qt.inputMethod.hide() }

            Flickable {
                id: addFlickable
                anchors.fill: parent
                contentHeight: addContentWrapper.height
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // Wrap all content in an Item so that taps on dead zones
                // (labels, padding, spaces between fields) propagate up to
                // the background MouseArea instead of disappearing.
                // Interactive children (TextFields, buttons) accept their own
                // events and never reach this MouseArea — no keyboard flash.
                // preventStealing:false lets Flickable reclaim scroll drags.
                Item {
                    id: addContentWrapper
                    width: addFlickable.width
                    height: addContent.height

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: false
                        onClicked: Qt.inputMethod.hide()
                    }

                    Column {
                        id: addContent
                        width: parent.width

                    // ── Panel header ──────────────────────────────────────
                    Item {
                        width: parent.width; height: 72

                        Text {
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                            anchors.left: parent.left; anchors.leftMargin: 32
                            anchors.right: addPanelCloseBtn.left; anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Add New Cocktail"
                            font.family: root.fontDisplayBold
                            font.weight: Font.Bold
                            font.pixelSize: 26
                            color: root.creamHi
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: addPanelCloseBtn
                            anchors.right: parent.right; anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 18
                            color: addPanelCloseBtnMA.containsMouse ? root.goldFaint : "transparent"
                            border.color: addPanelCloseBtnMA.containsMouse ? root.gold : root.goldGhost
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent; text: "×"
                                font.pixelSize: 22; color: root.cream
                            }
                            MouseArea {
                                id: addPanelCloseBtnMA
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelAddPanel()
                            }
                        }

                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.goldFaint }
                    }

                    // ── Name ─────────────────────────────────────────────
                    Item {
                        width: parent.width; height: 80

                        Column {
                            x: 32; y: 14; width: parent.width - 64; spacing: 6

                            Text {
                                renderType: Text.NativeRendering; textFormat: Text.PlainText
                                text: "NAME"
                                font.family: root.fontDisplayBold; font.pixelSize: 11
                                font.weight: Font.Bold; font.letterSpacing: 1.4
                                color: root.cream; opacity: 0.5
                            }

                            TextField {
                                id: addNameField
                                width: parent.width; height: 38
                                color: root.cream
                                font.family: root.fontBody; font.pixelSize: 16
                                padding: 10
                                background: Rectangle {
                                    color: addNameField.activeFocus ? Qt.rgba(0.91,0.87,0.78,0.08) : Qt.rgba(0.91,0.87,0.78,0.04)
                                    border.color: addNameField.activeFocus ? root.gold : root.goldGhost
                                    border.width: 1; radius: 2
                                }
                            }
                        }
                    }

                    // ── Source + Price ────────────────────────────────────
                    Item {
                        width: parent.width; height: 80

                        Column {
                            x: 32; y: 14
                            width: Math.round((parent.width - 64) * 0.65); spacing: 6

                            Text {
                                renderType: Text.NativeRendering; textFormat: Text.PlainText
                                text: "SOURCE  (optional)"
                                font.family: root.fontDisplayBold; font.pixelSize: 11
                                font.weight: Font.Bold; font.letterSpacing: 1.4
                                color: root.cream; opacity: 0.5
                            }
                            TextField {
                                id: addSourceField
                                width: parent.width; height: 38
                                color: root.cream
                                font.family: root.fontBody; font.pixelSize: 16
                                padding: 10
                                background: Rectangle {
                                    color: addSourceField.activeFocus ? Qt.rgba(0.91,0.87,0.78,0.08) : Qt.rgba(0.91,0.87,0.78,0.04)
                                    border.color: addSourceField.activeFocus ? root.gold : root.goldGhost
                                    border.width: 1; radius: 2
                                }
                            }
                        }

                        Column {
                            x: 32 + Math.round((parent.width - 64) * 0.65) + 16
                            y: 14
                            width: parent.width - (32 + Math.round((parent.width - 64) * 0.65) + 16) - 32
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering; textFormat: Text.PlainText
                                text: "PRICE"
                                font.family: root.fontDisplayBold; font.pixelSize: 11
                                font.weight: Font.Bold; font.letterSpacing: 1.4
                                color: root.cream; opacity: 0.5
                            }
                            Row {
                                spacing: 0
                                Text {
                                    renderType: Text.NativeRendering
                                    text: "$"
                                    font.family: root.fontMono; font.pixelSize: 16
                                    color: root.gold; opacity: 0.78
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: 4
                                }
                                TextField {
                                    id: addPriceField
                                    width: 72; height: 38
                                    color: root.cream
                                    font.family: root.fontMono; font.pixelSize: 16
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    padding: 6
                                    background: Rectangle {
                                        color: addPriceField.activeFocus ? Qt.rgba(0.91,0.87,0.78,0.08) : Qt.rgba(0.91,0.87,0.78,0.04)
                                        border.color: addPriceField.activeFocus ? root.gold : root.goldGhost
                                        border.width: 1; radius: 2
                                    }
                                }
                            }
                        }
                    }

                    // ── Category ──────────────────────────────────────────
                    Item {
                        id: addCategorySection
                        width: parent.width
                        height: addCatLabel.implicitHeight + 12 + addCategoryFlow.implicitHeight + 24

                        Text {
                            id: addCatLabel
                            renderType: Text.NativeRendering; textFormat: Text.PlainText
                            x: 32; y: 12
                            text: "CATEGORY"
                            font.family: root.fontDisplayBold; font.pixelSize: 11
                            font.weight: Font.Bold; font.letterSpacing: 1.4
                            color: root.cream; opacity: 0.5
                        }

                        Flow {
                            id: addCategoryFlow
                            x: 32
                            y: addCatLabel.y + addCatLabel.implicitHeight + 10
                            width: parent.width - 64
                            spacing: 6

                            Repeater {
                                model: root.categoryOrder
                                delegate: Rectangle {
                                    id: catChip
                                    property bool sel: modelData === root.newDrinkCategory
                                    width: catChipLabel.implicitWidth + 22; height: 30; radius: 2
                                    color: sel ? root.gold : (catChipMA.containsMouse ? root.goldFaint : "transparent")
                                    border.color: sel ? root.gold : root.goldGhost; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        id: catChipLabel
                                        renderType: Text.NativeRendering; textFormat: Text.PlainText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: root.fontDisplayBold; font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: catChip.sel ? root.bgDark : root.cream
                                    }
                                    MouseArea {
                                        id: catChipMA
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.newDrinkCategory = modelData
                                            Qt.inputMethod.hide()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Divider ───────────────────────────────────────────
                    Rectangle { width: parent.width; height: 1; color: root.goldFaint }

                    // ── Ingredients header + "Add Row" button ─────────────
                    Item {
                        width: parent.width; height: 52

                        Text {
                            renderType: Text.NativeRendering; textFormat: Text.PlainText
                            anchors.left: parent.left; anchors.leftMargin: 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: "INGREDIENTS"
                            font.family: root.fontDisplayBold; font.pixelSize: 11
                            font.weight: Font.Bold; font.letterSpacing: 1.4
                            color: root.cream; opacity: 0.5
                        }

                        Rectangle {
                            id: addRowBtn
                            anchors.right: parent.right; anchors.rightMargin: 32
                            anchors.verticalCenter: parent.verticalCenter
                            width: addRowBtnLabel.implicitWidth + 22; height: 28; radius: 2
                            color: addRowBtnMA.containsMouse ? root.goldFaint : "transparent"
                            border.color: addRowBtnMA.containsMouse ? root.gold : root.goldGhost
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                id: addRowBtnLabel
                                renderType: Text.NativeRendering; textFormat: Text.PlainText
                                anchors.centerIn: parent
                                text: "+ Add Row"
                                font.family: root.fontDisplayBold; font.pixelSize: 11
                                font.weight: Font.Bold; color: root.cream
                            }
                            MouseArea {
                                id: addRowBtnMA
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Qt.inputMethod.hide()
                                    newDrinkIngredientsModel.append({ ingName: "", ingAmount: "" })
                                }
                            }
                        }
                    }

                    // ── Ingredient rows ───────────────────────────────────
                    Repeater {
                        model: newDrinkIngredientsModel
                        delegate: Item {
                            width: addContent.width; height: 50

                            Rectangle {
                                anchors.top: parent.top
                                x: 32; width: parent.width - 64; height: 1
                                color: root.hairline
                            }

                            TextField {
                                id: addIngNameField
                                x: 32
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.46
                                height: 36
                                text: model.ingName
                                color: root.cream
                                font.family: root.fontBody; font.pixelSize: 16
                                leftPadding: 6; rightPadding: 6
                                topPadding: 0; bottomPadding: 0
                                background: Rectangle {
                                    color: addIngNameField.activeFocus ? Qt.rgba(0.91,0.87,0.78,0.06) : "transparent"
                                    border.color: addIngNameField.activeFocus ? root.goldGhost : "transparent"
                                    radius: 2
                                }
                                onTextEdited: newDrinkIngredientsModel.setProperty(index, "ingName", text)
                            }

                            TextField {
                                id: addIngAmtField
                                anchors.right: addRemoveBtn.left; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.24
                                height: 36
                                text: model.ingAmount
                                color: root.gold
                                font.family: root.fontMono; font.pixelSize: 16
                                horizontalAlignment: Text.AlignRight
                                leftPadding: 6; rightPadding: 6
                                topPadding: 0; bottomPadding: 0
                                background: Rectangle {
                                    color: addIngAmtField.activeFocus ? Qt.rgba(0.91,0.87,0.78,0.06) : "transparent"
                                    border.color: addIngAmtField.activeFocus ? root.goldGhost : "transparent"
                                    radius: 2
                                }
                                onTextEdited: newDrinkIngredientsModel.setProperty(index, "ingAmount", text)
                            }

                            Rectangle {
                                id: addRemoveBtn
                                anchors.right: parent.right; anchors.rightMargin: 32
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28; radius: 14
                                visible: newDrinkIngredientsModel.count > 1
                                color: addRemoveBtnMA.containsMouse ? root.goldFaint : "transparent"
                                border.color: addRemoveBtnMA.containsMouse ? root.gold : root.goldGhost
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: "−"; font.pixelSize: 18; color: root.cream
                                }
                                MouseArea {
                                    id: addRemoveBtnMA
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Qt.inputMethod.hide()
                                        newDrinkIngredientsModel.remove(index)
                                    }
                                }
                            }
                        }
                    }

                    // ── Footer: Cancel / Add Drink ────────────────────────
                    Item {
                        width: parent.width; height: 72

                        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.goldFaint }

                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 32
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            // Cancel
                            Rectangle {
                                id: addCancelBtn
                                width: addCancelBtnText.implicitWidth + 28; height: 38; radius: 2
                                color: addCancelBtnMA.containsMouse ? root.goldFaint : "transparent"
                                border.color: addCancelBtnMA.containsMouse ? root.gold : root.goldGhost
                                border.width: 1
                                Behavior on color        { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: addCancelBtnText
                                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                                    anchors.centerIn: parent; text: "Cancel"
                                    font.family: root.fontDisplayBold; font.pixelSize: 13
                                    font.weight: Font.Bold; color: root.cream
                                }
                                MouseArea {
                                    id: addCancelBtnMA
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cancelAddPanel()
                                }
                            }

                            // Add Drink (orange)
                            Rectangle {
                                id: addDrinkBtn
                                width: addDrinkBtnText.implicitWidth + 28; height: 38; radius: 2
                                color: addDrinkBtnMA.pressed       ? Qt.darker(root.orange, 1.2)
                                     : addDrinkBtnMA.containsMouse ? Qt.lighter(root.orange, 1.12)
                                     : root.orange
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: addDrinkBtnText
                                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                                    anchors.centerIn: parent; text: "Add Drink"
                                    font.family: root.fontDisplayBold; font.pixelSize: 13
                                    font.weight: Font.Bold; color: "white"
                                }
                                MouseArea {
                                    id: addDrinkBtnMA
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var name = addNameField.text.trim()
                                        if (name.length === 0) return   // name required

                                        var ingredients = []
                                        for (var i = 0; i < newDrinkIngredientsModel.count; i++) {
                                            var it = newDrinkIngredientsModel.get(i)
                                            var n  = it.ingName.trim()
                                            if (n.length > 0)
                                                ingredients.push([n, it.ingAmount.trim()])
                                        }
                                        if (ingredients.length === 0) return   // ≥1 ingredient required

                                        root.saveNewDrink(
                                            name,
                                            addSourceField.text.trim(),
                                            parseInt(addPriceField.text) || 0,
                                            ingredients
                                        )
                                    }
                                }
                            }
                        }
                    }

                    } // Column addContent
                } // Item addContentWrapper
            } // Flickable addFlickable
        } // Rectangle addPanel
    } // Item addOverlay

    // ── Global keyboard-dismiss button ───────────────────────────────────
    // Appears above the virtual keyboard whenever it is active, for every
    // text input across the whole app (search, detail panel, add panel).
    // Tapping it calls Qt.inputMethod.hide() and blurs the active field.
    Rectangle {
        id: kbdDoneBtn
        z: 50                              // above panels (z:20), below keyboard (z:99)
        visible: inputPanel.active
        y: inputPanel.y - height - 8       // tracks the keyboard slide animation
        anchors.right: parent.right
        anchors.rightMargin: 12
        width: kbdDoneLabel.implicitWidth + 28
        height: 38
        radius: 2
        color: kbdDoneMA.pressed       ? Qt.darker(root.bgDark, 1.0)
             : kbdDoneMA.containsMouse ? Qt.rgba(0.09,0.07,0.05,1.0)
             : Qt.rgba(0.09, 0.07, 0.05, 0.97)
        border.color: root.gold
        border.width: 1

        Text {
            id: kbdDoneLabel
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "Done"
            font.family: root.fontDisplayBold
            font.pixelSize: 13
            font.weight: Font.Bold
            color: root.gold
        }

        MouseArea {
            id: kbdDoneMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.contentItem.forceActiveFocus()  // blurs the active TextField
                Qt.inputMethod.hide()
            }
        }
    }

    InputPanel {
        id: inputPanel
        z: 99
        x: 0
        y: root.height
        width: root.width

        states: State {
            name: "visible"
            when: inputPanel.active
            PropertyChanges {
                target: inputPanel
                y: root.height - inputPanel.height
            }
        }
        transitions: Transition {
            reversible: true
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.InOutQuad }
        }
    }
}
