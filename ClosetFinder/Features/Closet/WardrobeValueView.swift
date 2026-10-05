import Charts
import SwiftData
import SwiftUI

/// Lo que vale el armario: total, gasto por año y coste por puesta de cada prenda.
struct WardrobeValueView: View {
    @Query private var garments: [Garment]

    var body: some View {
        let priced = WardrobeValue.priced(garments)
        List {
            if priced.isEmpty {
                ContentUnavailableView {
                    Label("Añade lo que te costó tu ropa", systemImage: "banknote")
                } description: {
                    Text("Al editar una prenda, escribe el precio y cuándo la compraste. Aquí verás lo que vale tu armario y cuánto te cuesta cada puesta.")
                }
                .listRowBackground(Color.clear)
            } else {
                summary(priced)
                spendingChart(priced)
                let ranked = WardrobeValue.byCostPerWear(priced)
                Section {
                    ForEach(ranked.prefix(5)) { garment in
                        NavigationLink(value: garment) { CostPerWearRow(garment: garment) }
                    }
                } header: {
                    Text("Las más amortizadas")
                } footer: {
                    Text("Coste por puesta: el precio dividido entre las veces que te la has puesto con tus looks.")
                }
                if ranked.count > 5 {
                    Section("Las menos amortizadas") {
                        ForEach(ranked.suffix(min(5, ranked.count - 5)).reversed()) { garment in
                            NavigationLink(value: garment) { CostPerWearRow(garment: garment) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Valor del armario")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ priced: [Garment]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(WardrobeValue.format(WardrobeValue.total(priced)))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Group {
                    Text(priced.count == 1 ? String(localized: "1 prenda con precio") : String(localized: "\(priced.count) prendas con precio"))
                    if let average = WardrobeValue.averageCostPerWear(priced) {
                        Text("\(WardrobeValue.format(average)) por puesta de media")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func spendingChart(_ priced: [Garment]) -> some View {
        let years = WardrobeValue.spendingByYear(priced)
        if !years.isEmpty {
            Section("Gasto por año") {
                Chart(years) { item in
                    BarMark(x: .value("Año", String(item.year)), y: .value("Gasto", item.amount))
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(5)
                        .annotation(position: .top) {
                            Text(WardrobeValue.format(item.amount))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxis(.hidden)
                .frame(height: 170)
                .padding(.vertical, 8)
            }
        }
    }
}

/// Prenda con su precio, sus puestas y lo que cuesta cada una.
struct CostPerWearRow: View {
    let garment: Garment

    var body: some View {
        HStack(spacing: 12) {
            GarmentImage(garment: garment, inset: 0.1)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(garment.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let cost = garment.costPerWear {
                Text(WardrobeValue.format(cost))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.14), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let price = garment.price.map(WardrobeValue.format) ?? ""
        let wears = switch garment.wearCount {
        case 0: String(localized: "sin estrenar")
        case 1: String(localized: "1 puesta")
        default: String(localized: "\(garment.wearCount) puestas")
        }
        return "\(price) · \(wears)"
    }

    private var tint: Color {
        switch WardrobeValue.Payoff.of(garment) {
        case .good: .green
        case .fair: .orange
        case .poor: .red
        }
    }
}

#Preview {
    NavigationStack {
        WardrobeValueView()
            .appNavigationDestinations()
    }
    .modelContainer(AppModelContainer.preview())
}
