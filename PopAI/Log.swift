import Foundation
import SwiftUI
import UniformTypeIdentifiers

func log(_ message: String) {
    Log.global.append(message)
}

class Log: ObservableObject, FileDocument {
    static let global = Log()

    private static let _maxEntries = 65536
    private var _entries: [String] = []
    private let _queue = DispatchQueue(
        label: "log.queue", attributes: .concurrent)

    var entries: [String] {
        return _entries
    }

    init(entries: [String] = []) {
        self._entries = entries
    }

    func append(_ line: String) {
        _queue.async(flags: .barrier) {
            if self._entries.count >= Log._maxEntries {
                self._entries.removeFirst()
            }
            self._entries.append(line)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func reset() {
        self._entries = []
    }

    // MARK: FileDocument

    static var readableContentTypes: [UTType] { [.plainText] }

    required init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
            let lines = String(data: data, encoding: .utf8)?.components(
                separatedBy: .newlines)
        {
            _entries = lines
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
