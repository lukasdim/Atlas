// CocktailAtlas.qml — QML port of the React cocktail reference (v3).
//
// v3 changes:
//   • First-row-only category display with an expand/collapse toggle button
//   • Small uppercase labels switched to Bodoni Moda Bold for editorial polish
//   • Optional: drop BodoniModa-Bold.ttf into fonts/ for a true bold weight;
//     otherwise Qt synthesises bold from the Regular file.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard

ApplicationWindow {
    id: root
    width: 1024
    height: 600
    visible: true
    title: "Cocktail Atlas"

    background: Image {
        source: "images/gradient.png"
        fillMode: Image.Stretch        // use PreserveAspectCrop if you'd rather not distort it
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

    FontLoader {
        id: bodoni
        source: Qt.resolvedUrl("fonts/jetbrainsmono-variable.ttf")
        onStatusChanged: {
            if (status === FontLoader.Ready)
                console.log("Bodoni loaded:", name)
            else if (status === FontLoader.Error)
                console.log("Bodoni FAILED to load from:", source)
        }
    }

    FontLoader { id: displayFont; source: "fonts/bodonimoda-variable.ttf" }
    FontLoader { id: bodyFont;    source: "fonts/outfit-variable.ttf" }
    FontLoader { id: monoFont;    source: "fonts/jetbrainsmono-variable.ttf" }


    function fDisplay()     { return displayFont.status     === FontLoader.Ready ? displayFont.name     : "Times New Roman" }
    // probably need to replace all, but this is easier for testing
    function fDisplayBold() { return fDisplay() }
    function fBody()        { return bodyFont.status        === FontLoader.Ready ? bodyFont.name        : "Helvetica" }
    function fMono()        { return monoFont.status        === FontLoader.Ready ? monoFont.name        : "Courier New" }

    // ===================== STATE =====================
    property string activeCategory: "All"
    property string searchText: ""
    property bool   categoriesExpanded: false
    readonly property var currentGroups: filteredGroups()

    // Number of categories from categoryOrder shown on the first row
    // (plus the "All" chip and the expand toggle). Tune to taste.
    readonly property int firstRowCount: 4

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

    readonly property var drinks: [
        // SPRITZ & BUBBLES
        { n: "Aperol Spritz", s: "Bellini's", c: "Spritz & Bubbles", p: 11,
          i: [["Aperol","2 oz"],["Val d'Oca Prosecco","3 oz"],["Soda water","1 oz"],["Orange slice","garnish"]] },
        { n: "Hugo Spritz", s: "Bellini's", c: "Spritz & Bubbles", p: 11,
          i: [["St-Germain Elderflower","1 oz"],["Fresh lime juice","0.5 oz"],["Val d'Oca Prosecco","3 oz"],["Soda water","1 oz"],["Mint sprig","garnish"]] },
        { n: "Raspberry Lemonade", s: "Bellini's", c: "Spritz & Bubbles", p: 13,
          i: [["Absolut Raspberry","1.5 oz"],["Limoncello","0.5 oz"],["Fresh lime juice","0.5 oz"],["Lemonade","3 oz"]] },
        { n: "Summer in Italy", s: "Bellini's", c: "Spritz & Bubbles", p: 13,
          i: [["Limoncello","1 oz"],["Aperol","1 oz"],["Val d'Oca Prosecco","3 oz"]] },
        { n: "Italian Sparrow", s: "Bellini's", c: "Spritz & Bubbles", p: 13,
          i: [["Aperol","1.5 oz"],["Fresh lemon juice","0.75 oz"],["Val d'Oca Prosecco","3 oz"]] },
        { n: "Red Ferrari", s: "Bellini's", c: "Spritz & Bubbles", p: 13,
          i: [["Aperol","1.5 oz"],["Fresh grapefruit juice","1 oz"],["Fresh lemon juice","0.5 oz"],["Val d'Oca Prosecco","3 oz"]] },
        { n: "Limecello Spritz", s: "Bellini's", c: "Spritz & Bubbles", p: 14,
          i: [["Villa Massa Limoncello","1.5 oz"],["Prosecco","3 oz"],["Betty Buzz Meyer Lemon","1.5 oz"],["Mint","5-7 leaves"]] },
        { n: "Hampton Spritz", s: "Pool Bar / Crooners", c: "Spritz & Bubbles", p: 14,
          i: [["Hampton Water Bubbly Rosé","3 oz"],["Elderflower liqueur","0.75 oz"],["Fresh lime juice","0.5 oz"],["Betty Buzz Sparkling Grapefruit","1.5 oz"],["Raspberries","3-4"],["Mint","5 leaves"]] },
        { n: "Frozen Aperol Spritz", s: "Pool Bar", c: "Spritz & Bubbles", p: 13,
          i: [["Aperol","2 oz"],["Prosecco","3 oz"],["Orange juice","1 oz"],["Club soda","1 oz"],["Ice","blended"]] },
        { n: "Aperol Selection Tower", s: "Bellini's", c: "Spritz & Bubbles", p: 35,
          i: [["Aperol Spritz","1 serving"],["Italian Sparrow","1 serving"],["Red Ferrari","1 serving"],["Secret spritz","1 serving"],["Serves 2",""]] },
        { n: "Floral Selection Tower", s: "Bellini's", c: "Spritz & Bubbles", p: 35,
          i: [["Hugo Spritz","1 serving"],["Passion Lilly","1 serving"],["Summer in Italy","1 serving"],["Secret spritz","1 serving"],["Serves 2",""]] },

        // MARGARITAS & AGAVE
        { n: "24K Margarita", s: "Pool Bar / Crooners", c: "Margaritas & Agave", p: 14,
          i: [["Pantalones Tequila","1.5 oz"],["Cointreau","0.5 oz"],["Grand Marnier","0.25 oz"],["Fresh lemon juice","0.5 oz"],["Fresh lime juice","0.5 oz"],["Gold flakes","garnish"]] },
        { n: "Guava Margarita", s: "Pool Bar", c: "Margaritas & Agave", p: 14,
          i: [["Patrón Silver","1.5 oz"],["Cointreau","0.5 oz"],["Fresh lime juice","0.75 oz"],["Guava purée","1 oz"]] },
        { n: "Coconut Margarita", s: "Pool Bar", c: "Margaritas & Agave", p: 15,
          i: [["Patrón Silver","1.5 oz"],["Triple Sec","0.5 oz"],["Fresh lime juice","0.75 oz"],["Coconut cream","1 oz"]] },
        { n: "Grilled Pineapple Margarita", s: "Pool Bar", c: "Margaritas & Agave", p: 18,
          i: [["Pantalones Blanco","1.5 oz"],["Cointreau","0.5 oz"],["Fresh lime juice","0.75 oz"],["Grilled pineapple juice","1 oz"],["Agave","0.25 oz"]] },
        { n: "Meili Paloma 2.0", s: "Pool Bar", c: "Margaritas & Agave", p: 14,
          i: [["Meili Vodka","1.5 oz"],["Fresh lime juice","0.75 oz"],["Agave","0.5 oz"],["Jalapeño slices","2-3"],["Betty Buzz Grapefruit Soda","3 oz"]] },
        { n: "Truly Caliente Fresca", s: "Pool Bar", c: "Margaritas & Agave", p: 12,
          i: [["Truly Strawberry Lemonade","4 oz"],["Patrón Silver","1 oz"],["Fresh lime juice","0.5 oz"],["Jalapeño slices","2-3"],["Mint","5 leaves"]] },
        { n: "Sea Legs", s: "Pool Bar", c: "Margaritas & Agave", p: 20,
          i: [["Pantalones Reposado","1.5 oz"],["Maraschino liqueur","0.5 oz"],["Fresh lime juice","0.5 oz"],["Fresh grapefruit juice","1 oz"],["Agave","0.25 oz"],["Soda water","1 oz"]] },
        { n: "Pants on Fire", s: "Pool Bar / Crooners", c: "Margaritas & Agave", p: 20,
          i: [["Pantalones Reposado","1.5 oz"],["Campari","0.5 oz"],["Fresh lime juice","0.75 oz"],["Smoked paprika agave","0.5 oz"]] },
        { n: "Lavender Smoke", s: "Crooners", c: "Margaritas & Agave", p: 17,
          i: [["Ilegal Mezcal Reposado","1.5 oz"],["St-Germain liqueur","0.5 oz"],["Fresh lime juice","0.75 oz"],["Lavender syrup","0.5 oz"],["Orgeat","0.25 oz"]] },

        // TROPICAL & TIKI
        { n: "Passion Satisfaction", s: "Pool Bar", c: "Tropical & Tiki", p: 14,
          i: [["Crossfire Rum","1.5 oz"],["Licor 43","0.5 oz"],["Honey","0.25 oz"],["Fresh lime juice","0.5 oz"],["Passionfruit purée","0.75 oz"],["Pineapple juice","1 oz"],["Angostura bitters","2 dashes"]] },
        { n: "Sweetest Sounds", s: "Pool Bar / Crooners", c: "Tropical & Tiki", p: 14,
          i: [["Crossfire Rum","1.5 oz"],["Amaretto","0.5 oz"],["Coconut cream","1 oz"],["Fresh lime juice","0.5 oz"],["Ginger syrup","0.25 oz"]] },
        { n: "Southern Bond", s: "Pool Bar", c: "Tropical & Tiki", p: 14,
          i: [["Brother's Bond Bourbon","1 oz"],["Malibu Coconut Rum","0.75 oz"],["Mango purée","1 oz"],["Coconut milk","1 oz"],["Fresh lime juice","0.5 oz"],["Mint","5 leaves"]] },
        { n: "Jungle Bird", s: "Pool Bar", c: "Tropical & Tiki", p: 12,
          i: [["Bacardi White Rum","1 oz"],["Bacardi Spiced Rum","0.5 oz"],["Campari","0.75 oz"],["Fresh lime juice","0.5 oz"],["Pineapple juice","1.5 oz"]] },
        { n: "Truly Pineapple & Coconut Daiquiri", s: "Pool Bar", c: "Tropical & Tiki", p: 12,
          i: [["Truly Hard Seltzer","3 oz"],["Malibu Rum","1 oz"],["Pineapple juice","1 oz"],["Coconut cream","0.75 oz"],["Orgeat","0.25 oz"]] },
        { n: "Peanut Jungle Ball", s: "Pool Bar", c: "Tropical & Tiki", p: 15,
          i: [["Screwball Peanut Butter Whisky","1 oz"],["Campari","0.5 oz"],["Falernum","0.5 oz"],["Orgeat","0.25 oz"],["Fresh lemon juice","0.5 oz"],["Fresh lime juice","0.25 oz"],["Dark rum float","0.5 oz"]] },
        { n: "I Can't Feel the Rain", s: "Pool Bar", c: "Tropical & Tiki", p: 15,
          i: [["Ketel One Vodka","1.5 oz"],["Peach purée","0.75 oz"],["Pineapple juice","1 oz"],["Fresh lemon juice","0.5 oz"],["Honey","0.25 oz"]] },
        { n: "Tropical Alibi", s: "Pool Bar / Crooners", c: "Tropical & Tiki", p: 15,
          i: [["Sláinte Irish Whiskey","1.5 oz"],["Banana liqueur","0.5 oz"],["Coconut milk","1 oz"],["Pineapple juice","1 oz"],["Fresh lime juice","0.5 oz"],["Angostura bitters","2 dashes"]] },
        { n: "Aperol-Colada", s: "Pool Bar", c: "Tropical & Tiki", p: 18,
          i: [["Malibu Rum","1 oz"],["Aperol","0.75 oz"],["Pineapple juice","1.5 oz"],["Coconut cream","1 oz"],["Fresh lime juice","0.5 oz"],["Orgeat","0.25 oz"]] },
        { n: "Passion Tree", s: "Pool Bar", c: "Tropical & Tiki", p: 18,
          i: [["Absolut Vanilla","1.5 oz"],["Chinola Passion Liqueur","0.5 oz"],["Passion fruit purée","0.75 oz"],["Fresh lemon juice","0.5 oz"],["Prosecco","2 oz"]] },
        { n: "Baileys Colada", s: "Pool Bar", c: "Tropical & Tiki", p: 17,
          i: [["Baileys","1.5 oz"],["Coconut cream","1 oz"],["Pineapple juice","2 oz"],["Ice","blended"]] },

        // SOURS & CITRUS
        { n: "Passion Lilly", s: "Bellini's", c: "Sours & Citrus", p: 14,
          i: [["Montenegro Amaro","1 oz"],["Italicus Bergamot","0.75 oz"],["Fresh lemon juice","0.75 oz"],["Passion fruit purée","0.5 oz"],["Vanilla syrup","0.25 oz"],["Val d'Oca Prosecco","2 oz"]] },
        { n: "Honey Sweet Bourbon", s: "Pool Bar", c: "Sours & Citrus", p: 14,
          i: [["Brother's Bond Bourbon","1.5 oz"],["Aperol","0.5 oz"],["Peach purée","0.5 oz"],["Honey","0.25 oz"],["Fresh lemon juice","0.75 oz"]] },
        { n: "Classic Cosmo", s: "Crooners", c: "Sours & Citrus", p: 12,
          i: [["Absolut Elyx","1.5 oz"],["Cointreau","0.5 oz"],["Cranberry juice","0.75 oz"],["Fresh lime juice","0.5 oz"]] },
        { n: "French Martini", s: "Crooners", c: "Sours & Citrus", p: 12,
          i: [["Absolut Elyx","1.5 oz"],["Chambord","0.5 oz"],["Pineapple juice","1.5 oz"]] },
        { n: "Clover Club", s: "Crooners", c: "Sours & Citrus", p: 15,
          i: [["Bombay Gin","1.5 oz"],["Chambord","0.5 oz"],["Fresh lemon juice","0.75 oz"],["Raspberry purée","0.5 oz"],["Agave","0.25 oz"],["Egg white","0.5 oz (opt)"]] },
        { n: "Figs & Honey", s: "Crooners", c: "Sours & Citrus", p: 14,
          i: [["Absolut Elyx","1.5 oz"],["Fresh lemon juice","0.75 oz"],["Honey-thyme syrup","0.5 oz"],["Fig jam","1 bar spoon"]] },
        { n: "The Rose", s: "Crooners", c: "Sours & Citrus", p: 20,
          i: [["Absolut Elyx","1.5 oz"],["Fresh lemon juice","0.75 oz"],["Strawberry purée","1 oz"]] },
        { n: "Strawberry Fields Forever", s: "Crooners / Pool Bar", c: "Sours & Citrus", p: 15,
          i: [["Meili Vodka","1.5 oz"],["Basil","4 leaves"],["Strawberries","3 muddled"],["Agave","0.25 oz"],["Elderflower liqueur","0.5 oz"],["Betty Buzz Sparkling Lime","1.5 oz"]] },
        { n: "Sgroppini", s: "Flair of Italy", c: "Sours & Citrus", p: 14,
          i: [["Tito's Vodka","1 oz"],["Limoncello","0.75 oz"],["Fresh lemon juice","0.5 oz"],["Peach purée","0.5 oz"],["Honey","0.25 oz"],["Agave","0.25 oz"]] },
        { n: "Frose", s: "Pool Bar", c: "Sours & Citrus", p: 15,
          i: [["Tito's Vodka","1 oz"],["Hampton Water Rosé","3 oz"],["Strawberry purée","1 oz"],["Pear purée","0.5 oz"],["Ice","blended"]] },
        { n: "Lychee Vodka Mojito", s: "Pool Bar", c: "Sours & Citrus", p: 15,
          i: [["Tito's Vodka","1.5 oz"],["Lychee juice","1 oz"],["Fresh lime juice","0.5 oz"],["Mint","8 leaves"],["Soda water","1 oz"]] },
        { n: "State Fair", s: "Pool Bar", c: "Sours & Citrus", p: 16,
          i: [["Absolut Citron","1 oz"],["Hendrick's Gin","0.5 oz"],["Peach Schnapps","0.5 oz"],["Fresh lime juice","0.5 oz"],["Cranberry juice","1 oz"]] },

        // FLORAL & BOTANICAL
        { n: "Violette Haze", s: "Crooners", c: "Floral & Botanical", p: 19,
          i: [["Hendrick's Gin","1.5 oz"],["Crème de Violette","0.5 oz"],["Fresh lemon juice","0.75 oz"],["Cucumber slices","3"]] },
        { n: "Sailing Through the Orchids", s: "Crooners", c: "Floral & Botanical", p: 19,
          i: [["Grey Goose La Poire","1 oz"],["St-Germain liqueur","0.5 oz"],["Empress Gin","0.5 oz"],["Cointreau","0.25 oz"],["Fresh lemon juice","0.5 oz"],["Pear purée","0.5 oz"],["Yuzu bitters","2 dashes"]] },
        { n: "Roma", s: "Flair of Italy", c: "Floral & Botanical", p: 15,
          i: [["Hendrick's Gin","1.5 oz"],["St-Germain liqueur","0.5 oz"],["Limoncello","0.5 oz"],["Raspberries","3-4 muddled"]] },
        { n: "Italicize This", s: "Flair of Italy", c: "Floral & Botanical", p: 18,
          i: [["Italicus Bergamot Liqueur","2 oz"],["Fresh lime juice","0.5 oz"],["San Benedetto sparkling water","3 oz"]] },

        // STIRRED & SPIRIT-FORWARD
        { n: "Crooners Signature 007", s: "Crooners", c: "Stirred & Spirit-Forward", p: 14,
          i: [["Elyx or Tanqueray Gin","2.5 oz"],["Olive brine","0.25 oz"],["Olive","garnish"]] },
        { n: "Chairman of the Board", s: "Crooners", c: "Stirred & Spirit-Forward", p: 16,
          i: [["Grey Goose Vodka","1 oz"],["Tanqueray Gin","1 oz"],["Cointreau","0.5 oz"]] },
        { n: "Carajillo Old Fashioned", s: "Crooners", c: "Stirred & Spirit-Forward", p: 18,
          i: [["Bacardi 8","1 oz"],["Jack Daniel's","1 oz"],["Harvey's Bristol Cream","0.5 oz"],["Coffee tincture","0.25 oz"],["Orange blood syrup","0.25 oz"]] },
        { n: "Brooklyn Nights", s: "Crooners", c: "Stirred & Spirit-Forward", p: 19,
          i: [["Woodford Reserve Rye","2 oz"],["Carpano Antica","0.75 oz"],["Orange bitters","2 dashes"],["Luxardo cherry","garnish"]] },
        { n: "Whispers of Lapsang", s: "Crooners", c: "Stirred & Spirit-Forward", p: 19,
          i: [["Woodford Rye","1.5 oz"],["Bacardi 8","0.5 oz"],["Fresh lemon juice","0.5 oz"],["Lapsang tea syrup","0.5 oz"],["Angostura bitters","2 dashes"]] },
        { n: "Renaissance", s: "Flair of Italy", c: "Stirred & Spirit-Forward", p: 19,
          i: [["Hennessy VS","1.5 oz"],["Limoncello","0.5 oz"],["Carpano Antica","0.5 oz"],["Peach bitters","2 dashes"]] },

        // DESSERT & CREAM
        { n: "Rum Brulee", s: "Crooners", c: "Dessert & Cream", p: 14,
          i: [["Appleton Rum","1.5 oz"],["Crème de Cacao","0.5 oz"],["Banane du Brésil","0.5 oz"],["Walnut bitters","2 dashes"]] },
        { n: "Cask and Coco", s: "Crooners", c: "Dessert & Cream", p: 15,
          i: [["Jameson","1.5 oz"],["Licor 43","0.5 oz"],["Crème de Cacao","0.5 oz"],["Salted caramel syrup","0.25 oz"]] },
        { n: "Ferrero", s: "Crooners", c: "Dessert & Cream", p: 15,
          i: [["Absolut Vanilla","1 oz"],["Licor 43 Chocolate","0.5 oz"],["Baileys","0.5 oz"],["Frangelico","0.5 oz"],["Nutella","1 bar spoon"]] },
        { n: "Orange Dreams", s: "Flair of Italy", c: "Dessert & Cream", p: 17,
          i: [["Absolut Vanilla","1 oz"],["Orangecello","1 oz"],["Cream","1 oz"]] },

        // COFFEE
        { n: "Golden Café Cappuccino", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","3 oz"],["Milk foam","2 oz"],["Vanilla syrup","0.25 oz"],["Turmeric","pinch"],["Ginger","pinch"],["Cinnamon","pinch"]] },
        { n: "Honey Lavender Latte", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","6 oz"],["Lavender syrup","0.5 oz"],["Honey","0.25 oz"]] },
        { n: "Mocha Caramel Latte", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","6 oz"],["Chocolate syrup","0.5 oz"],["Caramel syrup","0.5 oz"]] },
        { n: "Tiramisu Cappuccino", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","3 oz"],["Milk foam","2 oz"],["Tiramisu syrup","0.5 oz"],["Cocoa powder","dusting"]] },
        { n: "Nutella Cappuccino", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","3 oz"],["Milk foam","2 oz"],["Nutella","1 bar spoon"]] },
        { n: "Pink Latte", s: "Specialty Coffees", c: "Coffee", p: 6,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Steamed milk","6 oz"],["Vanilla syrup","0.25 oz"],["Dragon fruit purée","0.5 oz"]] },

        // SPIRITED COFFEE
        { n: "Carajillo", s: "Spirited Coffees", c: "Spirited Coffee", p: 15,
          i: [["Licor 43","1.5 oz"],["Lavazza espresso","1 oz / 1 shot"],["Ice","for shaking"]] },
        { n: "Caballero", s: "Spirited Coffees", c: "Spirited Coffee", p: 13,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Amaretto","1 oz"],["Cream float","0.5 oz"]] },
        { n: "Espresso Martini", s: "Spirited Coffees", c: "Spirited Coffee", p: 15,
          i: [["Tito's Vodka","1.5 oz"],["Kahlúa","0.5 oz"],["Lavazza espresso","1 oz / 1 shot"],["Simple syrup","0.25 oz"],["Salt","pinch"]] },
        { n: "Espresso 43", s: "Spirited Coffees", c: "Spirited Coffee", p: 15,
          i: [["Lavazza espresso","1 oz / 1 shot"],["Licor 43","1 oz"],["Vodka","0.5 oz"]] },

        // APERITIFS (NEAT)
        { n: "Aperol (neat)", s: "Flair of Italy – Plus Package", c: "Aperitifs (Neat)", p: 9,
          i: [["Aperol","2 oz"],["Served on rocks",""]] },
        { n: "Campari (neat)", s: "Flair of Italy – Plus Package", c: "Aperitifs (Neat)", p: 9,
          i: [["Campari","2 oz"],["Served on rocks",""]] }
    ]

    // ===================== FILTER / GROUP LOGIC =====================
    function filteredGroups() {
        var list = drinks
        if (activeCategory !== "All")
            list = list.filter(function(d) { return d.c === activeCategory })
        if (searchText.trim().length > 0) {
            var q = searchText.toLowerCase()
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
        var out = []
        for (var ci = 0; ci < categoryOrder.length; ci++) {
            var cat = categoryOrder[ci]
            if (groups[cat]) out.push({ category: cat, drinks: groups[cat] })
        }
        return out
    }

    function categoryCount(cat) {
        if (cat === "All") return drinks.length
        var n = 0
        for (var i = 0; i < drinks.length; i++)
            if (drinks[i].c === cat) n++
        return n
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
                text: chip.label
                font.family: root.fDisplayBold()
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
                color: chip.active ? root.bgDark : root.cream
            }
            Text {
                text: chip.chipCount
                font.family: root.fDisplayBold()
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
            onClicked: chip.clicked()
            onEntered: chip.hovered = true
            onExited:  chip.hovered = false
        }
    }

    // Expand/collapse toggle. Visually distinct from CategoryChip:
    // filled gold background + italic "More"/"Less" label + chevron.
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
                text: toggle.expanded ? "Less" : "More"
                font.family: root.fDisplayBold()
                font.pixelSize: 14
                font.weight: Font.Bold
                font.italic: true
                color: root.bgDark
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: toggle.expanded ? "−" : "+"
                font.family: root.fDisplayBold()
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
            onClicked: toggle.clicked()
            onEntered: toggle.hovered = true
            onExited:  toggle.hovered = false
        }
    }

    component DrinkCard: Rectangle {
        id: card
        property var drink: ({})
        property int forcedIngredients: 0
        property bool hovered: false

        readonly property int actualIngredients: (drink.i || []).length
        readonly property int rowH: 34
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
            onEntered: card.hovered = true
            onExited:  card.hovered = false
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
                    id: nameText
                    anchors.left: parent.left
                    anchors.right: priceText.left
                    anchors.rightMargin: 14
                    text: card.drink.n || ""
                    font.family: root.fDisplayBold()
                    font.weight: Font.Bold
                    font.pixelSize: 28
                    color: root.creamHi
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: priceText
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    text: "$" + (card.drink.p || 0)
                    font.family: root.fMono()
                    font.pixelSize: 14
                    color: root.gold
                }
            }

            Text {
                id: sourceText
                width: parent.width
                height: 0
                property int implicitHeight: 16
                property int bottomPadding: 24
            }

            Repeater {
                model: card.drink.i || []
                delegate: Item {
                    width: cardCol.width
                    height: card.rowH

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.hairline
                        visible: index < (card.drink.i.length - 1)
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        font.family: root.fBody()
                        font.pixelSize: 14
                        color: root.cream
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.family: root.fMono()
                        font.pixelSize: 12
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
                    font.family: root.fDisplay()
                    font.pixelSize: 48
                    lineHeight: 0.92
                    color: root.creamHi
                }
                // Subtitle: now Bodoni Bold italic for editorial polish.
                Text {
                    text: root.drinks.length + " drinks · " + root.categoryOrder.length + " categories"
                    font.family: root.fDisplayBold()
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.italic: true
                    color: root.cream
                    opacity: 0.55
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
                    font.family: root.fBody()
                    font.pixelSize: 14
                    selectByMouse: true
                    padding: 12
                    background: Rectangle {
                        color: root.creamWash
                        border.color: Qt.rgba(0.83, 0.66, 0.37, 0.2)
                        radius: 2
                    }
                    onTextChanged: root.searchText = text
                }

                // First row: All + first N categories + expand toggle
                Flow {
                    width: parent.width
                    spacing: 7

                    CategoryChip {
                        label: "All"
                        chipCount: root.categoryCount("All")
                        active: root.activeCategory === "All"
                        onClicked: root.activeCategory = "All"
                    }
                    Repeater {
                        model: root.categoryOrder.slice(0, root.firstRowCount)
                        delegate: CategoryChip {
                            label: modelData
                            chipCount: root.categoryCount(modelData)
                            active: root.activeCategory === modelData
                            onClicked: root.activeCategory = modelData
                        }
                    }
                    ExpandToggle {
                        expanded: root.categoriesExpanded
                        onClicked: root.categoriesExpanded = !root.categoriesExpanded
                    }
                }

                // Second row: remaining categories, toggled by ExpandToggle.
                // visible:false makes the parent Column reclaim its space.
                Flow {
                    width: parent.width
                    spacing: 7
                    visible: root.categoriesExpanded

                    Repeater {
                        model: root.categoryOrder.slice(root.firstRowCount)
                        delegate: CategoryChip {
                            label: modelData
                            chipCount: root.categoryCount(modelData)
                            active: root.activeCategory === modelData
                            onClicked: root.activeCategory = modelData
                        }
                    }
                }
            }
        }

        // ---------- Scrollable content ----------
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: root.width
                spacing: 44
                topPadding: 32
                bottomPadding: 72

                TapHandler {
                    onTapped: searchField.focus = false
                }

                Repeater {
                    model: root.currentGroups

                    delegate: Column {
                        x: 28
                        width: root.width - 56
                        spacing: 12

                        Item {
                            width: parent.width
                            height: 56
                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                text: modelData.category
                                font.family: root.fDisplay()
                                font.pixelSize: 36
                                color: root.creamHi
                            }
                            // Section drink count: Bodoni Bold instead of mono.
                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 18
                                text: modelData.drinks.length + (modelData.drinks.length === 1 ? " DRINK" : " DRINKS")
                                font.family: root.fDisplayBold()
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
                            width: parent.width
                            text: root.categoryBlurbs[modelData.category] || ""
                            font.family: root.fBody()
                            font.italic: true
                            font.pixelSize: 13
                            color: root.cream
                            opacity: 0.6
                            wrapMode: Text.WordWrap
                            bottomPadding: 12
                        }

                        Column {
                            id: cardsCol
                            width: parent.width
                            spacing: 16
                            property int cols: root.width > 720 ? 2 : 1

                            Repeater {
                                model: root.buildCardRows(modelData.drinks, cardsCol.cols)
                                delegate: Row {
                                    id: cardRow
                                    width: cardsCol.width
                                    spacing: 16
                                    property var rowData: modelData

                                    Repeater {
                                        model: cardRow.rowData.drinks
                                        delegate: DrinkCard {
                                            width: (cardRow.width - cardRow.spacing * (cardsCol.cols - 1)) / cardsCol.cols
                                            drink: modelData
                                            forcedIngredients: cardRow.rowData.maxIngredients
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: root.width - 56
                    height: visible ? 220 : 0
                    visible: root.currentGroups.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "Nothing matches. Try another search."
                        font.family: root.fDisplay()
                        font.italic: true
                        font.pixelSize: 24
                        color: root.cream
                        opacity: 0.5
                    }
                }

                // Footer: Bodoni Bold italic for consistency with subtitle.
                Text {
                    x: 28
                    width: root.width - 56
                    text: "Portions are estimates based on standard bartending conventions —\nactual ship pours vary by bar and bartender."
                    font.family: root.fDisplayBold()
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
