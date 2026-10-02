import SwiftData
import SwiftUI

enum LooksSection: String, CaseIterable, Identifiable {
    case outfits, week, trips

    var id: Self { self }

    var title: String {
        switch self {
        case .outfits: String(localized: "Looks")
        case .week: String(localized: "Semana")
        case .trips: String(localized: "Maletas")
        }
    }
}

/// Pestaña Looks: looks guardados, planificación semanal y maletas de viaje.
struct LooksView: View {
    @Environment(AppRouter.self) private var router
    @State private var isCreatingOutfit = false
    @State private var isCreatingTrip = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.looksPath) {
            Group {
                switch router.looksSection {
                case .outfits: OutfitsGridView(isCreating: $isCreatingOutfit)
                case .week: WeekPlanView()
                case .trips: TripsListView(isCreating: $isCreatingTrip)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(router.looksSection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Sección", selection: $router.looksSection) {
                        ForEach(LooksSection.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    switch router.looksSection {
                    case .outfits:
                        Button { isCreatingOutfit = true } label: { Label("Nuevo look", systemImage: "plus") }
                    case .trips:
                        Button { isCreatingTrip = true } label: { Label("Nueva maleta", systemImage: "plus") }
                    case .week:
                        EmptyView()
                    }
                }
            }
            .appNavigationDestinations()
            .sheet(isPresented: $isCreatingOutfit) {
                OutfitEditorView { router.looksPath.append($0) }
            }
            .sheet(isPresented: $isCreatingTrip) {
                TripEditorView { router.looksPath.append($0) }
            }
        }
    }
}

/// Rejilla de looks guardados.
struct OutfitsGridView: View {
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @Query private var garments: [Garment]
    @Binding var isCreating: Bool
    @State private var favoritesOnly = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        if outfits.isEmpty {
            ContentUnavailableView {
                Label("Aún no tienes looks", systemImage: "tshirt")
            } description: {
                Text(garments.isEmpty
                     ? String(localized: "Añade primero tus prendas en el Armario. Después podrás combinarlas en looks.")
                     : String(localized: "Elige una prenda para cada parte del cuerpo y guarda la combinación para ponértela cuando quieras."))
            } actions: {
                if !garments.isEmpty {
                    Button("Crear un look") { isCreating = true }
                        .glassButtonStyle(prominent: true)
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        FilterChip(title: String(localized: "Todos"), isSelected: !favoritesOnly) { favoritesOnly = false }
                        FilterChip(title: String(localized: "Favoritos"), systemImage: "heart.fill", isSelected: favoritesOnly) {
                            favoritesOnly.toggle()
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(outfits.filter { !favoritesOnly || $0.isFavorite }) { outfit in
                            NavigationLink(value: outfit) {
                                OutfitCard(outfit: outfit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
        }
    }
}

/// Un día de la semana, identificable para presentar hojas.
struct PlanDay: Identifiable, Hashable {
    let date: Date
    var id: Date { date }
}

/// Planificación semanal: un look por día.
struct WeekPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [OutfitPlan]
    @Query private var outfits: [Outfit]

    @State private var weekOffset = 0
    @State private var pickingDay: PlanDay?
    @State private var feedback = 0

    private var calendar: Calendar { .current }

    private var days: [Date] {
        let reference = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
        return WeekPlanner.days(around: reference, calendar: calendar)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        withAnimation(.snappy) { weekOffset -= 1 }
                    } label: {
                        Image(systemName: "chevron.left").padding(8)
                    }
                    .accessibilityLabel("Semana anterior")
                    Spacer()
                    VStack(spacing: 2) {
                        Text(weekTitle).font(.headline)
                        if weekOffset != 0 {
                            Button("Volver a esta semana") { withAnimation(.snappy) { weekOffset = 0 } }
                                .font(.caption.weight(.semibold))
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy) { weekOffset += 1 }
                    } label: {
                        Image(systemName: "chevron.right").padding(8)
                    }
                    .accessibilityLabel("Semana siguiente")
                }
                .buttonStyle(.borderless)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(days, id: \.self) { day in
                    dayRow(day)
                }
            } footer: {
                Text("Planifica qué ponerte cada día. Al abrir el look verás dónde está cada prenda.")
            }
        }
        .sheet(item: $pickingDay) { day in
            OutfitPickerSheet(title: day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))) { outfit in
                OutfitScheduler.plan(outfit, on: day.date, in: modelContext)
                feedback += 1
            }
        }
        .sensoryFeedback(.success, trigger: feedback)
    }

    private var weekTitle: String {
        guard let first = days.first, let last = days.last else { return "" }
        if weekOffset == 0 { return String(localized: "Esta semana") }
        if weekOffset == 1 { return String(localized: "La semana que viene") }
        return (first..<last).formatted(.interval.day().month(.abbreviated))
    }

    @ViewBuilder
    private func dayRow(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let plan = WeekPlanner.plan(for: day, in: plans, calendar: calendar)
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(isToday ? Color.white : Color.primary)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
            }
            .frame(width: 44)
            .accessibilityElement(children: .combine)

            if let outfit = plan?.outfit {
                NavigationLink(value: outfit) {
                    OutfitRow(outfit: outfit)
                }
            } else {
                Button {
                    pickingDay = PlanDay(date: day)
                } label: {
                    Label("Elegir un look", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            if plan != nil {
                Button("Quitar", role: .destructive) {
                    OutfitScheduler.removePlans(on: day, in: modelContext, calendar: calendar)
                }
                Button("Cambiar") { pickingDay = PlanDay(date: day) }
                    .tint(.accentColor)
            }
        }
        .contextMenu {
            if let outfit = plan?.outfit {
                if isToday {
                    Button { outfit.markWorn(); feedback += 1 } label: {
                        Label("Me lo he puesto", systemImage: "checkmark")
                    }
                }
                Button { pickingDay = PlanDay(date: day) } label: { Label("Cambiar look", systemImage: "arrow.triangle.2.circlepath") }
                Button(role: .destructive) {
                    OutfitScheduler.removePlans(on: day, in: modelContext, calendar: calendar)
                } label: { Label("Quitar", systemImage: "trash") }
            }
        }
    }
}

#Preview {
    LooksView()
        .environment(AppRouter())
        .modelContainer(AppModelContainer.preview())
}
