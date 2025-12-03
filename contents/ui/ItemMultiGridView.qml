/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

PlasmaComponents.ScrollView {
    id: itemMultiGrid

    anchors {
        top: parent.top
    }

    width: parent.width

    implicitHeight: itemColumn.implicitHeight

    signal keyNavLeft(int subGridIndex)
    signal keyNavRight(int subGridIndex)
    signal keyNavUp
    signal keyNavDown

    property bool grabFocus: false

    property alias model: repeater.model
    property alias count: repeater.count
    property alias flickableItem: flickable
    property Item itemGrid: repeater.count > 0 ? repeater.itemAt(0).itemGrid : null
    property int currentGridIndex: 0

    function subGridAt(index) {
        return repeater.itemAt(index).itemGrid;
    }

    function getCurrentGrid() {
        if (repeater.count > 0 && currentGridIndex >= 0 && currentGridIndex < repeater.count) {
            return subGridAt(currentGridIndex);
        }
        return null;
    }

    function getGridCount() {
        return repeater.count;
    }

    function moveToNextGrid() {
        for (var i = currentGridIndex + 1; i < repeater.count; i++) {
            var grid = subGridAt(i);
            if (grid && grid.count > 0) {
                var oldGrid = getCurrentGrid();
                if (oldGrid) {
                    oldGrid.currentIndex = -1;
                }
                currentGridIndex = i;
                grid.currentIndex = 0;
                return true;
            }
        }
        return false;
    }

    function moveToPreviousGrid(preferredCol) {
        for (var i = currentGridIndex - 1; i >= 0; i--) {
            var grid = subGridAt(i);
            if (grid && grid.count > 0) {
                var oldGrid = getCurrentGrid();
                if (oldGrid) {
                    oldGrid.currentIndex = -1;
                }
                currentGridIndex = i;
                if (preferredCol !== undefined && preferredCol >= 0) {
                    grid.tryActivate(grid.lastRow(), preferredCol);
                } else {
                    grid.currentIndex = grid.count - 1;
                }
                return true;
            }
        }
        return false;
    }

    function moveUp() {
        var currentGrid = getCurrentGrid();
        if (!currentGrid || currentGrid.currentIndex < 0) {
            return false;
        }

        var currentRow = currentGrid.currentRow();
        var currentCol = currentGrid.currentCol();

        if (currentRow > 0) {
            currentGrid.tryActivate(currentRow - 1, currentCol);
            return true;
        } else {
            return moveToPreviousGrid(currentCol);
        }
    }

    function moveDown() {
        var currentGrid = getCurrentGrid();
        if (!currentGrid || currentGrid.currentIndex < 0) {
            return false;
        }

        var currentRow = currentGrid.currentRow();
        var currentCol = currentGrid.currentCol();
        var lastRow = currentGrid.lastRow();

        if (currentRow < lastRow) {
            currentGrid.tryActivate(currentRow + 1, currentCol);
            return true;
        } else {
            return moveToNextGrid();
        }
    }

    function resetNavigation() {
        currentGridIndex = 0;
        for (var i = 0; i < repeater.count; i++) {
            var grid = subGridAt(i);
            if (grid) {
                grid.currentIndex = (i === 0 && grid.count > 0) ? 0 : -1;
            }
        }
    }

    onFocusChanged: {
        if (!focus) {
            for (var i = 0; i < repeater.count; i++) {
                subGridAt(i).focus = false;
            }
        }
    }

    Flickable {
        id: flickable

        flickableDirection: Flickable.VerticalFlick
        contentHeight: itemColumn.implicitHeight

        function subGridAt(index) {
            return repeater.itemAt(index).itemGrid;
        }

        function tryActivate(row, col) { // FIXME TODO: Cleanup messy algo.
            if (contentY > 0) {
                row = 0;
            }

            var target = null;
            var rows = 0;

            for (var i = 0; i < repeater.count; i++) {
                var grid = subGridAt(i);

                if (rows <= row) {
                    target = grid;
                    rows += grid.lastRow() + 2; // Header counts as one.
                } else {
                    break;
                }
            }

            if (target) {
                rows -= (target.lastRow() + 2);
                target.tryActivate(row - rows, col);
            }
        }

        Column {
            id: itemColumn

            width: itemMultiGrid.width - Kirigami.Units.gridUnit

            Repeater {
                id: repeater

                delegate: Item {
                    width: itemColumn.width - Kirigami.Units.gridUnit
                    height: parseInt(repeater.model.modelForRow(index).count) <= 0 ? 0 : headerHeight + gridView.height + (index == repeater.count - 1 ? 0 : footerHeight)
                    opacity: parseInt(repeater.model.modelForRow(index).count) <= 0 ? 0 : 1

                    property int headerHeight: (gridViewLabel.height + gridViewLabelUnderline.height + Kirigami.Units.gridUnit)
                    property int footerHeight: (Math.ceil(headerHeight / cellSize) * cellSize) - headerHeight

                    property Item itemGrid: gridView

                    Kirigami.Heading {
                        id: gridViewLabel

                        anchors.top: parent.top

                        x: Kirigami.Units.smallSpacing
                        width: parent.width - x
                        height: dummyHeading.height

                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        opacity: 1.0

                        color: "white" // FIXME TODO: Respect theming?

                        level: 1

                        text: repeater.model.modelForRow(index).description
                    }

                    KSvg.SvgItem {
                        id: gridViewLabelUnderline

                        anchors.top: gridViewLabel.bottom

                        width: parent.width - Kirigami.Units.gridUnit
                        height: lineSvg.horLineHeight

                        svg: lineSvg
                        elementId: "horizontal-line"
                    }

                    MouseArea {
                        width: parent.width
                        height: parent.height

                        onClicked: root.toggle()
                    }

                    ItemGridView {
                        id: gridView

                        anchors {
                            top: gridViewLabelUnderline.bottom
                            topMargin: Kirigami.Units.gridUnit
                        }

                        width: parent.width
                        height: Math.ceil(count / Math.floor(width / cellSize)) * cellSize

                        cellWidth: cellSize
                        cellHeight: cellSize
                        iconSize: root.iconSize

                        verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

                        model: repeater.model.modelForRow(index)

                        onFocusChanged: {
                            if (focus) {
                                flickable.focus = true;
                            }
                        }

                        onCountChanged: {
                            if (itemMultiGrid.grabFocus && index == 0 && count > 0) {
                                currentIndex = 0;
                                focus = true;
                            }
                        }

                        onCurrentItemChanged: {
                            if (!currentItem) {
                                return;
                            }

                            if (index == 0 && currentRow() === 0) {
                                flickable.contentY = 0;
                                return;
                            }

                            var y = currentItem.y;
                            y = contentItem.mapToItem(flickable.contentItem, 0, y).y;

                            if (y < flickable.contentY) {
                                flickable.contentY = y;
                            } else {
                                y += cellSize;
                                y -= flickable.contentY;
                                y -= itemMultiGrid.height;

                                if (y > 0) {
                                    flickable.contentY += y;
                                }
                            }
                        }

                        onKeyNavLeft: {
                            flickable.keyNavLeft(index);
                        }

                        onKeyNavRight: {
                            flickable.keyNavRight(index);
                        }

                        onKeyNavUp: {
                            if (index > 0) {
                                var prevGrid = subGridAt(index - 1);
                                prevGrid.tryActivate(prevGrid.lastRow(), currentCol());
                            } else {
                                flickable.keyNavUp();
                            }
                        }

                        onKeyNavDown: {
                            if (index < repeater.count - 1) {
                                subGridAt(index + 1).tryActivate(0, currentCol());
                            } else {
                                flickable.keyNavDown();
                            }
                        }
                    }

                    // HACK: Steal wheel events from the nested grid view and forward them to
                    // the ScrollView's internal WheelArea.
                    Kicker.WheelInterceptor {
                        anchors.fill: gridView
                        z: 1

                        destination: findWheelArea(flickable)
                    }
                }
            }
        }
    }
}
