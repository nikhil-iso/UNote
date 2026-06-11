import Foundation
import PencilKit
import SwiftUI

struct CanvasConfiguration {
    var drawingPolicy: PKCanvasViewDrawingPolicy = .anyInput
    var contentSize: CGSize
}

struct PencilCanvasView: UIViewRepresentable {
    let drawing: PKDrawing
    let configuration: CanvasConfiguration
    let onDrawingChanged: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.drawingPolicy = configuration.drawingPolicy
        canvasView.isScrollEnabled = false
        canvasView.contentSize = configuration.contentSize
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false

        context.coordinator.lastAppliedDrawingData = drawing.dataRepresentation()

        DispatchQueue.main.async {
            context.coordinator.attachToolPicker(to: canvasView)
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasView.drawingPolicy = configuration.drawingPolicy
        canvasView.contentSize = configuration.contentSize

        let incomingData = drawing.dataRepresentation()
        if incomingData != context.coordinator.lastAppliedDrawingData {
            context.coordinator.isApplyingProgrammaticDrawing = true
            canvasView.drawing = drawing
            context.coordinator.lastAppliedDrawingData = incomingData
            context.coordinator.isApplyingProgrammaticDrawing = false
        }

        DispatchQueue.main.async {
            context.coordinator.attachToolPicker(to: canvasView)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        var toolPicker: PKToolPicker?
        var lastAppliedDrawingData = Data()
        var isApplyingProgrammaticDrawing = false

        init(parent: PencilCanvasView) {
            self.parent = parent
        }

        func attachToolPicker(to canvasView: PKCanvasView) {
            if toolPicker == nil {
                toolPicker = PKToolPicker()
            }
            toolPicker?.addObserver(canvasView)
            toolPicker?.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingProgrammaticDrawing else { return }
            let data = canvasView.drawing.dataRepresentation()
            lastAppliedDrawingData = data
            parent.onDrawingChanged(canvasView.drawing)
        }
    }
}
