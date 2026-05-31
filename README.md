# Tobisk Tag Editor

![Tobisk Tag Editor](Assets/hero.png)

A sleek, native macOS application built with SwiftUI for bulk-editing MP3 metadata. 

**Tobisk Tag Editor** is designed to make organizing Audiobooks and Music albums effortless. Just drop your files, arrange them, and hit "Bake" to write ID3 tags directly to your files.

## Features

- **Native macOS Experience:** Built entirely in Swift and SwiftUI for a blazing fast, native feel.
- **Drag & Drop:** Drop multiple MP3s or whole folders to instantly load them.
- **Smart Sorting:** Automatically sort files by natural naming conventions or their existing ID3 track numbers.
- **Audiobook & Music Modes:** Specialized tagging modes depending on your media type. Maps Book Titles to ID3 Album, Chapter to ID3 Title, Narrator to ID3 Album Artist, and more.
- **Bulk Apply:** Set global fields (like Cover Art, Album, Album Artist) that apply to all tracks, or use "Apply All" and "Set for Empty" on individual fields.
- **Audio Preview:** Integrated audio player to listen to your tracks without leaving the app.
- **Direct ID3 Baking:** Uses `ID3TagEditor` to securely write ID3v2.3 tags directly into your MP3 files.

## Building from Source

This project uses Swift Package Manager.

1. Clone the repository.
2. Open the directory in Xcode or use `swift build` from the command line.
3. Run the target.

## Signed macOS Build

Use the Xcode build script to create a signed app bundle:

```sh
./build-signed.sh --identity "Developer ID Application: Your Name (TEAMID)"
```

The script builds the package with the Xcode Swift toolchain, packages
`dist/Tobisk Tag Editor.app`, signs it with the bundle identifier
`de.tobisk.apps.tag-editor`, verifies the signature, and creates a zip archive.
For a local-only ad-hoc build, use:

```sh
./build-signed.sh --identity -
```

To install the signed app into `/Applications` after building:

```sh
./build-signed.sh --identity "Developer ID Application: Your Name (TEAMID)" --install
```
