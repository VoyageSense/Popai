import SwiftUI

struct Interaction: Identifiable {
    let id = UUID()
    let request: String
    let response: String?
}

struct ConversationView: View {
    @EnvironmentObject var nmea: NMEA
    @State private var conversations: [Interaction] = [
        Interaction(
            request: "PopAI, what is the current depth?", response: "2.1 feet"),
        Interaction(request: "PopAI, what is my depth?", response: "2.2 feet"),
        Interaction(request: "PopAI, draft please?", response: "1.9 feet"),
    ]
    @State private var listening: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(conversations) { conversation in
                            Text(conversation.request)
                                .font(.largeTitle)
                                .padding()
                                .foregroundColor(Color.secondary)
                                .frame(
                                    maxWidth: .infinity, maxHeight: .infinity,
                                    alignment: .topLeading)
                            if let response = conversation.response {
                                Text(response)
                                    .font(.largeTitle)
                                    .padding([.horizontal, .bottom])
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity,
                                        alignment: .topLeading)
                            }
                            Divider().padding()
                        }
                    }
                }
                HStack {
                    Button(action: {
                        listening = !listening
                    }) {
                        Text((listening ? "Stop" : "Start") + " Listening")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                listening ? Color.secondary : Color.blue
                            )
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    NavigationLink(
                        destination: SettingsView().environmentObject(nmea)
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
}

struct SettingsView: View {
    @EnvironmentObject var nmea: NMEA
    @State private var enableLogging: Bool = true
    @State private var nmeaAddress: String = "192.168.4.1:1456"
    @State private var nmeaSource: NMEASource = NMEASource.TCP
    @State private var draftUnit: Unit = Unit.USCS

    var body: some View {
        Form {
            Section(header: Text("Units")) {
                Picker("Draft", selection: $settings.units) {
                    Text("Metric").tag(Units.Metric)
                    Text("USCS (\"Imperial\")").tag(Units.USCS)
                }
            }
            Section(header: Text("NMEA")) {
                Picker("Data Source", selection: $nmeaSource) {
                    Text("Remote TCP").tag(NMEASource.TCP)
                    Text("Sample Data").tag(NMEASource.SampleData)
                }
                TextField("Address", text: $nmeaAddress)
                    .disableAutocorrection(true)
                    .disabled(nmeaSource == NMEASource.SampleData)
                    .foregroundStyle(
                        nmeaSource == NMEASource.TCP ? .primary : .secondary)
            }
            Section(header: Text("Logging")) {
                Toggle("Enable", isOn: $enableLogging)
                NavigationLink(destination: LogsView()) {
                    Text("View log")
                }.disabled(!enableLogging)
            }
            Section(header: Text("Boat")) {
                HStack {
                    Text("Draft")
                    Spacer()
                    Text(
                        nmea.state.draft == nil
                            ? ""
                            : draftUnit == .Metric
                                ? "\(String(format: "%0.2f", nmea.state.draft!.value)) m"
                                : "\(nmea.state.draft!.inFeet.feet)' \(nmea.state.draft!.inFeet.inches)\""
                    )
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct LogsView: View {
    @State private var logs: String = NMEA.sampleData
    @State private var expandAIS: Bool = false

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(logs)
                .padding()
        }
    }
}

#Preview {
    ConversationView().environmentObject(
        NMEA(state: NMEA.State(draft: Meters(1))))
}
