import SwiftUI

/// Una lectura de etiqueta, para presentarla en una hoja.
struct LabelReading: Identifiable {
    let id = UUID()
    let info: LabelInfo
}

/// Lo que se ha leído en la etiqueta, para revisarlo antes de pasarlo a la prenda.
struct LabelResultSheet: View {
    let info: LabelInfo
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if info.isEmpty {
                    ContentUnavailableView {
                        Label("No hemos podido leer la etiqueta", systemImage: "text.viewfinder")
                    } description: {
                        Text("Prueba con más luz, la etiqueta estirada y la cámara más cerca.")
                    }
                } else {
                    List {
                        if let size = info.size {
                            Section("Talla") {
                                LabeledContent(size) {
                                    if let equivalents = info.sizeEquivalents { Text(equivalents) }
                                }
                                .font(.headline)
                            }
                        }
                        if !info.fibers.isEmpty {
                            Section("Composición") {
                                Text(info.compositionText)
                            }
                        }
                        if !info.care.isEmpty {
                            Section("Cuidados") {
                                ForEach(info.care) { instruction in
                                    Label(instruction.title, systemImage: instruction.symbol)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hemos leído")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !info.isEmpty {
                    Button {
                        onApply()
                        dismiss()
                    } label: {
                        Text("Usar estos datos").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .presentationDetents([.medium, .large])
        // A media altura, iOS 26 hace la hoja translúcida y el botón se pierde sobre el formulario.
        .presentationBackground(Color(.systemGroupedBackground))
    }
}
