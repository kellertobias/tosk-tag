# Tosk Tag

![Tosk Tag](Assets/hero.png)

A native macOS SwiftUI app for bulk-editing MP3 metadata.

Tosk Tag is designed for organizing audiobook chapters and music albums. Drop files or folders into the app, arrange tracks, preview audio, set global metadata, and bake ID3 tags directly into the MP3 files.

## Features

- Native SwiftUI macOS interface.
- Drag-and-drop loading for MP3 files and folders.
- Natural filename sorting and existing-track-number sorting.
- Audiobook and music tagging modes.
- Bulk fields for album, album artist, cover art, and other repeated values.
- Apply-all and set-empty helpers for per-track fields.
- Integrated audio preview.
- Direct ID3v2.3 writing through `ID3TagEditor`.

## Screenshots

![Tosk Tag screenshot](screenshot.png)

## Building from Source

This project uses Swift Package Manager.

```sh
swift build
swift run TagEditor
```

You can also open the package directory in Xcode and run the `TagEditor` target.

## Signed macOS Build

Use the Xcode build script to create a signed app bundle:

```sh
./build-signed.sh --identity "Developer ID Application: Your Name (TEAMID)"
```

The script builds the package with the Xcode Swift toolchain, packages `dist/Tobisk Tag Editor.app`, signs it with the bundle identifier `de.tobisk.apps.tag-editor`, verifies the signature, and creates a zip archive.

For a local-only ad-hoc build, use:

```sh
./build-signed.sh --identity -
```

To install the signed app into `/Applications` after building:

```sh
./build-signed.sh --identity "Developer ID Application: Your Name (TEAMID)" --install
```

## License

Tosk Tag is released under the MIT License. See [LICENSE](LICENSE).
