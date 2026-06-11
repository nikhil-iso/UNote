import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("UNote.defaultRenderingMode") private var defaultRenderingModeRaw = RenderingMode.vector.rawValue

    private var binding: Binding<RenderingMode> {
        Binding {
            RenderingMode(rawValue: defaultRenderingModeRaw) ?? .vector
        } set: { newValue in
            defaultRenderingModeRaw = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Default rendering for new notebooks") {
                    Picker("Rendering", selection: binding) {
                        ForEach(RenderingMode.allCases) { mode in
                            Text(mode.preferenceDescription).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Preferences")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
