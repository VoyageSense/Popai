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

class NMEA: ObservableObject {
    typealias Fields = ArraySlice<Substring>

    struct Coordinates {
        let latitude: Double
        let longitude: Double

        var string: String {
            String(
                format: "%05.2f°%@ %06.2f°%@",
                latitude.magnitude, latitude.isLess(than: 0) ? "S" : "N",
                longitude.magnitude, longitude.isLess(than: 0) ? "W" : "E")
        }
    }

    struct AIS {
        struct TargetInfo {
            let createdAt = Date.now
            var updatedAt = Date.now
            var name: String?
            var position: Coordinates?

            init(name: String? = nil, position: Coordinates? = nil) {
                self.name = name
                self.position = position
            }
        }

        typealias MMSI = UInt32

        var targets: [MMSI: TargetInfo] = [:]
    }

    struct State {
        var draft: Meters?
        var headingMagnetic: Double?
        var headingTrue: Double?
        var position: Coordinates?
        var ais: AIS?
    }

    @Published var state: State
    @Published var log: Log

    public static let sampleData: Log = Log(entries: [
        "$YDGSV,3,1,12,06,19,043,38,11,53,045,41,12,76,144,48,20,48,106,45*75",
        "$YDGSV,3,2,12,24,10,199,43,25,59,305,43,29,31,287,46,05,31,152,43*7A",
        "$YDGSV,3,3,12,28,12,313,34,74,61,189,40,75,51,315,45,73,18,164,42*77",
        "$YDGSA,M,3,06,11,12,20,24,25,29,05,28,74,75,73,0.7,0.9,,1*0E",
        "$YDGGA,000250.00,3745.3487,N,12218.2355,W,1,12,0.70,-29.29,M,-25.20,M,0.00,0000*68",
        "$YDMDA,,I,,B,,C,17.8,C,,,,C,272.2,T,259.5,M,16.3,N,8.4,M*21",
        "$YDHDG,185.2,,,12.7,E*05",
        "$YDDPT,4.08,-1.67,*50",
        "$YDMWV,58.3,R,10.1,M,A*2D",
        "$YDMWV,73.2,T,8.4,M,A*1F",
        "$YDVTG,210.1,T,197.4,M,6.0,N,11.2,K,A*14",
        "!AIVDM,1,1,,B,35NQH10Oh:o@<vFEWwgECakV01kP,0*29",
        "!AIVDM,1,1,,A,15Mvht0P00o?aL0E`Vff4?wT2408,0*7D",
        "$YDVWR,61.6,R,19.7,N,10.2,M,36.5,K*59",
        "$YDVWT,74.2,R,16.4,N,8.5,M,30.4,K*6A",
        "!AIVDM,1,1,,B,15N7G;0000G@6P6Ea5Be>q5T00Rn,0*57",
        "!AIVDM,1,1,,B,15NO>Dd000o?nBBEd980iRKV2HMf,0*57",
        "!AIVDM,1,1,,A,15MjHDP047o?`JTEc2;Ln:CV0D2s,0*53",
        "!AIVDM,1,1,,B,15MvrUP000G@FKjEUtDim1UR0000,0*2F",
        "$YDGLL,3745.3498,N,12218.2354,W,000250.00,A,A*7D",
        "$YDRMC,000250.00,A,3745.3498,N,12218.2354,W,6.7,214.2,150225,12.8,E,A,C*70",
        "$YDHTD,V,,,,,,,,,,,0.0,T,,,,*45",
        "$YDZDA,000250.06,15,02,2025,,*6E",
        "$YDROT,-220.8,A*1E",
        "$YDHDG,183.7,,,12.8,E*09",
        "$YDHDM,183.7,M*32",
        "$YDHDT,196.5,T*34",
        "$YDMWD,272.2,T,259.4,M,16.4,N,8.4,M*69",
        "$YDMWV,65.2,R,9.9,M,A*12",
        "$YDMWV,74.8,T,8.4,M,A*12",
        "$YDDPT,4.08,-1.67,*50",
        "$YDDBT,13.3,f,4.08,M,2.23,F*32",
        "$YDDBS,7.9,f,2.41,M,1.31,F*01",
        "$YDVHW,196.5,T,183.7,M,5.6,N,10.4,K*78",
        "$YDVTG,214.2,T,201.4,M,6.7,N,12.5,K,A*1C",
        "$YDVLW,14332.946,N,109.715,N*57",
        "$YDRSA,-15.7,A,,V*7A",
        "$YDMTW,17.8,C*00",
        "!AIVDM,1,1,,A,403OthivTWP2jo@FfNEjH@O02L3E,0*47",
        "!AIVDM,1,1,,A,15NGdT?P00G?n=8Edi39b?wV2<2J,0*2F",
        "!AIVDM,1,1,,B,15NH7?PP01o@7C0E`vVf4?wT28Ms,0*3A",
        "!AIVDM,1,1,,B,403OtVQvTWP2koCklLEpHDg028Mw,0*6B",
        "!AIVDM,1,1,,A,15MiuGPP5bG?NqlEd2AmUww`0<28,0*44",
        "!AIVDM,2,1,5,A,55NDS<`00001L@G??S84h<5A85b0HiTE8000001S1@N55t0Ht008000,0*5A",
        "!AIVDM,2,2,5,A,0000000000000000,2*11",
        "!AIVDM,1,1,,A,15NDS<PP1;o?WlvEa9In4gw828ED,0*7D",
    ])

