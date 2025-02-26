import Foundation
import Network

class Client: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false

    private let queue = DispatchQueue(label: "ClientQueue")
    private var connection: NWConnection?
    private var nmea: NMEA?

    func connect(to: String, nmea: NMEA) {
        let parts = to.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            log("NMEA address is missing a port number")
            return
        }

        let host = NWEndpoint.Host(String(parts.first!))
        guard let port = UInt16(parts.last!),
            let port = NWEndpoint.Port(rawValue: port)
        else {
            log("NMEA address has invalid port number")
            return
        }

        connection = NWConnection(host: host, port: port, using: .tcp)
        self.nmea = nmea

        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log("Connected to \(host):\(port)")
                self.isConnected = true
                self.isConnecting = false
                self.receive()
            case .failed(let error):
                log("Connection failed: \(error.localizedDescription)")
                self.isConnecting = false
            case .waiting(let error):
                log("Waiting to reconnect: \(error.localizedDescription)")
            case .cancelled:
                log("Connection cancelled")
                self.isConnecting = false
            default:
                log("Unknown connection state")
                break
            }
        }

        connection?.start(queue: queue)
        isConnecting = true
    }

    func disconnect() {
        connection?.cancel()
        isConnected = false
        isConnecting = false
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) {
            data, _, isComplete, error in
            if let data = data,
                let sentences = String(data: data, encoding: .utf8)
            {
                for sentence in sentences.components(separatedBy: .newlines) {
                    do {
                        try self.nmea!.processSentence(sentence)
                    } catch {
                        log("Failed to process '\(sentence)': \(error)")
                    }
                }
            }
            if let error = error {
                log("Receive error: \(error.localizedDescription)")
            }
            if isComplete {
                log("Connection closed by server")
                self.isConnected = false
            } else {
                self.receive()
            }
        }
    }
}
