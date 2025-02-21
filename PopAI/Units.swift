struct Fathoms {
    var value: Double

    var inMeters: Meters {
        Feet(value * 6).inMeters
    }

    init(_ value: Double) {
        self.value = value
    }
}

struct Feet {
    var value: Double

    var inMeters: Meters {
        Meters(value * 0.3048)
    }

    var feet: Int {
        Int(value)
    }

    var inches: Int {
        Int((value - Double(feet)) * 12)
    }

    init(_ value: Double) {
        self.value = value
    }
}

struct Meters: Comparable {
    var value: Double

    var inFeet: Feet {
        Feet(value * 3.281)
    }

    static func < (lhs: Meters, rhs: Meters) -> Bool {
        lhs.value < rhs.value
    }

    init(_ value: Double) {
        self.value = value
    }
}