    private let recognizedTypes: [String: (Fields, inout NMEA.State) -> Void]
    private var unrecognizedTypes: Set<String> = Set()

    init(state: State = State(), log: Log = Log()) {
        self.state = state
        self.log = log
        self.recognizedTypes = [
            "DBT": processTransducerDepth,
            "GGA": ignore,
            "GLL": processGeographicPosition,
            "GSA": ignore,
            "GSV": ignore,
            "HDG": processHeading,
            "HDM": ignore,
            "HDT": ignore,
            "AIVDM": processAISMessage,
        ]
    }

    enum ProcessingError: Error {
        case unrecognizedEncoding
        case checksumNotFound
        case missingEnding
        case malformedChecksum
        case invalidChecksum
        case malformedTag
    }

    func processSentence(_ sentence: String) throws {
        if sentence.isEmpty {
            return
        }

        enum Format {
            case conventional
            case encapsulated
        }

        log.append(sentence)

        let format =
            switch sentence.prefix(1) {
            case "$":
                Format.conventional
            case "!":
                Format.encapsulated
            default:
                throw ProcessingError.unrecognizedEncoding
            }

        let sentenceParts = sentence.dropFirst(1).split(separator: "*")
        guard sentenceParts.count == 2 else {
            throw ProcessingError.checksumNotFound
        }

        let (payload, sumStr) = (sentenceParts[0], sentenceParts[1])
        guard sumStr.count == 2 else {
            throw ProcessingError.malformedChecksum
        }

        guard let sum = UInt8(sumStr, radix: 16) else {
            throw ProcessingError.malformedChecksum
        }

        guard sum == payload.utf8.reduce(0, ^) else {
            Popai.log(
                "Expected payload sum: \(sum), got \(payload.utf8.reduce(0, ^))"
            )
            throw ProcessingError.invalidChecksum
        }

        switch format {
        case Format.conventional:
            try processConventionalSentencePayload(payload)
        case Format.encapsulated:
            try processEncapsulatedSentencePayload(payload)
        }
    }

