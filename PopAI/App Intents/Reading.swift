// Copyright 2025 Alex Crawford
//
// This file is part of Popai.
//
// Popai is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// Popai is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// Popai. If not, see <https://www.gnu.org/licenses/>.

import AppIntents

enum Reading: Identifiable, Hashable, Sendable {
    var id: String { name() }

    case depth(meters: Float?, feet: Float?)

    func name() -> String {
        switch self {
        case .depth:
            "Depth"
        }
    }

    func systemImageName() -> String {
        switch self {
        case .depth:
            "water.waves.and.arrow.trianglehead.down"
        }
    }

    func lastReading() -> String {
        switch self {
        case .depth(meters: .none, feet: .none):
            "unknown"
        case let .depth(meters: .some(meters), feet: .none):
            "\(meters) meters"
        case let .depth(meters: .none, feet: .some(feet)):
            "\(feet) feet"
        case let .depth(meters: .some(meters), feet: .some(feet)):
            "\(meters) meters, \(feet) feet"
        }
    }
}

actor ReadingStore {
    static let global = ReadingStore()

    var instruments: [String: Reading] = ["Depth": .depth(meters: 4, feet: 13.1233333333)]

    func add(_ reading: Reading) {
        instruments[reading.name()] = reading
    }

    func get(_ name: String) -> Reading? {
        instruments[name]
    }

    func all() ->  [Reading] {
        Array(instruments.values)
    }
}

struct ReadingEntity: AppEntity {
    static let defaultQuery = ReadingEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Instrument Reading")

    var id: String { name }

    var name: String { "\(reading.name())" }
    var reading: Reading

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(reading.name())",
            subtitle: "\(reading.lastReading())",
            image: DisplayRepresentation.Image(systemName: reading.systemImageName()))
    }

    init(_ reading: Reading) {
        self.reading = reading
    }
}

struct ReadingEntityQuery: EntityQuery {
    func entities(for names: [String]) async throws -> [ReadingEntity] {
        var entities: [ReadingEntity] = []
        for name in names {
            if let reading = await ReadingStore.global.get(name) {
                entities.append(ReadingEntity(reading))
            }
        }
        return entities
    }

    func suggestedEntities() async throws -> [ReadingEntity] {
        await ReadingStore.global.all().map { ReadingEntity($0) }
    }
}

struct ReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Instrument Reading"
    static let description = IntentDescription("Provides the current reading of an instrument on the NMEA bus.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$reading) reading")
    }

    @Parameter(title: "Reading", description: "An instrument reading.")
    var reading: ReadingEntity

    func perform() async throws -> some IntentResult & ReturnsValue<ReadingEntity> & ProvidesDialog {
        let dialog = IntentDialog(
            full: LocalizedStringResource(stringLiteral: reading.reading.lastReading()),
            systemImageName: reading.reading.systemImageName())

        return .result(value: reading, dialog: dialog)
    }
}
