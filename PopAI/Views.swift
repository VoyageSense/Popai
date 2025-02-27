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

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(conversation.pastInteractions) { interaction in
                    background(interaction.request).padding()
                    foreground(interaction.response).padding([
                        .horizontal, .bottom,
                    ])
                    Divider().padding()
                }
                if conversation.currentRequest.isEmpty {
                    prompt()
                } else {
                    foreground(conversation.currentRequest).padding()
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
            }
            Section(header: Text("App")) {
                TextField("Presented keyword", text: $settings.presentedKeyword)
                TextField(
                    "Recognized keywords",
                    text: $settings.presentedRecognizedKeywords)
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
    ConversationView(
        appLog: Log(entries: ["started app"]),
        nmea: NMEA(state: NMEA.State(draft: Meters(1)), log: NMEA.sampleData),
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