    private func processConventionalSentencePayload(_ payload: Substring)
        throws
    {
        let fields = payload.split(
            separator: ",", omittingEmptySubsequences: false)

        guard
            let talker = fields.first?.prefix(2),
            let type = fields.first?.dropFirst(2),
            talker.count == 2 && type.count == 3
        else {
            throw ProcessingError.malformedTag
        }

        if let fn = recognizedTypes[String(type)] {
            fn(fields.dropFirst(), &self.state)
        } else if unrecognizedTypes.insert(String(type)).inserted {
            Popai.log("Unrecognized sentence: \(payload)")
        }
    }

    private func processEncapsulatedSentencePayload(_ payload: Substring)
        throws
    {
        let fields = payload.split(
            separator: ",", omittingEmptySubsequences: false)

        guard let marker = fields.first.map(String.init) else {
            throw ProcessingError.malformedTag
        }

        if let fn = recognizedTypes[marker] {
            fn(fields.dropFirst(), &self.state)
        } else if unrecognizedTypes.insert(marker).inserted {
            Popai.log("Unrecognized sentence: \(payload)")

        }
    }
}

// MARK: Message Handlers

private func ignore(_ fields: NMEA.Fields, _ state: inout NMEA.State) {}

private func processTransducerDepth(
    _ fields: NMEA.Fields, _ state: inout NMEA.State
) {
    guard fields.count == 6 else {
        Popai.log(
            "Expected six fields in transducer-depth sentence, but found \(fields.count)"
        )
        return
    }

    var feet: Feet? = nil
    var meters: Meters? = nil
    var fathoms: Fathoms? = nil

    for pair in stride(from: fields.startIndex, to: fields.endIndex, by: 2) {
        let measurement = fields[pair]
        let unit = fields[pair.advanced(by: 1)]

        guard let measurement = Double(measurement) else {
            Popai.log("Malformed measurement: \(measurement)")
            continue
        }

        switch unit {
        case "f":
            feet = Feet(measurement)
        case "M":
            meters = Meters(measurement)
        case "F":
            fathoms = Fathoms(measurement)
        default:
            Popai.log("Unrecognized transducer depth unit: \(unit)")
        }
    }

    switch (feet, meters, fathoms) {
    case let (feet?, meters?, fathoms?):
        state.draft = min(feet.inMeters, meters, fathoms.inMeters)
    case let (feet?, meters?, nil):
        state.draft = min(feet.inMeters, meters)
    case let (feet?, nil, fathoms?):
        state.draft = min(feet.inMeters, fathoms.inMeters)
    case let (feet?, nil, nil):
        state.draft = feet.inMeters
    case let (nil, meters?, fathoms?):
        state.draft = min(meters, fathoms.inMeters)
    case let (nil, meters?, nil):
        state.draft = meters
    case let (nil, nil, fathoms?):
        state.draft = fathoms.inMeters
    case (nil, nil, nil):
        Popai.log("No depth measurements found")
    }
}

private func processHeading(_ fields: NMEA.Fields, _ state: inout NMEA.State) {
    guard fields.count == 5 else {
        Popai.log(
            "Expected five fields in heading sentence, but found \(fields.count)"
        )
        return
    }

    func directionToMagnitude(_ dir: Substring) -> Double? {
        switch dir {
        case "E": 1
        case "W": -1
        case "": 0
        default: nil
        }
    }

    func magnitude(_ val: Substring) -> Double? {
        if val.isEmpty {
            0
        } else {
            Double(val)
        }
    }

    guard
        let sensor = Double(fields[fields.startIndex]),
        let deviation = magnitude(fields[fields.startIndex + 1]),
        let deviationDir = directionToMagnitude(fields[fields.startIndex + 2]),
        let variation = magnitude(fields[fields.startIndex + 3]),
        let variationDir = directionToMagnitude(fields[fields.startIndex + 4])
    else {
        Popai.log("Unable to read heading from \(fields)")
        return
    }

    let magnetic = sensor + deviation * deviationDir
    state.headingMagnetic = magnetic
    state.headingTrue = magnetic + variation * variationDir
}

