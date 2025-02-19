import SwiftUI

enum NMEASource {
    case TCP
    case SampleData
}

enum Unit {
    case Metric
    case USCS
}

@main
struct PopAIApp: App {
    var body: some Scene {
        WindowGroup {
            ConversationView()
        }
    }
}
