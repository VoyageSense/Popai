import SwiftUI

struct ConversationView: View {
    @EnvironmentObject var appLog: Log
    @EnvironmentObject var nmea: NMEA
    @EnvironmentObject var conversation: Conversation
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var networkClient: Client

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
                        destination: SettingsView()
                            .environmentObject(nmea)
                            .environmentObject(appLog)
                            .environmentObject(settings)
                            .environmentObject(networkClient)
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

    @ViewBuilder
    var conversations: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 8) {
                if conversation.listeningForFirst {
                    Text("PopAI, ...")
                        .font(.largeTitle)
                        .padding()
                        .foregroundColor(Color.secondary)
                } else {
                    ForEach(conversation.pastInteractions) { interaction in
                        Text(interaction.request)
                            .font(.largeTitle)
                            .padding()
                            .foregroundColor(Color.secondary)
                        Text(interaction.response)
                            .font(.largeTitle)
                            .padding([.horizontal, .bottom])
                        Divider().padding()
                    }
                    Text(conversation.currentRequest)
                        .font(.largeTitle)
                        .padding()
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var nmea: NMEA
    @EnvironmentObject var appLog: Log
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var networkClient: Client

    var body: some View {
        Form {
            Section(header: Text("Units")) {
                Picker("Draft", selection: $settings.draftUnits) {
                    Text("Metric").tag(Units.Metric)
                    Text("USCS (\"Imperial\")").tag(Units.USCS)
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
                    destination: LogView("nmea").environmentObject(nmea.log)
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
                            ? ""
                            : settings.draftUnits == .Metric
                                ? "\(String(format: "%0.2f", nmea.state.draft!.value)) m"
                                : "\(nmea.state.draft!.inFeet.feet)' \(nmea.state.draft!.inFeet.inches)\""
                    )
                }
            }
            Section(header: Text("App")) {
                NavigationLink(
                    destination: LogView("popai").environmentObject(appLog)
                ) {
                    Text("Log")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct LogView: View {
    @EnvironmentObject var log: Log
    @State private var showFileExporter = false
    @State private var showAlert = false
    @State private var lastError = ""
    private let name: String

    init(_ name: String) {
        self.name = name
    }

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
                        log.entries.map { entry in
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
                showFileExporter = true
            }) {
                Text("Save and reset log...")
                    .padding()
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: log,
                contentType: .plainText,
                defaultFilename: defaultFilename
            ) { result in
                switch result {
                case .success(let url):
                    PopAI.log("NMEA logs saved to \(url)")
                    log.reset()
                case .failure(let error):
                    lastError = error.localizedDescription
                    showAlert = true
                    PopAI.log("Failed to save NMEA logs to: \(lastError)")
                }
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

#Preview {
    ConversationView()
        .environmentObject(Log(entries: ["started app"]))
        .environmentObject(
            NMEA(state: NMEA.State(draft: Meters(1)), log: NMEA.sampleData)
        ).environmentObject(Settings())
        .environmentObject(Client())
        .environmentObject(
            Conversation(
                enabled: true,
                currentRequest: "PopAI, what is",
                pastInteractions: [
                    Conversation.Interaction(
                        request: "PopAI, what is the current depth?",
                        response: "2.1 feet"),
                    Conversation.Interaction(
                        request: "PopAI, what is my depth?",
                        response: "2.2 feet"),
                    Conversation.Interaction(
                        request: "PopAI, what's the draft?",
                        response: "1.9 feet"),
                ]))
}
