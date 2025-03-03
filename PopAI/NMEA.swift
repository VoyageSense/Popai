import Foundation

class NMEA: ObservableObject {
    struct State {
        var draft: Meters?
        var headingMagnetic: Double?
        var headingTrue: Double?
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
    ])

    private let recognizedTypes:
        [String: (ArraySlice<Substring>, inout NMEA.State) -> Void]
    private var unrecognizedTypes: Set<String> = Set()

    init(state: State = State(), log: Log = Log()) {
        self.state = state
        self.log = log
        self.recognizedTypes = [
            "DBT": processTransducerDepth,
            "HDG": processHeading,
            "HDM": ignore,
            "HDT": ignore,
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
            PopAI.log(
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
            PopAI.log("Unrecognized sentence: \(payload)")
        }
    }

    private func processEncapsulatedSentencePayload(_ payload: Substring)
        throws
    {

    }
}

private func ignore(
    _ fields: ArraySlice<Substring>, _ state: inout NMEA.State
) {}

private func processTransducerDepth(
    _ fields: ArraySlice<Substring>, _ state: inout NMEA.State
) {
    guard fields.count == 6 else {
        PopAI.log(
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
            PopAI.log("Malformed measurement: \(measurement)")
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
            PopAI.log("Unrecognized transducer depth unit: \(unit)")
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
        PopAI.log("No depth measurements found")
    }
}

private func processHeading(
    _ fields: ArraySlice<Substring>, _ state: inout NMEA.State
) {
    guard fields.count == 5 else {
        PopAI.log(
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
        PopAI.log("Unable to read heading from \(fields)")
        return
    }

    let magnetic = sensor + deviation * deviationDir
    state.headingMagnetic = magnetic
    state.headingTrue = magnetic + variation * variationDir
}
