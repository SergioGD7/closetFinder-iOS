import SwiftData
import SwiftUI

/// Búsqueda por texto libre con filtros en forma de token («Color: Azul», «Chaquetas»).
/// Cada resultado dice dónde está la prenda.
struct SearchView: View {
    @Query private var garments: [Garment]

    @State private var text = ""
    @State private var tokens: [SearchToken] = []
    @State private var suggestedTokens: [SearchToken] = []
    @AppStorage("recentSearches") private var recentStorage = ""

    // Búsqueda inteligente (Apple Intelligence)
    @State private var isInterpreting = false
    @State private var interpretedQuery: String?
    @State private var interpretationFailed = false
    /// Lo último que puso la interpretación, para distinguirlo de lo que escribe el usuario.
    @State private var appliedInterpretation: SmartSearch.Interpretation?

    private var isSearching: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty || !tokens.isEmpty }

    private var results: [Garment] { GarmentSearch.search(garments, text: text, tokens: tokens) }

    private var recentSearches: [String] {
        recentStorage.split(separator: "\n").map(String.init)
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    resultsSection
                } else {
                    browseSections
                }
            }
            .navigationTitle("Buscar")
            .searchable(text: $text, tokens: $tokens, suggestedTokens: $suggestedTokens,
                        prompt: "Prendas, colores, ubicaciones…") { token in
                Label(token.title, systemImage: token.symbol)
            }
            .onChange(of: text) { _, newValue in
                suggestedTokens = GarmentSearch.suggestedTokens(for: newValue, excluding: tokens)
                if newValue != appliedInterpretation?.text {
                    interpretedQuery = nil
                    interpretationFailed = false
                }
            }
            .onChange(of: tokens) { old, new in
                suggestedTokens = []
                guard new != appliedInterpretation?.tokens else { return }
                interpretedQuery = nil
                // Al convertir una palabra en token, se quita del texto.
                if new.count > old.count { text = GarmentSearch.removingLastWord(from: text) }
            }
            .onSubmit(of: .search) { remember(text) }
            #if DEBUG
            .task {
                // `-search "texto"` abre la búsqueda ya escrita (capturas y pruebas manuales).
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-search"), arguments.indices.contains(index + 1) {
                    text = arguments[index + 1]
                }
            }
            #endif
            .appNavigationDestinations()
        }
    }

    // MARK: Resultados

    @ViewBuilder
    private var resultsSection: some View {
        smartSearchSection
        let results = results
        if results.isEmpty {
            ContentUnavailableView.search(text: text)
                .listRowBackground(Color.clear)
        } else {
            Section(results.count == 1 ? String(localized: "1 resultado") : String(localized: "\(results.count) resultados")) {
                ForEach(results) { garment in
                    NavigationLink(value: garment) {
                        GarmentRow(garment: garment)
                    }
                    .simultaneousGesture(TapGesture().onEnded { remember(text) })
                }
            }
        }
    }

    // MARK: Búsqueda inteligente

    @ViewBuilder
    private var smartSearchSection: some View {
        if let interpretedQuery {
            Section {
                Label("Interpretado con Apple Intelligence: «\(interpretedQuery)»", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if tokens.isEmpty, SmartSearch.shouldOffer(for: text) {
            Section {
                Button {
                    interpret(text)
                } label: {
                    HStack {
                        Label("Buscar «\(text.trimmingCharacters(in: .whitespaces))» con Apple Intelligence", systemImage: "sparkles")
                        Spacer()
                        if isInterpreting { ProgressView() }
                    }
                }
                .disabled(isInterpreting)
            } footer: {
                if interpretationFailed {
                    Text("No se ha podido interpretar la búsqueda. Prueba con otras palabras.")
                } else {
                    Text("Entiende frases como «algo de abrigo para la nieve». Funciona en el iPhone, sin conexión.")
                }
            }
        }
    }

    private func interpret(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        isInterpreting = true
        interpretationFailed = false
        Task {
            defer { isInterpreting = false }
            do {
                let interpretation = try await SmartSearch.interpret(trimmed)
                remember(trimmed)
                appliedInterpretation = interpretation
                text = interpretation.text
                tokens = interpretation.tokens
                interpretedQuery = trimmed
            } catch {
                interpretationFailed = true
            }
        }
    }

    // MARK: Explorar

    @ViewBuilder
    private var browseSections: some View {
        if !recentSearches.isEmpty {
            Section {
                ForEach(recentSearches, id: \.self) { recent in
                    Button {
                        text = recent
                    } label: {
                        Label(recent, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                HStack {
                    Text("Recientes")
                    Spacer()
                    Button("Borrar") { recentStorage = "" }
                        .font(.footnote)
                        .textCase(nil)
                }
            }
        }

        Section("Por color") {
            quickTokens(GarmentColor.allCases.filter(presentColors.contains).map(SearchToken.color))
        }
        Section("Por estado") {
            quickTokens(GarmentStatus.allCases.filter { $0 != .stored }.map(SearchToken.status))
        }
        Section("Por temporada") {
            quickTokens(Season.allCases.filter { $0 != .allYear }.map(SearchToken.season))
        }
    }

    private var presentColors: Set<GarmentColor> { Set(garments.flatMap(\.colors)) }

    private func quickTokens(_ items: [SearchToken]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { token in
                    Button {
                        tokens = [token]
                    } label: {
                        HStack(spacing: 5) {
                            if case .color(let color) = token {
                                Circle().fill(color.fill).frame(width: 12, height: 12)
                                Text(color.title)
                            } else {
                                Image(systemName: token.symbol)
                                Text(token.title)
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func remember(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let updated = [trimmed] + recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recentStorage = updated.prefix(6).joined(separator: "\n")
    }
}

#Preview {
    SearchView()
        .modelContainer(AppModelContainer.preview())
}
