import Foundation
import Testing
@testable import ClosetFinder

/// Usa el modelo real de Apple Intelligence, así que solo se ejecuta en un iPhone con
/// Apple Intelligence activado. En el simulador el modelo dice estar disponible pero no puede
/// generar respuestas (`ModelManagerError 1026`), por eso ahí y en CI se omite.
@MainActor
struct SmartSearchTests {
    nonisolated static var canRunModel: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        SmartSearch.isAvailable
        #endif
    }

    @Test(.enabled(if: SmartSearchTests.canRunModel), .timeLimit(.minutes(1)))
    func interpretsColorAndCategory() async throws {
        let result = try await SmartSearch.interpret("una chaqueta azul")
        #expect(result.tokens.contains(.color(.blue)))
        #expect(result.tokens.contains(.category(.jacket)))
    }

    @Test(.enabled(if: SmartSearchTests.canRunModel), .timeLimit(.minutes(1)))
    func interpretsColdWeather() async throws {
        let result = try await SmartSearch.interpret("algo de abrigo para la nieve")
        let categories = result.tokens.filter { $0.kind == SearchToken.category(.coat).kind }
        #expect(!categories.isEmpty)
        #expect(result.tokens.contains(.season(.autumnWinter)) || result.text.localizedCaseInsensitiveContains("nieve"))
    }
}
