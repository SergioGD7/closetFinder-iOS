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
            }
            .onChange(of: tokens) { old, new in
                // Al convertir una palabra en token, se quita del texto.
                if new.count > old.count { text = GarmentSearch.removingLastWord(from: text) }
                suggestedTokens = []
            }
            .onSubmit(of: .search) { remember(text) }
            .appNavigationDestinations()
        }
    }

    // MARK: Resultados

    @ViewBuilder
    private var resultsSection: some View {
        let results = results
        if results.isEmpty {
            ContentUnavailableView.search(text: text)
                .listRowBackground(Color.clear)
        } else {
            Section(results.count == 1 ? "1 resultado" : "\(results.count) resultados") {
                ForEach(results) { garment in
                    NavigationLink(value: garment) {
                        GarmentRow(garment: garment)
                    }
                    .simultaneousGesture(TapGesture().onEnded { remember(text) })
                }
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