private func processGeographicPosition(
    _ fields: NMEA.Fields, state: inout NMEA.State
) {
    guard fields.count == 7 else {
        Popai.log(
            "Expected seven fields in geographic position sentence, but found \(fields.count)"
        )
        return
    }

    func directionToSign(_ dir: Substring) -> Double? {
        switch dir {
        case "N": 1
        case "S": -1
        case "E": 1
        case "W": -1
        default: nil
        }
    }

    func statusIsValid(_ status: Substring) -> Bool? {
        switch status {
        case "A": true
        case "V": false
        default: nil
        }
    }

    let latitude = fields[fields.startIndex]
    let latitudeDirection = fields[fields.startIndex + 1]
    let longitude = fields[fields.startIndex + 2]
    let longitudeDirection = fields[fields.startIndex + 3]
    let status = fields[fields.startIndex + 5]

    guard
        let latitudeMagnitude = Double(latitude),
        let latitudeSign = directionToSign(latitudeDirection),
        let longitudeMagnitude = Double(longitude),
        let longitudeSign = directionToSign(longitudeDirection),
        let valid = statusIsValid(status)
    else {
        Popai.log("Failed to read geographic position from \(fields)")
        return
    }

    if valid {
        state.position = NMEA.Coordinates(
            latitude: latitudeMagnitude / 100 * latitudeSign,
            longitude: longitudeMagnitude / 100 * longitudeSign)
    }
}

func processAISMessage(_ fields: NMEA.Fields, state: inout NMEA.State) {
    guard fields.count == 6 else {
        Popai.log(
            "Expected six fields in AIS sentence, but found \(fields.count)"
        )
        return
    }

    if let entry = AIVDMDecoder.decode(fields) {
        if state.ais == nil {
            state.ais = NMEA.AIS()
        }

        var target =
            state.ais!.targets[entry.mmsi]
            ?? NMEA.AIS.TargetInfo(name: entry.shipName)
        target.updatedAt = Date.now

        if let name = entry.shipName {
            target.name = name
        }

        if let latitude = entry.latitude, let longitude = entry.longitude {
            target.position = NMEA.Coordinates(
                latitude: latitude, longitude: longitude)
        }

        state.ais!.targets[entry.mmsi] = target
    }
}

// MARK: AIVDMDecoder

class AIVDMDecoder {
    struct AISMessage {
        let messageType: UInt8
        let mmsi: NMEA.AIS.MMSI
        let navigationStatus: UInt8?
        let speedOverGround: Double?
        let longitude: Double?
        let latitude: Double?
        let courseOverGround: Double?
        let trueHeading: Int?
        let shipName: String?
        let callSign: String?
        let shipType: Int?
    }

    private static var messageBuffer: [Int: String] = [:]

    static func decode(_ fields: NMEA.Fields) -> AISMessage? {
        let totalFragments = Int(fields[fields.indices.startIndex + 0]) ?? 1
        let fragmentNumber = Int(fields[fields.indices.startIndex + 1]) ?? 1
        let messageId = Int(fields[fields.indices.startIndex + 2]) ?? 0
        let payload = fields[fields.indices.startIndex + 4]

        if totalFragments > 1 {
            messageBuffer[messageId, default: ""] += payload
            if fragmentNumber < totalFragments {
                return nil
            }
        } else {
            messageBuffer[messageId] = String(payload)
        }

        guard let fullPayload = messageBuffer[messageId] else { return nil }
        messageBuffer.removeValue(forKey: messageId)

        return decodePayload(fullPayload)
    }

