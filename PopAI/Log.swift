import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

class Log: ObservableObject, FileDocument {
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
        self.entries = []
    }

    // MARK: FileDocument

    static var readableContentTypes: [UTType] { [.plainText] }

    required init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
            let lines = String(data: data, encoding: .utf8)?.components(
                separatedBy: .newlines)
        {
            entries = lines
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(
            regularFileWithContents: entries.joined(separator: "\n").data(
                using: .utf8)!)
    }
}
