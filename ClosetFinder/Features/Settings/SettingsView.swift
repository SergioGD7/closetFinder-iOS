import CloudKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Ajustes: estado de iCloud, copia de seguridad y datos de ejemplo.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var garments: [Garment]
    @Query private var locations: [StorageLocation]

    @State private var iCloudStatus: CKAccountStatus?
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var message: Message?

    struct Message: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    var body: some View {
        NavigationStack {
            Form {
                iCloudSection
                backupSection
                if garments.isEmpty && locations.isEmpty {
                    Section {
                        Button("Cargar un armario de ejemplo") {
                            SampleData.insertIfEmpty(into: modelContext)
                            SpotlightIndexer.reindexAll(in: modelContext)
                        }
                    }
                }
                Section {
                    LabeledContent("Versión", value: appVersion)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", systemImage: "checkmark") { dismiss() }
                }
            }
            .task { await loadICloudStatus() }
            .fileExporter(isPresented: $isExporting, document: exportDocument,
                          contentType: .closetFinderBackup, defaultFilename: BackupService.suggestedFilename()) { result in
                if case .failure(let error) = result {
                    message = Message(title: "No se pudo guardar la copia", text: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.closetFinderBackup]) { result in
                switch result {
                case .success(let url): restore(from: url)
                case .failure(let error):
                    message = Message(title: "No se pudo abrir el archivo", text: error.localizedDescription)
                }
            }
            .alert(item: $message) { message in
                Alert(title: Text(message.title), message: Text(message.text))
            }
        }
    }

    // MARK: iCloud

    private var iCloudSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: iCloudSymbol)
                    .font(.title2)
                    .foregroundStyle(iCloudIsWorking ? Color.accentColor : .secondary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(iCloudTitle).font(.body.weight(.semibold))
                    Text(iCloudDetail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("iCloud")
        } footer: {
            Text("Tus prendas, fotos y ubicaciones se guardan en tu iCloud privado. Si borras la app y la vuelves a instalar con el mismo Apple ID, todo vuelve solo. También se sincroniza entre tu iPhone y tu iPad.")
        }
    }

    private var iCloudIsWorking: Bool { AppModelContainer.syncsWithICloud && iCloudStatus == .available }

    private var iCloudSymbol: String { iCloudIsWorking ? "checkmark.icloud" : "exclamationmark.icloud" }

    private var iCloudTitle: String {
        guard AppModelContainer.syncsWithICloud else { return "Sincronización no disponible" }
        switch iCloudStatus {
        case .available: return "Sincronizado con iCloud"
        case .noAccount: return "Sin cuenta de iCloud"
        case .restricted: return "iCloud restringido"
        case .temporarilyUnavailable: return "iCloud no disponible ahora"
        default: return "Comprobando iCloud…"
        }
    }

    private var iCloudDetail: String {
        guard AppModelContainer.syncsWithICloud else {
            return "Esta compilación no tiene acceso a iCloud. Los datos solo se guardan en este dispositivo."
        }
        switch iCloudStatus {
        case .available: return "Los cambios se copian a tu iCloud automáticamente."
        case .noAccount: return "Inicia sesión en Ajustes › tu nombre para guardar una copia en iCloud."
        case .restricted: return "Un perfil o las restricciones del dispositivo impiden usar iCloud."
        case .temporarilyUnavailable: return "Se sincronizará en cuanto iCloud vuelva a estar disponible."
        default: return ""
        }
    }

    private func loadICloudStatus() async {
        guard AppModelContainer.syncsWithICloud else { return }
        iCloudStatus = try? await CKContainer(identifier: AppModelContainer.cloudKitContainer).accountStatus()
    }

    // MARK: Copia de seguridad

    private var backupSection: some View {
        Section {
            Button {
                export()
            } label: {
                Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up")
            }
            .disabled(garments.isEmpty && locations.isEmpty)

            Button {
                isImporting = true
            } label: {
                Label("Restaurar desde un archivo", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Copia de seguridad")
        } footer: {
            Text("Guarda un archivo con todo tu armario, fotos incluidas, en Archivos, en el ordenador o donde quieras. Al restaurar se añade lo que falta; lo que ya tienes no se duplica.")
        }
    }

    private func export() {
        do {
            let archive = try BackupService.makeArchive(from: modelContext)
            exportDocument = BackupDocument(data: try archive.encoded())
            isExporting = true
        } catch {
            message = Message(title: "No se pudo crear la copia", text: error.localizedDescription)
        }
    }

    private func restore(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let archive = try BackupArchive.decode(Data(contentsOf: url))
            let summary = try BackupService.restore(archive, into: modelContext)
            SpotlightIndexer.reindexAll(in: modelContext)
            message = Message(
                title: "Copia restaurada",
                text: "Se han añadido \(summary.garments) prendas, \(summary.locations) ubicaciones y \(summary.profiles) personas. \(summary.skipped) elementos ya estaban y no se han duplicado.")
        } catch {
            message = Message(title: "No se pudo restaurar", text: (error as? LocalizedError)?.errorDescription
                              ?? "El archivo no es una copia de Closet Finder o está dañado.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(AppModelContainer.preview())
}
