import SwiftData
import SwiftUI

/// Primer arranque tras instalar o reinstalar la app. Antes de enseñar la bienvenida mira si el
/// usuario ya tiene un armario en iCloud: si lo tiene, espera a que llegue y entra directamente.
struct FirstLaunchView: View {
    let onFinish: () -> Void

    enum Phase: Equatable {
        case checking, restoring, onboarding
    }

    @Environment(\.modelContext) private var modelContext
    @State private var phase: Phase = .checking
    @State private var restoredGarments = 0
    @State private var canSkip = false

    var body: some View {
        Group {
            if phase == .onboarding {
                OnboardingView(onFinish: onFinish)
            } else {
                waitingView
            }
        }
        .task { await run() }
    }

    // MARK: Esperando a iCloud

    private var waitingView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: phase == .checking ? "icloud" : "icloud.and.arrow.down")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(phase == .checking ? String(localized: "Buscando tu armario en iCloud…")
                                        : String(localized: "Recuperando tu armario…"))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(phase == .checking
                     ? String(localized: "Si ya usabas Closet Finder con este Apple ID, tus prendas vuelven solas.")
                     : String(localized: "Estamos trayendo de iCloud tus prendas, fotos y ubicaciones. Puede tardar un poco si tienes muchas fotos."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            ProgressView()
                .padding(.top, 4)
            if restoredGarments > 0 {
                Text(restoredGarments == 1 ? String(localized: "1 prenda recuperada")
                                           : String(localized: "\(restoredGarments) prendas recuperadas"))
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            if canSkip {
                Button {
                    withAnimation { phase = .onboarding }
                } label: {
                    Text("Empezar sin esperar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.snappy, value: restoredGarments)
        .animation(.snappy, value: canSkip)
    }

    // MARK: Lógica

    private var localCounts: (garments: Int, locations: Int) {
        ((try? modelContext.fetchCount(FetchDescriptor<Garment>())) ?? 0,
         (try? modelContext.fetchCount(FetchDescriptor<StorageLocation>())) ?? 0)
    }

    private func run() async {
        #if DEBUG
        // `-restoreDemo`: enseña la pantalla de recuperación sin iCloud (simulador, capturas).
        if ProcessInfo.processInfo.arguments.contains("-restoreDemo") {
            phase = .restoring
            restoredGarments = 12
            canSkip = true
            return
        }
        #endif
        let counts = localCounts
        // Sin iCloud no hay nada que consultar: directamente a la bienvenida.
        guard counts.garments + counts.locations == 0, AppModelContainer.syncsWithICloud else {
            if counts.garments + counts.locations > 0 { onFinish() } else { phase = .onboarding }
            return
        }
        async let account = ICloudLookup.accountAvailable()
        async let cloud = ICloudLookup.cloudData()
        let decision = FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: true,
                                                  accountAvailable: await account, cloudData: await cloud)
        switch decision {
        case .skip: onFinish()
        case .onboarding: withAnimation { phase = .onboarding }
        case .restore(let patience): await waitForRestore(patience: patience)
        }
    }

    /// Espera a que termine la importación de iCloud. Entra en la app cuando ha llegado algo y la
    /// importación ha acabado; si acaba sin traer nada, o se agota la paciencia, pasa a la bienvenida
    /// (que se cierra sola si los datos llegan después).
    private func waitForRestore(patience: Duration) async {
        withAnimation { phase = .restoring }
        let monitor = CloudSyncMonitor.shared
        let clock = ContinuousClock()
        let start = clock.now
        while !Task.isCancelled {
            let counts = localCounts
            restoredGarments = counts.garments
            let hasData = counts.garments + counts.locations > 0
            let importDone = monitor.finishedImports > 0 && !monitor.isImporting
            let elapsed = start.duration(to: clock.now)
            if hasData && importDone { return onFinish() }
            if importDone && !hasData && elapsed > .seconds(5) { break }
            if elapsed > patience { break }
            if elapsed > .seconds(10) { canSkip = true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard !Task.isCancelled else { return }
        if localCounts.garments + localCounts.locations > 0 {
            onFinish()
        } else {
            withAnimation { phase = .onboarding }
        }
    }
}

#Preview {
    FirstLaunchView {}
        .modelContainer(AppModelContainer.make(inMemory: true))
}