    private static func decodePayload(_ payload: String) -> AISMessage? {
        guard let bitString = dearmor(payload) else {
            return nil
        }

        let messageType = UInt8(getInt(bitString, start: 0, length: 6))
        let mmsi = NMEA.AIS.MMSI(getUInt(bitString, start: 8, length: 30))

        var navigationStatus: UInt8? = nil
        var speedOverGround: Double? = nil
        var longitude: Double? = nil
        var latitude: Double? = nil
        var courseOverGround: Double? = nil
        var trueHeading: Int? = nil
        var shipName: String? = nil
        var callSign: String? = nil
        var shipType: Int? = nil

        if messageType == 1 || messageType == 2 || messageType == 3 {
            navigationStatus = UInt8(getUInt(bitString, start: 38, length: 4))
            speedOverGround =
                Double(getInt(bitString, start: 50, length: 10)) / 10.0
            longitude =
                Double(getInt(bitString, start: 61, length: 28)) / 600000.0
            latitude =
                Double(getInt(bitString, start: 89, length: 27))
                / 600000.0
            courseOverGround =
                Double(getInt(bitString, start: 116, length: 12)) / 10.0
            trueHeading = getInt(bitString, start: 128, length: 9)
        } else if messageType == 5 {
            shipName = getString(bitString, start: 112, length: 120)
            callSign = getString(bitString, start: 70, length: 42)
            shipType = getInt(bitString, start: 232, length: 8)
        } else if messageType == 24 {
            shipName = getString(bitString, start: 40, length: 120)
            shipType = getInt(bitString, start: 232, length: 8)
        }

        return AISMessage(
            messageType: messageType,
            mmsi: mmsi,
            navigationStatus: navigationStatus,
            speedOverGround: speedOverGround,
            longitude: longitude,
            latitude: latitude,
            courseOverGround: courseOverGround,
            trueHeading: trueHeading,
            shipName: shipName,
            callSign: callSign,
            shipType: shipType
        )
    }

    private static let asciiToBinary: [Character: String] = {
        let mapping =
            "0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVW`abcdefghijklmnopqrstuvw"

        return Dictionary(
            uniqueKeysWithValues: mapping.enumerated().map { (index, char) in
                let nibble = String(index, radix: 2)
                return (
                    char,
                    String(repeating: "0", count: max(0, 6 - nibble.count))
                        + nibble
                )
            })
    }()

    private static func dearmor(_ payload: String) -> String? {
        return payload.reduce(into: Optional("")) { result, char in
            guard let bits = asciiToBinary[char] else {
                result = nil
                return
            }
            result?.append(bits)
        }
    }

    private static func getInt(_ bitString: String, start: Int, length: Int)
        -> Int
    {
        guard start + length <= bitString.count else { return 0 }
        let unsigned = getUInt(bitString, start: start, length: length)

        return unsigned >= (1 << (length - 1))
            ? Int(unsigned) - (1 << length) : Int(unsigned)
    }

    private static func getUInt(_ bitString: String, start: Int, length: Int)
        -> UInt
    {
        guard start + length <= bitString.count else { return 0 }
        return UInt(bitString.dropFirst(start).prefix(length), radix: 2) ?? 0
    }

    private static func getString(
        _ bitString: String, start: Int, length: Int
    ) -> String {
        guard start + length <= bitString.count else { return "" }

        let extractedBits = bitString.dropFirst(start).prefix(length)
        let sixBitChunks = String(extractedBits).chunked(into: 6)
        let str = sixBitChunks.compactMap { chunk -> String? in
            guard let value = Int(chunk, radix: 2) else { return nil }
            let decodedValue: UInt8

            if value < 32 {
                decodedValue = UInt8(value) + Character("@").asciiValue!  // Maps to "@" (ASCII 64) through "_" (ASCII 95)
            } else {
                decodedValue = UInt8(value)  // Maps to " " (ASCII 32) through "?" (ASCII 63)
            }

            return String(UnicodeScalar(decodedValue))
        }.joined()

        return String(str.split(separator: "@").first!)
            .trimmingCharacters(in: .whitespaces)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: self.count, by: size).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end =
                self.index(start, offsetBy: size, limitedBy: self.endIndex)
                ?? self.endIndex
            return String(self[start..<end])
        }
    }
}
