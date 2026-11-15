# Themes

A theme sets the colours, line widths, corner shapes and sizes of the grid panel. GridSnap has ten built-in themes, and you can make your own.

Every theme has a light version and a dark version. GridSnap uses the one that matches macOS, so the panel changes when your Mac switches between light and dark.

## Choose a theme

Open Settings and choose a theme from the **Theme** menu. The built-in themes are Default, Graphite, Outline, Tiles, Blueprint, Terminal, Solarized, Nord, Sunset and High Contrast.

To keep the panel light or dark whatever macOS does, set **Appearance** to Light or Dark.

## Make your own theme

1. In Settings, choose the built-in theme that is closest to what you want.
2. Click **Edit a Copy…**. GridSnap saves a copy as a file, switches to it, and opens it in your text editor.
3. Change the file and save it.
4. Open the grid. GridSnap reads the file every time the grid opens, so you see your changes at once.

Your themes are `.json` files in `~/Library/Application Support/GridSnap/Themes`. The **Theme** menu lists them under the built-in themes, and **Open Themes Folder** at the bottom of the menu shows the folder in Finder.

- A theme's name is its file name. To rename a theme, rename the file, then choose it again in Settings.
- To share a theme, send the file. To install one, put the file in the folder.
- To delete a theme, delete the file. If that theme was in use, GridSnap goes back to Default.

## The theme file

This theme draws square outlined cells in amber and leaves everything else as it is in Default:

```json
{
  "cell":      { "fill": "none", "stroke": "#FFB000 40%", "lineWidth": 1, "radius": 0 },
  "selection": { "fill": "#FFB000 85%", "stroke": "#FFFFFF", "lineWidth": 2, "radius": 0 },
  "spacing": 2,
  "light": {
    "selection": { "stroke": "#7A5200" }
  }
}
```

A theme only needs to hold what it changes. Anything you leave out comes from the Default theme.

### Light and dark

- A value at the top level applies in both versions.
- A value inside `"dark"` or `"light"` applies only in that version, and wins over the top level.

In the example, the selection has a white outline, except in the light version, where it is brown.

A file from **Edit a Copy…** lists every value of both versions, so everything in it is inside `"dark"` or `"light"`.

### Elements

| Element | What it is | Uses |
|---|---|---|
| `panel` | The panel behind everything. A fill is drawn over the glass, so a see-through colour tints the glass and a solid colour hides it. | `fill`, `stroke`, `lineWidth`, `radius` |
| `header` | The app's name above the cells | `text` |
| `cell` | One cell of the grid | `fill`, `stroke`, `lineWidth`, `radius` |
| `ghost` | A window you snapped earlier | `fill`, `stroke`, `lineWidth`, `radius` |
| `selection` | The cells you selected | `fill`, `stroke`, `lineWidth`, `radius` |
| `pending` | The cells that the window covers when the grid opens, before you select anything | `fill`, `stroke`, `lineWidth`, `radius` |
| `hover` | The cell under the pointer, before you start a drag. Default gives it no fill and no stroke, so nothing is drawn. | `fill`, `stroke`, `lineWidth`, `radius` |
| `preset` | A line in the preset list. The fill and stroke show while you click it. | `fill`, `stroke`, `lineWidth`, `radius`, `text` |
| `keycap` | The number beside a preset | `fill`, `stroke`, `lineWidth`, `radius`, `text` |
| `focusRing` | The outline of the panel that has the keyboard, when you have more than one display | `stroke`, `lineWidth` |

### Properties

| Property | Value |
|---|---|
| `fill` | The colour inside the shape |
| `stroke` | The colour of the outline |
| `text` | The colour of the text |
| `lineWidth` | The width of the outline, in points. `0` draws no outline. |
| `radius` | How round the corners are, in points. `0` gives square corners, and a large number gives a pill or a circle. |

`"spacing"` is not part of an element. It is the space between two cells, in points. `0` makes the cells touch, except at the halves, thirds and quarters of the display, where the gaps are wider. To remove those gaps too, turn off **Wider gaps at halves, thirds and quarters** in Settings.

### Layout

`"layout"` is not part of an element either. It is an object that sets the sizes of the panel:

| Key | Value |
|---|---|
| `width` | The width of the panel, in points |
| `cellsHeight` | The height of the cell area, in points. If you leave it out, the cell area has the shape of the display. |
| `padding` | The space between the edge of the panel and the cells, in points |
| `headerTop` | The space above the app's icon, in points |
| `iconSize` | The size of the app's icon, in points |
| `headerGap` | The space between the app's icon and the cells, in points |
| `nameSize` | The font size of the app's name, in points |
| `dimOthers` | How visible the panels on the other displays are, as a percentage in quotes. `"100%"` does not dim them. Below that, the panel under the pointer takes the keyboard. |
| `shadow` | `true` gives the panel a shadow. Use it only with `"glass": false`. |
| `glass` | `false` removes the glass behind the panel, so that the panel's `fill` is all that you see behind the cells |

This layout gives a small panel of a fixed size, with no glass, and dims the panels on the other displays:

```json
"layout": { "width": 320, "cellsHeight": 195, "padding": 20, "headerTop": 20, "iconSize": 30, "headerGap": 12, "nameSize": 18, "dimOthers": "60%", "shadow": true, "glass": false }
```

### Colours

| You write | You get |
|---|---|
| `"#FFB000"` | A colour, as red, green and blue in hexadecimal |
| `"#FFB000 40%"` | The same colour at 40% opacity |
| `"#FFB00066"` | The same again, with the opacity as a fourth hexadecimal pair |
| `"accent"` | The accent colour you chose in System Settings |
| `"accent 30%"` | The accent colour at 30% opacity |
| `"none"` | Nothing. Use it to remove a fill or a stroke that Default has. |

## If a theme has a mistake

GridSnap does not use a theme file that it cannot read. The grid appears in the Default theme, and Settings shows what is wrong in red under the **Theme** menu, for example `cell.fill: “#GGB000” is not a colour.` Fix the file, save it, and open the grid again.

A misspelt name, such as `"sellection"`, counts as a mistake, so that a typing error cannot quietly do nothing.

The file is JSON. GridSnap also accepts `//` comments and a comma after the last item.
