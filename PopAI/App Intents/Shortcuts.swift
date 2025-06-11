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
