import Charts
import SwiftData
import SwiftUI

/// Estadísticas del armario: qué hay, dónde está y qué no se usa.
struct StatsView: View {
    @Query private var garments: [Garment]
    @Query private var outfits: [Outfit]
    @Query(sort: [SortDescriptor(\StorageLocation.sortIndex)]) private var locations: [StorageLocation]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(value: garments.count, title: String(localized: "Prendas"), systemImage: "hanger", tint: .accentColor)
                    StatTile(value: forgotten.count, title: String(localized: "Sin usar en 6 meses"), systemImage: "moon.zzz", tint: .indigo)
                    StatTile(value: count(.lent), title: String(localized: "Prestadas"), systemImage: GarmentStatus.lent.symbol, tint: .orange)
                    StatTile(value: count(.toDonate), title: String(localized: "Para donar"), systemImage: GarmentStatus.toDonate.symbol, tint: .pink)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                NavigationLink {
                    WardrobeValueView()
                } label: {
                    LabeledContent {
                        let priced = WardrobeValue.priced(garments)
                        if !priced.isEmpty { Text(WardrobeValue.format(WardrobeValue.total(priced))) }
                    } label: {
                        Label("Valor del armario", systemImage: "banknote")
                    }
                }
                NavigationLink {
                    YearInReviewView()
                } label: {
                    Label(String(localized: "Tu \(String(Calendar.current.component(.year, from: .now))) en ropa"), systemImage: "sparkles")
                }
            }

            gapsSection

            if !byCategory.isEmpty {
                Section("Por categoría") {
                    Chart(byCategory, id: \.label) { item in
                        BarMark(x: .value("Prendas", item.count), y: .value("Categoría", item.label))
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text("\(item.count)").font(.caption).foregroundStyle(.secondary)
                            }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel().font(.footnote)
                        }
                    }
                    .frame(height: CGFloat(byCategory.count) * 28 + 10)
                    .padding(.vertical, 6)
                }
            }

            if !byRoom.isEmpty {
                Section("Por estancia") {
                    Chart(byRoom, id: \.label) { item in
                        BarMark(x: .value("Prendas", item.count), y: .value("Estancia", item.label))
                            .foregroundStyle(LocationKind.room.tint.gradient)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text("\(item.count)").font(.caption).foregroundStyle(.secondary)
                            }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel().font(.footnote)
                        }
                    }
                    .frame(height: CGFloat(byRoom.count) * 34 + 10)
                    .padding(.vertical, 6)
                }
            }

            Section {
                if forgotten.isEmpty {
                    Text("Has usado toda tu ropa en los últimos seis meses.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(forgotten.prefix(8)) { garment in
                        NavigationLink(value: garment) {
                            GarmentRow(garment: garment, locationText: WardrobeInsights.wornDescription(garment) + " · " + (garment.location?.shortPath ?? String(localized: "Sin ubicación")))
                        }
                    }
                }
            } header: {
                Text("Olvidadas")
            } footer: {
                Text("Prendas guardadas que no te pones desde hace más de seis meses. Buenas candidatas para darles uso o donarlas.")
            }

            let mostWorn = WardrobeInsights.mostWorn(garments)
            if !mostWorn.isEmpty {
                Section("Las que más usas") {
                    ForEach(mostWorn) { garment in
                        NavigationLink(value: garment) {
                            HStack {
                                GarmentRow(garment: garment)
                                Text("\(garment.wearCount)×")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var forgotten: [Garment] { WardrobeInsights.forgotten(garments) }

    @ViewBuilder
    private var gapsSection: some View {
        let gaps = WardrobeGaps.gaps(in: outfits)
        if !gaps.isEmpty {
            Section {
                ForEach(gaps) { gap in
                    HStack(spacing: 12) {
                        GarmentArtwork(category: gap.slot.representativeCategory, color: .gray)
                            .padding(6)
                            .frame(width: 44, height: 44)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gap.slot.title).font(.subheadline.weight(.semibold))
                            Text(gap.outfits.count == 1
                                 ? String(localized: "Completaría 1 look: \(gap.outfits[0].displayName)")
                                 : String(localized: "Completaría \(gap.outfits.count) looks: \(gap.outfits.map(\.displayName).formatted(.list(type: .and)))"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Huecos en el armario")
            } footer: {
                Text("Looks a los que les falta una parte. Si vas a comprar algo, esto es lo que más looks completaría.")
            }
        }
    }

    private func count(_ status: GarmentStatus) -> Int { garments.filter { $0.status == status }.count }

    private struct Bucket { let label: String; let count: Int }

    private var byCategory: [Bucket] {
        GarmentCategory.allCases.compactMap { category in
            let count = garments.filter { $0.category == category }.count
            return count > 0 ? Bucket(label: category.title, count: count) : nil
        }
        .sorted { $0.count > $1.count }
    }

    private var byRoom: [Bucket] {
        var buckets = locations.filter { $0.parent == nil }.map { Bucket(label: $0.name, count: $0.totalGarmentCount) }
        let unassigned = garments.filter { $0.location == nil }.count
        if unassigned > 0 { buckets.append(Bucket(label: String(localized: "Sin ubicación"), count: unassigned)) }
        return buckets.filter { $0.count > 0 }
    }
}

private struct StatTile: View {
    let value: Int
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title.bold())
                .monospacedDigit()
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .appNavigationDestinations()
    }
    .modelContainer(AppModelContainer.preview())
}
