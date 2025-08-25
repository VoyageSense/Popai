// Copyright 2025 Alex Crawford
//
// This file is part of Popai.
//
// Popai is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// Popai is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// Popai. If not, see <https://www.gnu.org/licenses/>.

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
