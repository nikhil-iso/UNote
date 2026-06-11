# UNote

UNote is a local-only SwiftUI/PencilKit note-taking app scaffold for iPadOS 17+.

Current implementation includes:

- Xcode app and unit test targets.
- Local notebook folders in the app Documents directory.
- `metadata.json`, `pages/`, and thumbnail generation.
- PencilKit editing through `PKCanvasView` and `PKToolPicker`.
- Infinite canvas and standard paper metadata with exact export dimensions.
- Raster/vector rendering mode stored per notebook.
- Async autosave after two seconds of inactivity and immediate save hooks.
- Shape overlay insertion, resizing, rotation, and basic auto-shape recognition.
- PDF/PNG/JPEG export and PDF/image import through document pickers.

Open `UNote.xcodeproj` in Xcode and run the `UNote` scheme on an iPadOS 17+ simulator or device.
