/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import Qt5Compat.GraphicalEffects
// Deliberately imported after QtQuick to avoid missing restoreMode property in Binding. Fix in Qt 6.
import QtQml 2.15

import org.kde.kquickcontrolsaddons 2.0
import org.kde.kwindowsystem 1.0
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.private.shell 2.0
import org.kde.kirigami 2.20 as Kirigami

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.private.kicker 0.1 as Kicker

import "code/tools.js" as Tools

/* TODO
 * Reverse middleRow layout + keyboard nav + filter list text alignment in rtl locales.
 * Keep cursor column when arrow'ing down past non-full trailing rows into a lower grid.
 * Make DND transitions cleaner by performing an item swap instead of index reinsertion.
*/

Kicker.DashboardWindow {
    id: root

    property bool smallScreen: ((Math.floor(width / Kirigami.Units.iconSizes.huge) <= 22) || (Math.floor(height / Kirigami.Units.iconSizes.huge) <= 14))

    property int iconSize: smallScreen ? Kirigami.Units.iconSizes.large : Kirigami.Units.iconSizes.huge
    property int cellSize: iconSize + (2 * Kirigami.Units.iconSizes.sizeForLabels)
        + (2 * Kirigami.Units.smallSpacing)
        + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom,
                        highlightItemSvg.margins.left + highlightItemSvg.margins.right))
    property int columns: Math.floor(((smallScreen ? 85 : 80)/100) * Math.ceil(width / cellSize))
    property bool searching: searchField.text !== ""

    keyEventProxy: searchField
    backgroundColor: Qt.rgba(0, 0, 0, 0.737)

    onKeyEscapePressed: {
        if (searching) {
            searchField.clear();
        } else {
            root.toggle();
        }
    }

    onVisibleChanged: {
        reset();

        if (visible) {
            preloadAllAppsTimer.restart();
        }
    }

    onSearchingChanged: {
        if (!searching) {
            reset();
        } else {
            filterList.currentIndex = -1;
        }
    }

    function reset() {
        searchField.clear();
        systemFavoritesGrid.currentIndex = -1;
        filterList.currentIndex = 0;
        funnelModel.sourceModel = rootModel.modelForRow(0);
        mainGrid.model = funnelModel;
        mainGrid.currentIndex = -1;
        filterListScrollArea.focus = true;
        filterList.model = rootModel;
    }

    mainItem: MouseArea {
        id: rootItem

        anchors.fill: parent

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        Connections {
            target: kicker

            function onReset() {
                if (!root.searching) {
                    filterList.applyFilter();
                    funnelModel.reset();
                }
            }

            function onDragSourceChanged() {
                if (!kicker.dragSource) {
                    // FIXME TODO HACK: Reset all views post-DND to work around
                    // mouse grab bug despite QQuickWindow::mouseGrabberItem==0x0.
                    // Needs a more involved hunt through Qt Quick sources later since
                    // it's not happening with near-identical code in the menu repr.
                    rootModel.refresh();
                }
            }
        }

        Connections {
            target: Plasmoid
            function onUserConfiguringChanged() {
                if (Plasmoid.userConfiguring) {
                    root.hide()
                }
            }
        }

        PlasmaExtras.Menu {
            id: contextMenu

            PlasmaExtras.MenuItem {
                action: Plasmoid.internalAction("configure")
            }
        }

        Kirigami.Heading {
            id: dummyHeading

            visible: false

            width: 0

            level: 1
        }

        TextMetrics {
            id: headingMetrics

            font: dummyHeading.font
        }

        Kicker.FunnelModel {
            id: funnelModel

            onSourceModelChanged: {
                if (mainColumn.visible) {
                    mainGrid.currentIndex = -1;
                    mainGrid.forceLayout();
                }
            }
        }

        Timer {
            id: preloadAllAppsTimer

            property bool done: false

            interval: 1000
            repeat: false

            onTriggered: {
                if (done || root.searching) {
                    return;
                }

                for (var i = 0; i < rootModel.count; ++i) {
                    var model = rootModel.modelForRow(i);

                    if (model.description === "KICKER_ALL_MODEL") {
                        allAppsGrid.model = model;
                        done = true;
                        break;
                    }
                }
            }

            function defer() {
                if (running && !done) {
                    restart();
                }
            }
        }

        Kicker.ContainmentInterface {
            id: containmentInterface
        }

        TextInput {
            id: searchField

            width: 0
            height: 0

            visible: false

            persistentSelection: true

            onTextChanged: {
                runnerModel.query = searchField.text;
            }

            function clear() {
                text = "";
            }

            onSelectionStartChanged: Qt.callLater(searchHeading.updateSelection)
            onSelectionEndChanged: Qt.callLater(searchHeading.updateSelection)
        }

        TextEdit {
            id: searchHeading

            anchors {
                horizontalCenter: parent.horizontalCenter
            }

            y: (middleRow.anchors.topMargin / 2) - (root.smallScreen ? (height/10) : 0)

            font.pointSize: dummyHeading.font.pointSize * 1.5
            wrapMode: Text.NoWrap
            opacity: 1.0

            selectByMouse: false
            cursorVisible: false

            color: "white"

            text: root.searching ? i18n("Searching for '%1'", searchField.text) : i18nc("@info:placeholder as in, 'start typing to initiate a search'", "Type to search…")

            function updateSelection() {
                if (!searchField.selectedText) {
                    return;
                }

                var delta = text.lastIndexOf(searchField.text, text.length - 2);
                searchHeading.select(searchField.selectionStart + delta, searchField.selectionEnd + delta);
            }
        }

        PlasmaComponents.ToolButton {
            id: cancelSearchButton

            anchors {
                left: searchHeading.right
                leftMargin: Kirigami.Units.gridUnit
                verticalCenter: searchHeading.verticalCenter
            }

            width: Kirigami.Units.iconSizes.large
            height: width

            visible: (searchField.text !== "")

            icon.name: "edit-clear"
            flat: false

            onClicked: searchField.clear();

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;

                    if (runnerModel.count) {
                        mainColumn.tryActivate(0, 0);
                    } else {
                        systemFavoritesGrid.tryActivate(0, 0);
                    }
                } else if (event.key === Qt.Key_Backtab) {
                    event.accepted = true;

                    systemFavoritesGrid.tryActivate(0, 0);
                }
            }
        }

        Row {
            id: middleRow

            anchors {
                top: parent.top
                topMargin: Kirigami.Units.gridUnit * (smallScreen ? 8 : 10)
                bottom: parent.bottom
                bottomMargin: (Kirigami.Units.gridUnit * 2)
                horizontalCenter: parent.horizontalCenter
            }

            width: (root.columns * root.cellSize) + (2 * spacing)
            height: parent.height

            spacing: Kirigami.Units.gridUnit * 2

            Item {
                id: mainColumn

                anchors.top: parent.top

                width: (columns * root.cellSize) + Kirigami.Units.gridUnit
                height: Math.floor(parent.height / root.cellSize) * root.cellSize + mainGridContainer.headerHeight


                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    Kirigami.Theme.inherit: false

                property int columns: root.columns
                property Item visibleGrid: mainGrid

                function tryActivate(row, col) {
                    if (visibleGrid) {
                        visibleGrid.tryActivate(row, col);
                    }
                }

                Item {
                    id: mainGridContainer

                    anchors.fill: parent
                    z: (opacity === 1.0) ? 1 : 0

                    visible: opacity !== 0.0

                    property int headerHeight: mainColumnLabel.height + mainColumnLabelUnderline.height + Kirigami.Units.gridUnit

                    opacity: {
                        if (root.searching) {
                            return 0.0;
                        }

                        if (filterList.allApps) {
                            return 0.0;
                        }

                        return 1.0;
                    }

                    onOpacityChanged: {
                        if (opacity === 1.0) {
                            mainColumn.visibleGrid = mainGrid;
                        }
                    }

                    Kirigami.Heading {
                        id: mainColumnLabel

                        anchors {
                            top: parent.top
                        }

                        x: Kirigami.Units.smallSpacing
                        width: parent.width - x

                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        opacity: 1.0

                        color: "white"

                        level: 1

                        text: funnelModel.description
                    }

                    KSvg.SvgItem {
                        id: mainColumnLabelUnderline

                        visible: mainGrid.count

                        anchors {
                            top: mainColumnLabel.bottom
                        }

                        width: parent.width - Kirigami.Units.gridUnit
                        height: lineSvg.horLineHeight

                        svg: lineSvg
                        elementId: "horizontal-line"
                    }

                    ItemGridView {
                        id: mainGrid

                        anchors {
                            top: mainColumnLabelUnderline.bottom
                            topMargin: Kirigami.Units.gridUnit
                        }

                        width: parent.width
                        height: systemFavoritesGrid.y + systemFavoritesGrid.height - mainGridContainer.headerHeight

                        cellWidth: root.cellSize
                        cellHeight: cellWidth
                        iconSize: root.iconSize

                        model: funnelModel

                        onCurrentIndexChanged: {
                            preloadAllAppsTimer.defer();
                        }

                        onKeyNavLeft: {
                            var row = currentRow();
                            var target = systemFavoritesGrid;
                            var targetRow = row;
                            target.tryActivate(targetRow, favoritesColumn.columns - 1);
                        }

                        onKeyNavRight: {
                            filterListScrollArea.focus = true;
                        }
                    }
                }

                ItemMultiGridView {
                    id: allAppsGrid

                    anchors {
                        top: parent.top
                    }

                    z: (opacity === 1.0) ? 1 : 0
                    width: parent.width
                    height: systemFavoritesGrid.y + systemFavoritesGrid.height

                    visible: opacity !== 0.0

                    opacity: filterList.allApps ? 1.0 : 0.0

                    onOpacityChanged: {
                        if (opacity === 1.0) {
                            allAppsGrid.flickableItem.contentY = 0;
                            mainColumn.visibleGrid = allAppsGrid;
                        }
                    }

                    onKeyNavLeft: {
                        var row = 0;

                        for (var i = 0; i < subGridIndex; i++) {
                            row += subGridAt(i).lastRow() + 2; // Header counts as one.
                        }

                        row += subGridAt(subGridIndex).currentRow();

                        var target = systemFavoritesGrid;
                        var targetRow = row;
                        target.tryActivate(targetRow, favoritesColumn.columns - 1);
                    }

                    onKeyNavRight: {
                        filterListScrollArea.focus = true;
                    }
                }

                ItemMultiGridView {
                    id: runnerGrid

                    anchors {
                        top: parent.top
                    }

                    z: (opacity === 1.0) ? 1 : 0
                    width: parent.width
                    height: Math.min(implicitHeight, systemFavoritesGrid.y + systemFavoritesGrid.height)

                    visible: opacity !== 0.0

                    model: runnerModel

                    grabFocus: true

                    opacity: root.searching ? 1.0 : 0.0

                    onOpacityChanged: {
                        if (opacity === 1.0) {
                            mainColumn.visibleGrid = runnerGrid;
                        }
                    }

                    onKeyNavLeft: {
                        var row = 0;

                        for (var i = 0; i < subGridIndex; i++) {
                            row += subGridAt(i).lastRow() + 2; // Header counts as one.
                        }

                        row += subGridAt(subGridIndex).currentRow();

                        var target = systemFavoritesGrid;
                        var targetRow = row;
                        target.tryActivate(targetRow, favoritesColumn.columns - 1);
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        event.accepted = true;

                        if (filterList.enabled) {
                            filterList.forceActiveFocus();
                        } else {
                            systemFavoritesGrid.tryActivate(0, 0);
                        }
                    } else if (event.key === Qt.Key_Backtab) {
                        event.accepted = true;

                        if (root.searching) {
                            cancelSearchButton.focus = true;
                        } else {
                            systemFavoritesGrid.tryActivate(0, 0);
                        }
                    }
                }
            }

            Item {
                id: favoritesColumn

                width: (columns * root.cellSize) + Kirigami.Units.gridUnit
                height: parent.height

                property int columns: 1

                ItemGridView {
                    id: systemFavoritesGrid

                    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    Kirigami.Theme.inherit: false

                    anchors {
                        top: parent.top
                    }

                    property int rows: Math.ceil(count / Math.floor(width / root.cellSize))

                    width: parent.width
                    height: parent.height

                    cellWidth: root.cellSize
                    cellHeight: root.cellSize
                    iconSize: root.iconSize

                    model: systemFavorites

                    dropEnabled: true

                    onCurrentIndexChanged: {
                        preloadAllAppsTimer.defer();
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;

                            if (root.searching && !runnerModel.count) {
                                cancelSearchButton.focus = true;
                            } else {
                                mainColumn.tryActivate(0, 0);
                            }
                        } else if (event.key === Qt.Key_Backtab) {
                            event.accepted = true;

                            if (filterList.enabled) {
                                filterList.forceActiveFocus();
                            } else if (root.searching && !runnerModel.count) {
                                cancelSearchButton.focus = true;
                            } else {
                                mainColumn.tryActivate(0, 0);
                            }
                        }
                    }
                }
            }

            Item {
                id: filterListColumn

                PlasmaComponents.ScrollView {
                    id: filterListScrollArea

                    height: mainGrid.height

                    enabled: !root.searching

                    ListView {
                        id: filterList

                        focus: true

                        property bool allApps: true

                        model: rootModel

                        onCurrentIndexChanged: applyFilter()

                        function applyFilter() {
                            if (!root.searching && currentIndex >= 0) {
                                if (preloadAllAppsTimer.running) {
                                    preloadAllAppsTimer.stop();
                                }

                                var model = rootModel.modelForRow(currentIndex);

                                if (model.description === "KICKER_ALL_MODEL") {
                                    allAppsGrid.model = model;
                                    allApps = true;
                                    funnelModel.sourceModel = null;
                                    preloadAllAppsTimer.done = true;
                                } else {
                                    funnelModel.sourceModel = model;
                                    allApps = false;
                                }
                            } else {
                                funnelModel.sourceModel = null;
                                allApps = false;
                            }
                        }
                    }
                }
            }
        }

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.open(mouse.x, mouse.y);
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.toggle();
            }
        }
    }

    Component.onCompleted: {
        rootModel.refresh();
    }
}
