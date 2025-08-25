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
