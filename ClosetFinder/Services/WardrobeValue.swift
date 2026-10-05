import Foundation

/// Lo que vale el armario: precio de las prendas, gasto por año y coste por puesta.
nonisolated enum WardrobeValue {

    static var currencyCode: String { Locale.current.currency?.identifier ?? "EUR" }

    /// «€», «$», «£»
    static var currencySymbol: String { Locale.current.currencySymbol ?? currencyCode }

    /// «2.340 €», «49,95 €»
    static func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(amount.rounded() == amount ? 0 : 2)))
    }

    static func priced(_ garments: [Garment]) -> [Garment] {
        garments.filter { $0.price != nil }
    }

    static func total(_ garments: [Garment]) -> Double {
        garments.compactMap(\.price).reduce(0, +)
    }

    /// Lo que costaron las prendas con precio dividido entre todas las veces que te las has puesto.
    static func averageCostPerWear(_ garments: [Garment]) -> Double? {
        let priced = priced(garments)
        let wears = priced.map(\.wearCount).reduce(0, +)
        guard !priced.isEmpty, wears > 0 else { return nil }
        return total(priced) / Double(wears)
    }

    struct YearSpending: Identifiable, Equatable {
        let year: Int
        let amount: Double
        var id: Int { year }
    }

    /// Gasto de cada año, según la fecha de compra (o la de alta, si no se indicó).
    static func spendingByYear(_ garments: [Garment], calendar: Calendar = .current) -> [YearSpending] {
        var byYear: [Int: Double] = [:]
        for garment in garments {
            guard let price = garment.price else { continue }
            let year = calendar.component(.year, from: garment.purchasedAt ?? garment.createdAt)
            byYear[year, default: 0] += price
        }
        return byYear.keys.sorted().map { YearSpending(year: $0, amount: byYear[$0] ?? 0) }
    }

    /// Qué tal se ha amortizado una prenda, según las veces que te la has puesto.
    enum Payoff: Equatable {
        case good, fair, poor

        static func of(_ garment: Garment) -> Payoff {
            switch garment.wearCount {
            case 30...: .good
            case 5..<30: .fair
            default: .poor
            }
        }
    }

    /// De la que menos cuesta cada puesta a la que más.
    static func byCostPerWear(_ garments: [Garment]) -> [Garment] {
        priced(garments).sorted { ($0.costPerWear ?? 0) < ($1.costPerWear ?? 0) }
    }
}

/// Resumen de un año: lo que más te has puesto, colores y lo que se ha quedado en el armario.
nonisolated struct YearInReview {
    let year: Int
    /// Veces que te has puesto un look.
    let looksWorn: Int
    let mostWornOutfit: (outfit: Outfit, count: Int)?
    let starGarment: (garment: Garment, count: Int)?
    /// Prendas puestas al menos una vez.
    let garmentsWorn: Int
    let garmentCount: Int
    /// Colores ordenados por las veces que te has puesto prendas de ese color.
    let topColors: [GarmentColor]
    let newGarments: Int
    let spent: Double

    var notWorn: Int { garmentCount - garmentsWorn }
    var hasActivity: Bool { looksWorn > 0 || garmentsWorn > 0 || newGarments > 0 }

    init(year: Int, garments: [Garment], outfits: [Outfit], calendar: Calendar = .current) {
        self.year = year
        func inYear(_ date: Date) -> Bool { calendar.component(.year, from: date) == year }
        guard let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            looksWorn = 0; mostWornOutfit = nil; starGarment = nil; garmentsWorn = 0; garmentCount = 0
            topColors = []; newGarments = 0; spent = 0
            return
        }

        let outfitWears = outfits.map { ($0, $0.wearDates.filter(inYear).count) }.filter { $0.1 > 0 }
        looksWorn = outfitWears.map(\.1).reduce(0, +)
        mostWornOutfit = outfitWears.max { $0.1 < $1.1 }.map { (outfit: $0.0, count: $0.1) }

        // Las prendas que ya existían ese año.
        let existing = garments.filter { $0.createdAt < endOfYear }
        let garmentWears = existing.map { ($0, $0.wearDates.filter(inYear).count) }
        let worn = garmentWears.filter { $0.1 > 0 }
        garmentCount = existing.count
        garmentsWorn = worn.count
        starGarment = worn.max { $0.1 < $1.1 }.map { (garment: $0.0, count: $0.1) }

        var colorCounts: [GarmentColor: Int] = [:]
        for (garment, count) in worn { colorCounts[garment.primaryColor, default: 0] += count }
        topColors = colorCounts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
            .prefix(3).map(\.key)

        newGarments = garments.filter { inYear($0.createdAt) }.count
        spent = garments.filter { $0.price != nil && inYear($0.purchasedAt ?? $0.createdAt) }.compactMap(\.price).reduce(0, +)
    }

    /// Años con algo que contar, del más reciente al más antiguo.
    static func years(garments: [Garment], outfits: [Outfit], now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let dates = garments.flatMap { $0.wearDates + [$0.createdAt] } + outfits.flatMap(\.wearDates)
        var years = Set(dates.map { calendar.component(.year, from: $0) })
        years.insert(calendar.component(.year, from: now))
        return years.sorted(by: >)
    }
}

/// Qué prenda completaría más looks: looks sin calzado, sin parte de abajo o sin parte de arriba.
nonisolated enum WardrobeGaps {

    struct Gap: Identifiable {
        let slot: OutfitSlot
        let outfits: [Outfit]
        var id: OutfitSlot { slot }
    }

    /// Partes del cuerpo que le faltan a un look para estar completo.
    static func missingSlots(in outfit: Outfit) -> [OutfitSlot] {
        let slots = Set(outfit.pieces.map { OutfitSlot.slot(for: $0.category) })
        guard !slots.isEmpty else { return [] }
        var missing: [OutfitSlot] = []
        let hasBody = slots.contains(.fullBody)
        if !hasBody, !slots.contains(.top), !slots.contains(.outer) { missing.append(.top) }
        if !hasBody, !slots.contains(.bottom) { missing.append(.bottom) }
        if !slots.contains(.feet) { missing.append(.feet) }
        return missing
    }

    /// Huecos ordenados por el número de looks que completarían.
    static func gaps(in outfits: [Outfit]) -> [Gap] {
        var bySlot: [OutfitSlot: [Outfit]] = [:]
        for outfit in outfits {
            for slot in missingSlots(in: outfit) { bySlot[slot, default: []].append(outfit) }
        }
        return bySlot
            .map { Gap(slot: $0.key, outfits: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.outfits.count != $1.outfits.count ? $0.outfits.count > $1.outfits.count
                : OutfitSlot.allCases.firstIndex(of: $0.slot)! < OutfitSlot.allCases.firstIndex(of: $1.slot)! }
    }
}
