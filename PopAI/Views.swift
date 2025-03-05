import SwiftUI

struct ConversationView: View {
    @ObservedObject var appLog: Log
    @ObservedObject var nmea: NMEA
    @ObservedObject var conversation: Conversation
    @ObservedObject var settings: Settings
    @ObservedObject var networkClient: Client

    var body: some View {
        NavigationStack {
            VStack {
                conversations
                HStack {
                    Button(action: {
                        conversation.toggleListening()
                    }) {
                        Text(
                            conversation.isEnabled
                                ? ((conversation.isOngoing ? "Stop" : "Start")
                                    + " Listening")
                                : "Speech recognition disabled"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            conversation.isEnabled
                                ? (conversation.isOngoing
                                    ? Color.secondary : Color.blue)
                                : Color.red
                        )
                        .foregroundColor(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .disabled(!conversation.isEnabled)
                    NavigationLink(
                        destination: SettingsView(
                            nmea: nmea,
                            appLog: appLog,
                            settings: settings,
                            networkClient: networkClient)
                    ) {
                        Image(systemName: "gearshape.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .foregroundColor(Color.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    var conversations: some View {
        func background(_ text: String) -> some View {
            Text(text)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }

        func foreground(_ text: String) -> some View {
            Text(text)
                .font(.largeTitle)
        }

        func prompt() -> some View {
            background(settings.presentedKeyword + " ...")
        }

        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(conversation.pastInteractions) { interaction in
                        background(interaction.request).padding()
                        foreground(interaction.response).padding([
                            .horizontal, .bottom,
                        ])
                        Divider().padding()
                    }
                    if conversation.currentRequest.isEmpty {
                        prompt().padding().id("last")
                    } else {
                        foreground(conversation.currentRequest)
                            .padding()
                            .id("last")
                    }
                }
                .onChange(of: conversation.pastInteractions) {
                    withAnimation {
                        proxy.scrollTo("last")
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var nmea: NMEA
    @ObservedObject var appLog: Log
    @ObservedObject var settings: Settings
    @ObservedObject var networkClient: Client

    var body: some View {
        Form {
            Section(header: Text("Units")) {
                Picker("Draft", selection: $settings.draftUnits) {
                    Text("Metric").tag(Units.Metric)
                    Text("USCS (\"Imperial\")").tag(Units.USCS)
                }
                Picker("Heading", selection: $settings.headingReference) {
                    Text("True").tag(HeadingReference.True)
                    Text("Magnetic").tag(HeadingReference.Magnetic)
                }
            }
            Section(header: Text("NMEA")) {
                Picker("Data Source", selection: $settings.nmeaSource) {
                    Text("Remote TCP").tag(NMEASource.TCP)
                    Text("Sample Data").tag(NMEASource.SampleData)
                }
                TextField("Address", text: $settings.nmeaAddress)
                    .disableAutocorrection(true)
                    .keyboardType(.numbersAndPunctuation)
                    .disabled(settings.nmeaSource == NMEASource.SampleData)
                    .foregroundStyle(
                        settings.nmeaSource == NMEASource.TCP
                            ? .primary : .secondary)
                NavigationLink(
                    destination: LogView(log: nmea.log, name: "nmea")
                ) {
                    Text("Log")
                }
                Button(action: {
                    switch settings.nmeaSource {
                    case .TCP:
                        if networkClient.isConnected {
                            networkClient.disconnect()
                        } else {
                            networkClient.connect(
                                to: settings.nmeaAddress, nmea: nmea)
                        }
                    case .SampleData:
                        for sentence in NMEA.sampleData.entries {
                            do {
                                try nmea.processSentence(sentence)
                            } catch {
                                log("Failed to process '\(sentence)': \(error)")
                            }
                        }
                    }
                }) {
                    Text(
                        networkClient.isConnecting
                            ? "Connecting..."
                            : networkClient.isConnected
                                ? "Disconnect" : "Connect"
                    )
                    .frame(
                        maxWidth: .infinity, alignment: .center)
                }.disabled(networkClient.isConnecting)
            }
            Section(header: Text("Boat")) {
                HStack {
                    Text("Draft")
                    Spacer()
                    Text(
                        nmea.state.draft == nil
                            ? "Unknown"
                            : settings.draftUnits == .Metric
                                ? "\(String(format: "%0.2f", nmea.state.draft!.value)) m"
                                : "\(nmea.state.draft!.inFeet.feet)' \(nmea.state.draft!.inFeet.inches)\""
                    )
                    .foregroundStyle(
                        nmea.state.draft == nil ? .secondary : .primary)
                }
                HStack {
                    Text("Heading")
                    Spacer()
                    Text(
                        // TODO: This should be a computed property on a ViewModel
                        {
                            switch (
                                nmea.state.headingMagnetic,
                                nmea.state.headingTrue
                            ) {
                            case (nil, nil):
                                "Unknown"
                            case let (nil, .some(hTrue)):
                                "\(String(format: "%0.1f°T", hTrue))"
                            case let (.some(hMagnetic), nil):
                                "\(String(format: "%0.1f°M", hMagnetic))"
                            case let (.some(hMagnetic), .some(hTrue)):
                                "\(String(format: "%0.1f°M / %0.1f°T", hMagnetic, hTrue))"
                            }
                        }()
                    )
                    .foregroundStyle(
                        nmea.state.headingMagnetic == nil
                            && nmea.state.headingTrue == nil
                            ? .secondary : .primary)
                }
                HStack {
                    Text("Position")
                    Spacer()
                    Text(nmea.state.position?.string ?? "Unknown")
                        .foregroundStyle(
                            nmea.state.position == nil ? .secondary : .primary)
                }
                NavigationLink(destination: AISView(nmea: nmea)) {
                    Text("AIS Targets")
                }
            }
            Section(header: Text("App")) {
                TextField("Presented keyword", text: $settings.presentedKeyword)
                TextField(
                    "Recognized keywords",
                    text: $settings.presentedRecognizedKeywords)
                Button(action: {
                    settings.resetKeywords()
                }) {
                    Text("Reset keywords")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                NavigationLink(
                    destination: LogView(log: appLog, name: "popai")
                ) {
                    Text("Log")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct LogView: View {
    @ObservedObject var log: Log
    @State private var showFileExporter = false
    @State private var showAlert = false
    @State private var lastError = ""
    let name: String

    var defaultFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddyyyy_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(name)_\(timestamp).txt"
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Text(
                        log.entries.suffix(100).map { entry in
                            entry.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                        }.joined(separator: "\n")
                    )
                    .padding()
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height,
                        alignment: .topLeading)
                }
            }
            Button(action: {
                let tempDirectory = FileManager.default.temporaryDirectory
                let fileURL = tempDirectory.appendingPathComponent(
                    defaultFilename)

                do {
                    try log.write(to: fileURL)

                    if let windowScene = UIApplication.shared.connectedScenes
                        .first as? UIWindowScene,
                        let rootViewController = windowScene.windows.first?
                            .rootViewController
                    {
                        let shareView = UIActivityViewController(
                            activityItems: [fileURL],
                            applicationActivities: nil
                        )
                        shareView.completionWithItemsHandler = {
                            activity, success, items, error in
                            if success {
                                log.reset()
                            } else if let error = error {
                                PopAI.log(
                                    "Failed to share log '\(name)': \(error.localizedDescription)"
                                )
                            } else {
                                PopAI.log(
                                    "Sharing of log '\(name)' was canceled")
                            }
                        }
                        rootViewController.present(shareView, animated: true)
                    }
                } catch {
                    PopAI.log("Failed while writing \(name) log to \(fileURL)")
                    lastError = error.localizedDescription
                    showAlert = true
                }
            }) {
                Text("Share and reset log...")
                    .padding()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(lastError),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct AISView: View {
    struct AISTargetInfo: Identifiable, Equatable, Hashable {
        let mmsi: String
        let info: NMEA.AIS.TargetInfo

        var name: String {
            info.name ?? ""
        }

        var lastUpdate: String {
            info.updatedAt.formatted(date: .omitted, time: .standard)
        }

        var position: String {
            info.position?.string ?? "Position Unknown"
        }

        var id: String {
            mmsi
        }

        static func == (left: Self, right: Self) -> Bool {
            left.mmsi == right.mmsi
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(mmsi)
        }
    }

    @ObservedObject var nmea: NMEA
    @State private var sortOrder = [KeyPathComparator<AISTargetInfo>(\.name)]

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        private var isCompact: Bool { horizontalSizeClass == .compact }
    #else
        private let isCompact = false
    #endif

    var body: some View {
        if isCompact {
            compact
        } else {
            full
        }
    }

    var full: some View {
        Table(
            nmea.state.ais?.targets.map {
                AISTargetInfo(mmsi: String($0.key), info: $0.value)
            }.sorted(using: sortOrder) ?? [],
            sortOrder: $sortOrder
        ) {
            TableColumn("Name", value: \.name, comparator: .lexical)
            TableColumn("MMSI", value: \.mmsi, comparator: .lexical)
            TableColumn("Position", value: \.position, comparator: .lexical)
            TableColumn(
                "Last Update", value: \.lastUpdate, comparator: .lexical)
        }
    }

    var compact: some View {
        let targets: [AISTargetInfo] =
            nmea.state.ais?.targets.map {
                AISTargetInfo(mmsi: String($0.key), info: $0.value)
            }.sorted(using: sortOrder) ?? []

        return Table(targets, sortOrder: $sortOrder) {
            TableColumn("Target") { target in
                VStack {
                    HStack {
                        Text(target.name)
                            .font(.title)
                            .frame(
                                maxWidth: .infinity, alignment: .leading)
                        Text(target.mmsi)
                            .frame(
                                maxWidth: .infinity, alignment: .trailing)
                    }
                    HStack {
                        Text(target.lastUpdate)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(target.position)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

#Preview {
    ConversationView(
        appLog: Log(entries: ["2025-02-28T21:28:16.838 | Started app"]),
        nmea: NMEA(
            state: NMEA.State(
                draft: Meters(1),
                headingMagnetic: 183.7,
                headingTrue: 196.5,
                position: NMEA.Coordinates(latitude: 37.45, longitude: 122.18),
                ais: NMEA.AIS(targets: [
                    366_900_010: NMEA.AIS.TargetInfo(name: "Alcatraz Flyer"),
                    366_900_020: NMEA.AIS.TargetInfo(
                        name: "Ship 2",
                        position: NMEA.Coordinates(
                            latitude: 37.45, longitude: 122.18)),
                ])),
            log: NMEA.sampleData),
        conversation: Conversation(
            enabled: true,
            currentRequest: "",
            pastInteractions: [
                Conversation.Interaction(
                    request: "PopAI, what is the current depth?",
                    response: "2.1 feet"),
                Conversation.Interaction(
                    request: "PopAI, what's the draft?",
                    response: "1.9 feet"),
            ]),
        settings: Settings(),
        networkClient: Client())
}
