import SwiftUI

enum NMEASource {
    case TCP
    case SampleData
}

enum Units: String {
    case Metric
    case USCS
}

@main
struct PopAIApp: App {
    @StateObject var nmea = NMEA()

    var body: some Scene {
        WindowGroup {
            ConversationView().environmentObject(nmea).onAppear {
                // TODO: testing out the parsing
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    do {
                        try nmea.processSentence(
                            "$YDDBS,7.9,f,2.41,M,1.31,F*01\r\n")
                    } catch {
                        print("failed to process sentence: \(error)")
                    }
                }
            }
        }
    }
}
