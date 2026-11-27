# Building GridSnap

## What you need

You need the Xcode Command Line Tools with the macOS 26 SDK. GridSnap has no Xcode project. The build script compiles the Swift files directly with `swiftc`.

## Build the app

```sh
git clone https://github.com/konieczkow/gridsnap.git
cd gridsnap
./build.sh            # builds build/GridSnap.app
./build.sh install    # also copies it to /Applications
open /Applications/GridSnap.app
```

## Keep the Accessibility permission between builds

macOS ties the Accessibility permission to the code signature of the app. Without a signing certificate, the build script uses an ad-hoc signature, which changes with every build. You would then have to grant the permission again after each build.

To avoid this, create a self-signed certificate once:

1. Open Keychain Access and choose Certificate Assistant › Create a Certificate.
2. Set the certificate type to "Code Signing" and name the certificate `GridSnap Dev`.

The build script finds this certificate and signs the app with it. To sign with another identity, run `CODESIGN_IDENTITY="name" ./build.sh`.

## Source files

All the code is in `Sources/`:

| File | What it holds |
|---|---|
| `main.swift` | Startup |
| `AX.swift` | The code that finds and moves windows |
| `Screens.swift` | The area of each display that windows may use, without the menu bar and the Dock |
| `Grid.swift` | The grid overlay |
| `Themes.swift` | The code that reads a theme and finds its problems |
| `BuiltinThemes.swift` | The ten built-in themes, as JSON |
| `Presets.swift` | Presets |
| `Hotkeys.swift` | Global shortcuts |
| `ShortcutButton.swift` | The button that records a shortcut |
| `SettingsWindow.swift` | The Settings window |
| `Menu.swift` | The menu bar menu |
| `Defaults.swift` | Stored settings |

## App icon

`Resources/icon.png` is the source of the app icon. If you change it, use `iconutil` to regenerate `Resources/AppIcon.icns` from it.
