import SwiftUI
import UIKit

struct PageThumbnailStrip: View {
    @ObservedObject var viewModel: NotebookEditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<viewModel.metadata.pageCount, id: \.self) { index in
                    Button {
                        Task {
                            await viewModel.switchPage(to: index)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            thumbnail(for: index)
                                .frame(width: 72, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(index == viewModel.currentPageIndex ? Color.accentColor : Color.clear, lineWidth: 3)
                                }
                            Text("\(index + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task {
                        await viewModel.addPage()
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .help("Add page")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    @ViewBuilder
    private func thumbnail(for index: Int) -> some View {
        let url = viewModel.thumbnailURL(for: index)
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.white
                Rectangle()
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            }
        }
    }
}
