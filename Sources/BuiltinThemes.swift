// The built-in themes, in the order Settings lists them. Default is complete; the others hold only what they change.
let builtinThemes: [(name: String, json: String)] = [
("Default", """
{
  "panel":     { "radius": 18 },
  "cell":      { "lineWidth": 1, "radius": 4 },
  "ghost":     { "lineWidth": 1, "radius": 4 },
  "selection": { "fill": "accent 85%", "lineWidth": 1.5, "radius": 4 },
  "pending":   { "fill": "accent 30%", "stroke": "accent", "lineWidth": 2, "radius": 4 },
  "preset":    { "radius": 5 },
  "keycap":    { "radius": 4 },
  "focusRing": { "lineWidth": 2 },
  "hover":     {},
  "layout":    { "width": 480, "padding": 10, "headerTop": 16, "iconSize": 36, "headerGap": 10, "nameSize": 20, "dimOthers": "100%", "shadow": false, "glass": true },
  "spacing": 4,
  "dark": {
    "header":    { "text": "#FFFFFF 90%" },
    "cell":      { "fill": "#FFFFFF 10%", "stroke": "#FFFFFF 20%" },
    "ghost":     { "fill": "#FFFFFF 25%", "stroke": "#FFFFFF 45%" },
    "selection": { "stroke": "#FFFFFF 70%" },
    "preset":    { "fill": "#FFFFFF 15%", "text": "#FFFFFF 85%" },
    "keycap":    { "fill": "#FFFFFF 18%", "text": "#FFFFFF" },
    "focusRing": { "stroke": "#FFFFFF 80%" }
  },
  "light": {
    "panel":     { "fill": "#FFFFFF 50%" },
    "header":    { "text": "#000000 85%" },
    "cell":      { "fill": "#000000 6%", "stroke": "#000000 15%" },
    "ghost":     { "fill": "#000000 18%", "stroke": "#000000 38%" },
    "selection": { "stroke": "#000000 30%" },
    "preset":    { "fill": "#000000 10%", "text": "#000000 80%" },
    "keycap":    { "fill": "#000000 12%", "text": "#000000 85%" },
    "focusRing": { "stroke": "#000000 55%" }
  }
}
"""),
("Graphite", """
{
  "dark": {
    "panel":     { "fill": "#000000 30%" },
    "ghost":     { "fill": "#FFFFFF 18%", "stroke": "#FFFFFF 38%" },
    "selection": { "fill": "#FFFFFF 85%", "stroke": "#FFFFFF" },
    "pending":   { "fill": "#FFFFFF 12%", "stroke": "#FFFFFF 85%" }
  },
  "light": {
    "ghost":     { "fill": "#000000 14%", "stroke": "#000000 32%" },
    "selection": { "fill": "#000000 75%", "stroke": "#000000" },
    "pending":   { "fill": "#000000 8%", "stroke": "#000000 75%" }
  }
}
"""),
("Outline", """
{
  "cell":      { "fill": "none", "radius": 6 },
  "ghost":     { "radius": 6 },
  "selection": { "fill": "accent 25%", "stroke": "accent", "lineWidth": 2.5, "radius": 6 },
  "pending":   { "fill": "none", "stroke": "accent 75%", "lineWidth": 1.5, "radius": 6 },
  "keycap":    { "fill": "none", "lineWidth": 1 },
  "spacing": 6,
  "dark": {
    "cell":      { "stroke": "#FFFFFF 32%" },
    "ghost":     { "fill": "#FFFFFF 10%", "stroke": "#FFFFFF 60%" },
    "keycap":    { "stroke": "#FFFFFF 45%" }
  },
  "light": {
    "cell":      { "stroke": "#000000 28%" },
    "ghost":     { "fill": "#000000 7%", "stroke": "#000000 55%" },
    "keycap":    { "stroke": "#000000 40%" }
  }
}
"""),
("Tiles", """
{
  "cell":      { "stroke": "none", "radius": 3 },
  "ghost":     { "stroke": "none", "radius": 3 },
  "selection": { "fill": "accent", "stroke": "none", "radius": 3 },
  "pending":   { "fill": "accent 45%", "stroke": "none", "radius": 3 },
  "spacing": 6,
  "dark": {
    "cell":      { "fill": "#FFFFFF 14%" },
    "ghost":     { "fill": "#FFFFFF 36%" }
  },
  "light": {
    "cell":      { "fill": "#000000 9%" },
    "ghost":     { "fill": "#000000 26%" }
  }
}
"""),
("Blueprint", """
{
  "panel":     { "lineWidth": 1, "radius": 8 },
  "cell":      { "fill": "none", "lineWidth": 0.5, "radius": 0 },
  "ghost":     { "radius": 0 },
  "selection": { "lineWidth": 2, "radius": 0 },
  "pending":   { "lineWidth": 1.5, "radius": 0 },
  "preset":    { "radius": 0 },
  "keycap":    { "radius": 0 },
  "spacing": 0,
  "dark": {
    "panel":     { "fill": "#0C3B8C 82%", "stroke": "#FFFFFF 40%" },
    "header":    { "text": "#FFFFFF" },
    "cell":      { "stroke": "#FFFFFF 45%" },
    "ghost":     { "fill": "#FFFFFF 16%", "stroke": "#FFFFFF 75%" },
    "selection": { "fill": "#FFFFFF 35%", "stroke": "#FFFFFF" },
    "pending":   { "fill": "#7FD4FF 18%", "stroke": "#7FD4FF" },
    "preset":    { "fill": "#FFFFFF 18%", "text": "#FFFFFF 90%" },
    "keycap":    { "fill": "#FFFFFF 22%", "text": "#FFFFFF" },
    "focusRing": { "stroke": "#FFFFFF" }
  },
  "light": {
    "panel":     { "fill": "#EEF4FF 88%", "stroke": "#1D4FC4 45%" },
    "header":    { "text": "#143A94" },
    "cell":      { "stroke": "#1D4FC4 45%" },
    "ghost":     { "fill": "#1D4FC4 12%", "stroke": "#1D4FC4 70%" },
    "selection": { "fill": "#1D4FC4 30%", "stroke": "#1D4FC4" },
    "pending":   { "fill": "#0A84C4 14%", "stroke": "#0A84C4" },
    "preset":    { "fill": "#1D4FC4 14%", "text": "#143A94" },
    "keycap":    { "fill": "#1D4FC4 16%", "text": "#143A94" },
    "focusRing": { "stroke": "#1D4FC4" }
  }
}
"""),
("Terminal", """
{
  "panel":     { "lineWidth": 1, "radius": 4 },
  "cell":      { "fill": "none", "radius": 0 },
  "ghost":     { "radius": 0 },
  "selection": { "lineWidth": 1, "radius": 0 },
  "pending":   { "lineWidth": 1.5, "radius": 0 },
  "preset":    { "radius": 0 },
  "keycap":    { "radius": 0 },
  "spacing": 2,
  "dark": {
    "panel":     { "fill": "#000000 88%", "stroke": "#33FF66 45%" },
    "header":    { "text": "#33FF66" },
    "cell":      { "stroke": "#33FF66 35%" },
    "ghost":     { "fill": "#33FF66 14%", "stroke": "#33FF66 65%" },
    "selection": { "fill": "#33FF66 85%", "stroke": "#33FF66" },
    "pending":   { "fill": "#33FF66 12%", "stroke": "#33FF66" },
    "preset":    { "fill": "#33FF66 20%", "text": "#33FF66 90%" },
    "keycap":    { "fill": "#33FF66 22%", "text": "#33FF66" },
    "focusRing": { "stroke": "#33FF66" }
  },
  "light": {
    "panel":     { "fill": "#F5F2E7 92%", "stroke": "#0B6B2B 45%" },
    "header":    { "text": "#0B5A24" },
    "cell":      { "stroke": "#0B6B2B 35%" },
    "ghost":     { "fill": "#0B6B2B 12%", "stroke": "#0B6B2B 60%" },
    "selection": { "fill": "#0B6B2B 85%", "stroke": "#0B6B2B" },
    "pending":   { "fill": "#0B6B2B 10%", "stroke": "#0B6B2B" },
    "preset":    { "fill": "#0B6B2B 15%", "text": "#0B5A24" },
    "keycap":    { "fill": "#0B6B2B 16%", "text": "#0B5A24" },
    "focusRing": { "stroke": "#0B6B2B" }
  }
}
"""),
("Solarized", """
{
  "dark": {
    "panel":     { "fill": "#002B36 88%" },
    "header":    { "text": "#93A1A1" },
    "cell":      { "fill": "#073642", "stroke": "#586E75 55%" },
    "ghost":     { "fill": "#586E75 55%", "stroke": "#839496 70%" },
    "selection": { "fill": "#268BD2 90%", "stroke": "#FDF6E3 60%" },
    "pending":   { "fill": "#B58900 30%", "stroke": "#B58900" },
    "preset":    { "fill": "#586E75 45%", "text": "#93A1A1" },
    "keycap":    { "fill": "#586E75 60%", "text": "#FDF6E3" },
    "focusRing": { "stroke": "#93A1A1" }
  },
  "light": {
    "panel":     { "fill": "#FDF6E3 90%" },
    "header":    { "text": "#586E75" },
    "cell":      { "fill": "#EEE8D5", "stroke": "#93A1A1 55%" },
    "ghost":     { "fill": "#93A1A1 45%", "stroke": "#657B83 70%" },
    "selection": { "fill": "#268BD2 90%", "stroke": "#268BD2" },
    "pending":   { "fill": "#B58900 28%", "stroke": "#B58900" },
    "preset":    { "fill": "#93A1A1 35%", "text": "#586E75" },
    "keycap":    { "fill": "#93A1A1 45%", "text": "#073642" },
    "focusRing": { "stroke": "#657B83" }
  }
}
"""),
("Nord", """
{
  "dark": {
    "panel":     { "fill": "#2E3440 88%" },
    "header":    { "text": "#ECEFF4" },
    "cell":      { "fill": "#3B4252", "stroke": "#4C566A" },
    "ghost":     { "fill": "#D8DEE9 22%", "stroke": "#D8DEE9 55%" },
    "selection": { "fill": "#88C0D0 90%", "stroke": "#ECEFF4 70%" },
    "pending":   { "fill": "#88C0D0 25%", "stroke": "#88C0D0" },
    "preset":    { "fill": "#3B4252", "text": "#D8DEE9" },
    "keycap":    { "fill": "#4C566A", "text": "#ECEFF4" },
    "focusRing": { "stroke": "#D8DEE9" }
  },
  "light": {
    "panel":     { "fill": "#ECEFF4 90%" },
    "header":    { "text": "#2E3440" },
    "cell":      { "fill": "#D8DEE9 70%", "stroke": "#4C566A 25%" },
    "ghost":     { "fill": "#4C566A 28%", "stroke": "#4C566A 55%" },
    "selection": { "fill": "#5E81AC 90%", "stroke": "#5E81AC" },
    "pending":   { "fill": "#5E81AC 25%", "stroke": "#5E81AC" },
    "preset":    { "fill": "#D8DEE9", "text": "#3B4252" },
    "keycap":    { "fill": "#4C566A 22%", "text": "#2E3440" },
    "focusRing": { "stroke": "#4C566A 70%" }
  }
}
"""),
("Sunset", """
{
  "panel":     { "radius": 22 },
  "cell":      { "radius": 8 },
  "ghost":     { "radius": 8 },
  "selection": { "radius": 8 },
  "pending":   { "radius": 8 },
  "preset":    { "radius": 8 },
  "keycap":    { "radius": 8 },
  "spacing": 5,
  "dark": {
    "panel":     { "fill": "#3B1028 70%" },
    "header":    { "text": "#FFE6D6" },
    "cell":      { "fill": "#FF9E7A 14%", "stroke": "#FF9E7A 28%" },
    "ghost":     { "fill": "#FF9E7A 32%", "stroke": "#FFC2A8 55%" },
    "selection": { "fill": "#FF6B4A 90%", "stroke": "#FFE0C7 80%" },
    "pending":   { "fill": "#FF4F8B 28%", "stroke": "#FF4F8B" },
    "preset":    { "fill": "#FF9E7A 20%", "text": "#FFE6D6 90%" },
    "keycap":    { "fill": "#FF9E7A 28%", "text": "#FFF3EA" },
    "focusRing": { "stroke": "#FFC2A8 85%" }
  },
  "light": {
    "panel":     { "fill": "#FFF1E6 85%" },
    "header":    { "text": "#7A2E12" },
    "cell":      { "fill": "#E8552D 10%", "stroke": "#E8552D 22%" },
    "ghost":     { "fill": "#E8552D 24%", "stroke": "#C2410C 45%" },
    "selection": { "fill": "#F0562E 90%", "stroke": "#C2410C" },
    "pending":   { "fill": "#E0457B 22%", "stroke": "#E0457B" },
    "preset":    { "fill": "#E8552D 15%", "text": "#7A2E12" },
    "keycap":    { "fill": "#E8552D 20%", "text": "#7A2E12" },
    "focusRing": { "stroke": "#C2410C 70%" }
  }
}
"""),
("High Contrast", """
{
  "panel":     { "lineWidth": 2 },
  "cell":      { "fill": "none", "lineWidth": 2 },
  "ghost":     { "lineWidth": 2 },
  "selection": { "lineWidth": 3 },
  "pending":   { "fill": "none", "lineWidth": 3 },
  "focusRing": { "lineWidth": 4 },
  "spacing": 6,
  "dark": {
    "panel":     { "fill": "#000000", "stroke": "#FFFFFF" },
    "header":    { "text": "#FFFFFF" },
    "cell":      { "stroke": "#FFFFFF" },
    "ghost":     { "fill": "#FFFFFF 40%", "stroke": "#FFFFFF" },
    "selection": { "fill": "#FFD60A", "stroke": "#FFFFFF" },
    "pending":   { "stroke": "#FFD60A" },
    "preset":    { "fill": "#FFFFFF 30%", "text": "#FFFFFF" },
    "keycap":    { "fill": "#FFFFFF", "text": "#000000" },
    "focusRing": { "stroke": "#FFD60A" }
  },
  "light": {
    "panel":     { "fill": "#FFFFFF", "stroke": "#000000" },
    "header":    { "text": "#000000" },
    "cell":      { "stroke": "#000000" },
    "ghost":     { "fill": "#000000 30%", "stroke": "#000000" },
    "selection": { "fill": "#0040DD", "stroke": "#000000" },
    "pending":   { "stroke": "#0040DD" },
    "preset":    { "fill": "#000000 20%", "text": "#000000" },
    "keycap":    { "fill": "#000000", "text": "#FFFFFF" },
    "focusRing": { "stroke": "#0040DD" }
  }
}
"""),
]
