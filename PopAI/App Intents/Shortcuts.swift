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

class Shortcuts: AppShortcutsProvider {
    static let shortcutTileColor = ShortcutTileColor.navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadingIntent(),
            phrases: [
                "Ask \(.applicationName) for the \(\.$reading)"
            ],
            shortTitle: "Get Instrument Reading",
            systemImageName: "gauge.with.dots.needle.bottom.100percent",
            parameterPresentation: ParameterPresentation(
                for: \.$reading,
                summary: Summary("Get the \(\.$reading)"),
                optionsCollections: {
                    OptionsCollection(ReadingEntityQuery(), title: "All Instrument Readings")
                }
            )
        )
    }
}
