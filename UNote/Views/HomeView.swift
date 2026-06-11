import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: NotebookStore
    @State private var showingNewNotebook = false
    @State private var showingPreferences = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.notebooks) { summary in
                    NavigationLink(value: summary.metadata) {
                        NotebookRow(summary: summary)
                    }
                }
            }
            .overlay {
                if store.notebooks.isEmpty {
                    ContentUnavailableView("No Notebooks", systemImage: "folder", description: Text("Create a local notebook to start writing."))
                }
            }
            .navigationTitle("UNote")
            .navigationDestination(for: NotebookMetadata.self) { metadata in
                NotebookEditorView(metadata: metadata, store: store)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingPreferences = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Preferences")

                    Button {
                        showingNewNotebook = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("New notebook")
                }
            }
            .refreshable {
                await store.refreshNotebooks()
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesView()
            }
        }
    }
}

private struct NotebookRow: View {
    let summary: NotebookSummary

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.metadata.name)
                    .font(.headline)
                Text("\(summary.metadata.pageMode.displayName) - \(summary.metadata.renderingMode.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if summary.metadata.pageMode == .standardPages {
                    Text("\(summary.metadata.pageCount) page\(summary.metadata.pageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailURL = summary.thumbnailURL,
           let image = UIImage(contentsOfFile: thumbnailURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NewNotebookSheet: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("UNote.defaultRenderingMode") private var defaultRenderingModeRaw = RenderingMode.vector.rawValue

    @State private var name = ""
    @State private var pageMode = PageMode.infiniteCanvas
    @State private var paperSize = StandardPaperSize.letter
    @State private var errorMessage: String?

    private var selectedRenderingMode: RenderingMode {
        RenderingMode(rawValue: defaultRenderingModeRaw) ?? .vector
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Notebook name", text: $name)
                    Picker("Mode", selection: $pageMode) {
                        ForEach(PageMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    if pageMode == .standardPages {
                        Picker("Paper", selection: $paperSize) {
                            ForEach(StandardPaperSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                    }
                    LabeledContent("Rendering") {
                        Text(selectedRenderingMode.preferenceDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            do {
                                _ = try await store.createNotebook(
                                    name: name,
                                    pageMode: pageMode,
                                    standardSize: paperSize,
                                    renderingMode: selectedRenderingMode
                                )
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .alert("Could not create notebook", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
