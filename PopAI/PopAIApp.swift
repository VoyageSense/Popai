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

    var body: some Scene {
        WindowGroup {
            ConversationView()
                .environmentObject(Log.global)
                .environmentObject(nmea)
                .environmentObject(conversation)
                .environmentObject(settings)
                .onAppear {
                    log("Started app")

                    conversation.enableSpeech {
                        (request: Conversation.Request) -> String in
                        return "I don't know"
                    }

                    // TODO: testing out the parsing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        do {
                            try nmea.processSentence(
                                "$YDDBS,7.9,f,2.41,M,1.31,F*01\r\n")
                            try nmea.processSentence(
                                "$BLAH,7.9,f,2.41,M,1.31,F*4E\r\n")
                        } catch {
                            log("Failed to process sentence: \(error)")
                        }
                    }
                }
        }
    }
}
