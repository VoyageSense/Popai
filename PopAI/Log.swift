import Foundation

func log(_ message: String) {
    let timestamp = Date().formatted(
        .iso8601
            .year()
            .month()
            .day()
            .time(includingFractionalSeconds: true))
    let entry = "\(timestamp) | \(message)"
    Log.global.append(entry)
    print(entry)
}

class Log: ObservableObject {
    static let global = Log()

    private static let maxEntries = 65536
    private(set) var entries: [String] = []
    private let queue = DispatchQueue(
        label: "log.queue", attributes: .concurrent)

    init(entries: [String] = []) {
        self.entries = entries
    }

    func append(_ line: String) {
        queue.async(flags: .barrier) {
            if self.entries.count >= Log.maxEntries {
                self.entries.removeFirst()
            }
            self.entries.append(line)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func reset() {
        queue.async(flags: .barrier) {
            self.entries = []
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func write(to: URL) throws {
        try entries.joined(separator: "\n").write(
            to: to, atomically: true, encoding: .utf8)
    }
}
