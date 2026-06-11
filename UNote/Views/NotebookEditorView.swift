import SwiftUI
import UIKit

struct NotebookEditorView: View {
    @StateObject private var viewModel: NotebookEditorViewModel
    @State private var showingImportPicker = false

    init(metadata: NotebookMetadata, store: NotebookStore) {
        _viewModel = StateObject(wrappedValue: NotebookEditorViewModel(metadata: metadata, store: store))
    }

    var body: some View {
        Group {
            if viewModel.isLoaded {
                editor
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.metadata.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onDisappear {
            Task {
                await viewModel.saveImmediately()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .unoteShouldAutosaveNow)) { _ in
            Task {
                await viewModel.saveImmediately()
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            ImportDocumentPicker { url in
                Task {
                    await viewModel.importBackground(from: url)
                }
            }
        }
        .sheet(item: $viewModel.exportedDocument) { document in
            ExportDocumentPicker(url: document.url)
        }
        .alert("UNote", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleAutoShapeRecognition()
                } label: {
                    Image(systemName: viewModel.metadata.autoShapeRecognitionEnabled ? "wand.and.stars" : "wand.and.stars.inverse")
                }
                .help("Auto-shape recognition")

                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import")

                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.displayName) {
                            Task {
                                await viewModel.export(format: format)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export")
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            CanvasSurfaceView(viewModel: viewModel)

            if viewModel.metadata.pageMode == .standardPages {
                PageThumbnailStrip(viewModel: viewModel)
            }
        }
    }
}

private struct CanvasSurfaceView: View {
    @ObservedObject var viewModel: NotebookEditorViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = viewModel.canvasSize(in: proxy.size)

            Group {
                if viewModel.metadata.pageMode == .standardPages {
                    ScrollView([.horizontal, .vertical]) {
                        surface(size: size)
                            .padding(28)
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            surface(size: size)
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    viewModel.extendInfiniteCanvasIfNeeded()
                                }
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .onAppear {
                viewModel.updateCanvasSize(size)
            }
            .onChange(of: size.width) { _, _ in
                viewModel.updateCanvasSize(size)
            }
            .onChange(of: size.height) { _, _ in
                viewModel.updateCanvasSize(size)
            }
        }
    }

    private func surface(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Color.white

            if let backgroundImage = viewModel.backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            }

            PencilCanvasView(
                drawing: viewModel.drawing,
                configuration: CanvasConfiguration(contentSize: size),
                onDrawingChanged: viewModel.drawingDidChange
            )
            .frame(width: size.width, height: size.height)

            ForEach($viewModel.shapes) { $shape in
                ShapeOverlayView(
                    shape: $shape,
                    canvasSize: size,
                    onFinishedEditing: viewModel.shapesDidChange
                )
            }

            VStack {
                HStack {
                    Spacer()
                    ShapePaletteView(insertShape: viewModel.insertShape)
                        .padding(12)
                }
                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Rectangle())
        .dropDestination(for: String.self) { items, location in
            guard let rawValue = items.first,
                  let kind = ShapeKind(rawValue: rawValue)
            else {
                return false
            }
            viewModel.insertShape(kind, at: location)
            return true
        }
    }
}
