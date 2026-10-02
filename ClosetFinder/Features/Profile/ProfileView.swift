import SwiftData
import SwiftUI

/// Medidas corporales de cada persona de la casa y las tallas que le corresponden.
struct ProfileView: View {
    @Query(sort: \BodyProfile.createdAt) private var profiles: [BodyProfile]
    @AppStorage("selectedProfileID") private var selectedID = ""

    @State private var editorTarget: ProfileEditorTarget?

    private var selected: BodyProfile? {
        profiles.first { $0.uuid.uuidString == selectedID } ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selected {
                    content(for: selected)
                } else {
                    ContentUnavailableView {
                        Label("Añade tus medidas", systemImage: "figure.stand")
                    } description: {
                        Text("Con tu altura, pecho, cintura y pie calculamos tus tallas y te avisamos si una prenda te queda bien.")
                    } actions: {
                        Button("Añadir medidas") { editorTarget = .new }
                            .glassButtonStyle(prominent: true)
                    }
                }
            }
            .navigationTitle("Medidas")
            .toolbar {
                if let selected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Editar") { editorTarget = .edit(selected) }
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                ProfileEditorView(target: target) { saved in
                    selectedID = saved.uuid.uuidString
                }
            }
            .appNavigationDestinations()
        }
    }

    private func content(for profile: BodyProfile) -> some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(profiles) { person in
                            personChip(person, isSelected: person === profile)
                        }
                        Button {
                            editorTarget = .new
                        } label: {
                            Label("Persona", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            Section {
                HStack(spacing: 18) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 92, weight: .ultraLight))
                        .foregroundStyle(Color.accentColor.gradient)
                        .frame(width: 80)
                        .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        ForEach(BodyMeasurement.allCases) { measurement in
                            HStack {
                                Text(measurement.title).foregroundStyle(.secondary)
                                Spacer()
                                Text(profile.value(of: measurement)?.centimeters ?? "—")
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                            .padding(.vertical, 5)
                            if measurement != BodyMeasurement.allCases.last { Divider() }
                        }
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text(profile.sizing.title)
            }

            Section {
                let recommendations = profile.recommendations
                if recommendations.isEmpty {
                    Text("Añade pecho, cintura o pie para ver tus tallas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recommendations) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(item.size).font(.headline)
                                if !item.equivalents.isEmpty {
                                    Text(item.equivalents).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Tallas recomendadas")
            } footer: {
                Text("Calculadas con tablas europeas habituales. Cada marca talla un poco distinto: úsalas como referencia.")
            }

            let owned = profile.garments ?? []
            if !owned.isEmpty {
                Section {
                    NavigationLink {
                        GarmentListView(title: "Ropa de \(profile.name)", garments: owned)
                    } label: {
                        Label("Ropa de \(profile.name)", systemImage: "hanger")
                            .badge(owned.count)
                    }
                }
            }
        }
    }

    private func personChip(_ person: BodyProfile, isSelected: Bool) -> some View {
        Button {
            selectedID = person.uuid.uuidString
        } label: {
            HStack(spacing: 8) {
                Text(person.initial)
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(isSelected ? Color.white.opacity(0.25) : Color(.tertiarySystemFill), in: Circle())
                Text(person.name)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.leading, 5)
            .padding(.trailing, 14)
            .frame(minHeight: 38)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ProfileView()
        .modelContainer(AppModelContainer.preview())
}
