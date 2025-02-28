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
    @Published var presentedKeyword: String {
        didSet {
            UserDefaults.standard.set(
                presentedKeyword, forKey: "presentedKeyword")
        }
    }
    @Published var presentedRecognizedKeywords: String {
        didSet {
            recognizedKeywords = presentedRecognizedKeywords.split(
                separator: ","
            ).map({ keyword in
                keyword.trimmingCharacters(in: .whitespaces).lowercased()
            })
        }
    }
    var recognizedKeywords: [String] {
        didSet {
            UserDefaults.standard.set(
                recognizedKeywords.joined(separator: ","),
                forKey: "recognizedKeywords")

            let newPresentedRecognizedKeywords = recognizedKeywords.joined(
                separator: ", ")
            if newPresentedRecognizedKeywords != presentedRecognizedKeywords {
                presentedRecognizedKeywords = newPresentedRecognizedKeywords
            }
        }
    }
    let defaultPresentedKeyword = "PopAI"
    let defaultRecognizedKeywords = [
        "popeye", "poppy", "papa", "pape", "bye-bye", "pop ai", "hope",
    ]

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
        self.presentedKeyword =
            UserDefaults.standard.string(forKey: "presentedKeyword")
            ?? defaultPresentedKeyword

        let recognizedKeywords =
            UserDefaults.standard.string(forKey: "recognizedKeywords")?.split(
                separator: ","
            ).map(String.init) ?? defaultRecognizedKeywords
        self.presentedRecognizedKeywords = ""  // This is set by the next assignment
        self.recognizedKeywords = recognizedKeywords
    }

    func resetKeywords() {
        DispatchQueue.main.async {
            self.presentedKeyword = self.defaultPresentedKeyword
            self.recognizedKeywords = self.defaultRecognizedKeywords
        }
    }
}

struct Correction {
    let presented: String
    let recognized: [String]

    init(_ presented: String, _ recognized: [String]) {
        self.presented = presented
        self.recognized = recognized
    }
}

@main
struct PopAIApp: App {
    @StateObject var nmea = NMEA()
    @StateObject var conversation = Conversation()
    @StateObject var settings = Settings()
    @StateObject var client = Client()

    private var draftReading: String {
        switch settings.draftUnits {
        case .Metric:
            if let meters = nmea.state.draft?.value {
                return String(
                    format: "%.1f meters", meters)
            } else {
                return "I don't know"
            }
        case .USCS:
            if let feet = nmea.state.draft?.inFeet {
                return String(
                    format: "%d feet, %d inches",
                    feet.feet,
                    feet.inches)
            } else {
                return "I don't know"
            }
        }
    }

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
                    (transcription: String) -> (String, String?) in
                    log("Heard: \(transcription)")

                    let normal = transcription.lowercased()
                    guard
                        settings.recognizedKeywords.contains(
                            where: normal.contains)
                    else {
                        return (transcription, nil)
                    }

                    log("Recognized: \(transcription)")

                    let corrections = [
                        Correction(
                            settings.presentedKeyword,
                            settings.recognizedKeywords),
                        Correction("depth", ["debt", "death", "deaf"]),
                    ]

                    var corrected = transcription
                    corrections.forEach({ correction in
                        correction.recognized.forEach({ recognized in
                            if let range = corrected.range(
                                of: recognized, options: .caseInsensitive)
                            {
                                corrected.replaceSubrange(
                                    range,
                                    with: correction.presented.first?
                                        .isUppercase ?? false
                                        ? correction.presented
                                        : corrected[range].first!.isUppercase
                                            ? correction.presented
                                                .localizedCapitalized
                                            : correction.presented)
                            }
                        })
                    })

                    log("Corrected to: \(corrected)")

                    let normalCorrected = corrected.lowercased()
                    if ["draft", "depth"].contains(
                        where: normalCorrected.contains)
                    {
                        return (corrected, draftReading)
                    } else {
                        return (corrected, nil)
                    }
                }
            }
        }
    }
}
