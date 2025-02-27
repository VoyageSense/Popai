import SwiftUI

enum NMEASource: String {
    case TCP
    case SampleData
}

enum Units: String {
    case Metric
    case USCS
}

class Settings: ObservableObject {
    @Published var draftUnits: Units {
        didSet {
            UserDefaults.standard.set(draftUnits.rawValue, forKey: "draftUnits")
        }
    }
    @Published var nmeaSource: NMEASource {
        didSet {
            UserDefaults.standard.set(nmeaSource.rawValue, forKey: "nmeaSource")
        }
    }
    @Published var nmeaAddress: String {
        didSet {
            UserDefaults.standard.set(nmeaAddress, forKey: "nmeaAddress")
        }
    }

    init() {
        self.draftUnits =
            Units(
                rawValue: UserDefaults.standard.string(forKey: "draftUnits")
                    ?? "")
            ?? Units.Metric
        self.nmeaSource =
            NMEASource(
                rawValue: UserDefaults.standard.string(forKey: "nmeaSource")
                    ?? "")
            ?? NMEASource.TCP
        self.nmeaAddress =
            UserDefaults.standard.string(forKey: "nmeaAddress")
            ?? "192.168.4.1:1456"
    }
}

@main
struct PopAIApp: App {
    @StateObject var nmea = NMEA()
    @StateObject var conversation = Conversation()
    @StateObject var settings = Settings()
    @StateObject var client = Client()

    var body: some Scene {
        WindowGroup {
            ConversationView(
                appLog: Log.global,
                nmea: nmea,
                conversation: conversation,
                settings: settings,
                networkClient: client
            )
            .onAppear {
                log("Started app")

                conversation.enableSpeech {
                    (request: Conversation.Request) -> String in
                    switch request {
                    case Conversation.Request.Draft:
                        switch settings.draftUnits {
                        case .Metric:
                            if let meters = nmea.state.draft?.value {
                                return String(format: "%.1f meters", meters)
                            } else {
                                return "I don't know"
                            }
                        case .USCS:
                            if let feet = nmea.state.draft?.inFeet {
                                return String(
                                    format: "%d feet, %d inches", feet.feet,
                                    feet.inches)
                            } else {
                                return "I don't know"
                            }
                        }
                    }
                }
            }
        }
    }
}
