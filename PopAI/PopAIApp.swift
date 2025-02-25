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
    @StateObject var conversation = Conversation()

    var body: some Scene {
        WindowGroup {
            ConversationView()
                .environmentObject(Log.global)
                .environmentObject(nmea)
                .environmentObject(conversation)
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
