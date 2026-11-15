# Using GridSnap

GridSnap moves and resizes one window at a time. Unless you change it in [Settings](#settings), this is the focused window.

## Snap a window with the mouse

Press ⌃⌥D (Control-Option-D). A grid panel appears on every display. The panel on the window's display outlines the cells that the window covers now.

Click a cell, or drag across the cells you want. The window follows your drag and snaps when you release. Wider gaps between the cells mark the halves, thirds and quarters of the display.

If your drag leaves the cells but stays on the panel, the nearest cells stay selected. If your drag leaves the panel, the window returns to where it was, and releasing there cancels the snap.

## Snap a window with the keyboard

With the grid open, you can use these keys:

| Key | What it does |
|---|---|
| Arrow keys | Move the selection |
| Shift+→ or Shift+↑ | Make the selection larger |
| Shift+← or Shift+↓ | Make the selection smaller |
| Return | Snap the window to the selection |
| Tab | Move the selection to the next display |
| 1 to 9 | Apply a [preset](#presets) |
| Esc | Cancel |

The selection starts on the cells that the window covers now. If you press Return without changing the selection, the window aligns to the grid.

## Cancel

To cancel, press Esc, click anywhere outside the panel, or drag outside the panel and release. The window returns to where it was.

## Use more than one display

Each display has its own grid panel. When you select cells on a panel, the window snaps to that panel's display. To move a window to another display, drag on that display's panel.

The keyboard starts on the panel of the display that holds the window. Press Tab to move the selection, and the window with it, to the next display.

A preset's shortcut snaps the window on the display that already holds it.

## Presets

A preset is a saved area, such as the left half of the display. A Full screen preset on ⌃⌥F is built in.

To save a preset, select an area on the grid and hold Shift while you release the mouse or press Return. You can also click **+** in Settings.

You can apply a preset in three ways:

- Press its shortcut, if it has one.
- Choose it from the Presets menu in the GridSnap menu.
- Open the grid and press a number key from 1 to 9. If the preset list is shown under the cells, you can also click the preset there.

## Undo a snap

Press ⌃⌥Z to put the window back where it was before the last snap. Press ⌃⌥Z again to redo the snap.

## Settings

To open Settings, click the GridSnap icon in the menu bar and choose **Settings…**.

| Setting | What it controls |
|---|---|
| Show grid | The shortcut that opens the grid |
| Undo snap | The shortcut that undoes the last snap |
| Columns and Rows | The size of the grid |
| Gap | The space, in points, between snapped windows |
| Appearance | Whether the panel is light, dark, or matches macOS |
| Theme | The colours and shapes of the panel. [Themes](themes.md) explains how to make your own. |
| Show | Whether the panel shows the app's icon and name above the cells, the preset list under them, and the wider gaps that mark the halves, thirds and quarters |
| Target | Whether GridSnap moves the focused window or the window under the cursor |
| Presets | Your presets. You can change a preset's name and shortcut in the table. To remove a preset, select it and click **−**. |
