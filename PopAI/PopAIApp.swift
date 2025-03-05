import SwiftUI

enum NMEASource: String {
    case TCP
    case SampleData
}

enum Units: String {
    case Metric
    case USCS
}

enum HeadingReference: String {
    case Magnetic
    case True
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
    @Published var headingReference: HeadingReference {
        didSet {
            UserDefaults.standard.set(
                headingReference.rawValue, forKey: "headingReference")
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
        self.recognizedKeywords = recognizedKeywords
        self.presentedRecognizedKeywords = recognizedKeywords.joined(
            separator: ", ")
        self.headingReference =
            HeadingReference(
                rawValue: UserDefaults.standard.string(
                    forKey: "headingReference") ?? "") ?? HeadingReference.True
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

    private var headingReading: String {
        switch settings.headingReference {
        case .True:
            if let heading = nmea.state.headingTrue {
                return String(
                    format: "%.1f° true", heading)
            } else {
                return "I don't know"
            }
        case .Magnetic:
            if let heading = nmea.state.headingMagnetic {
                return String(
                    format: "%.1f° magnetic", heading)
            } else {
                return "I don't know"
            }
        }
    }

    private var closestAheadReading: String {
        guard let position = nmea.state.position else {
            return "I don't know our position yet"
        }

        guard let heading = nmea.state.headingTrue else {
            return "I don't know our heading yet"
        }

        guard let vessel = closestAheadOf(position: position, heading: heading)
        else {
            return "I don't see anything in front of us on AIS yet"
        }

        if let name = vessel.name {
            return "That's the \(name)"
        } else {
            return "I don't see a name for it on AIS yet"
        }
    }

    private var closestBehindReading: String {
        guard let position = nmea.state.position else {
            return "I don't know our position yet"
        }

        guard let heading = nmea.state.headingTrue else {
            return "I don't know our heading yet"
        }

        guard
            let vessel = closestAheadOf(
                position: position, heading: fmod(heading + 180, 360))
        else {
            return "I don't see anything behind us on AIS yet"
        }

        if let name = vessel.name {
            return "That's the \(name)"
        } else {
            return "I don't see a name for it on AIS yet"
        }
    }

    private func closestAheadOf(
        position: NMEA.Coordinates, heading: Double, fieldOfView: Double = 45
    )
        -> NMEA.AIS.TargetInfo?
    {
        let myLat = position.latitude
        let myLong = position.longitude

        var closest: NMEA.AIS.TargetInfo?
        var minDistance: Double = .greatestFiniteMagnitude

        for (_, info) in nmea.state.ais?.targets ?? [:] {
            guard
                let lat = info.position?.latitude,
                let long = info.position?.longitude
            else {
                continue
            }

            log("Checking \(info)")

            let dx = (long - myLong) * cos(myLat * .pi / 180)
            let dy = lat - myLat

            let angle = fmod((atan2(dy, dx) * 180 / .pi) + 360 + 90, 360)  // 0 is East in trig

            let angleDiff =
                fmod(abs(angle - heading) + 180, 360) - 180
            log("  Angle: \(angle) (\(angleDiff))")

            if abs(angleDiff) <= fieldOfView {
                let distance = dx * dx + dy * dy
                if distance < minDistance {
                    minDistance = distance
                    closest = info
                }
            }
        }

        return closest
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
                if let buildInfoPath = Bundle.main.path(
                    forResource: "BuildInfo", ofType: "plist"),
                    let buildInfo = NSDictionary(contentsOfFile: buildInfoPath)
                {
                    let revision =
                        buildInfo["Revision"] as? String ?? "missing revision"
                    let builtAt =
                        buildInfo["BuiltAt"] as? String ?? "info missing"
                    log(
                        "Started app (\(revision), built at \(builtAt))"
                    )
                } else {
                    log("Started app (unknown revision)")
                }

                conversation.enableSpeech(startedListening: {
                    (context: Conversation.BeginContext) -> Void in
                    context.say(
                        [
                            "I'm listening",
                            "How can I help?",
                            "What's up?",
                        ].randomElement()!)
                }) {
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
                    } else if ["heading", "course", "coarse"].contains(
                        where: normalCorrected.contains)
                    {
                        return (corrected, headingReading)
                    } else if ["position", "coordinates"].contains(
                        where: normalCorrected.contains)
                    {
                        return (
                            corrected,
                            nmea.state.position?.string ?? "I don't know"
                        )
                    } else if ["boat", "vessel", "name"].contains(
                        where: normalCorrected.contains)
                    {
                        if ["ahead", "bow"].contains(
                            where: normalCorrected.contains)
                        {
                            return (corrected, closestAheadReading)
                        } else if ["astern", "behind us", "stern"].contains(
                            where: normalCorrected.contains)
                        {
                            return (corrected, closestBehindReading)
                        }
                    }

                    return (corrected, nil)
                }
            }
        }
    }
}
