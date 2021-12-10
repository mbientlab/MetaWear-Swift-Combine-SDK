// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

/// Specify event frequencies in Hz or millisecond periods between events
///
public struct MWFrequency: Equatable, Hashable {

    // Events per second (Hz)
    public let rateHz: Double
    // Milliseconds between events
    public let periodMs: Int

    public init(hz: Double) {
        self.rateHz = hz
        self.periodMs = rateHz == 0 ? 0 : Int(1/rateHz * 1000)
    }

    public init(eventsPerMin: Double) {
        let hz = eventsPerMin / 60
        self.init(hz: hz)
    }

    public init(eventsPerHour: Double) {
        let min = eventsPerHour / 60
        self.init(eventsPerMin: min)
    }

    public init(eventsPerDay: Double) {
        let hr = eventsPerDay / 24
        self.init(eventsPerHour: hr)
    }

    public init(periodMs: Int) {
        self.periodMs = periodMs
        self.rateHz = periodMs == 0 ? 0 : (1000 / Double(periodMs))
    }

    public static let hz1 = CommonCases.hz1.freq
    public static let hz10 = CommonCases.hz10.freq
    public static let hz20 = CommonCases.hz20.freq
    public static let hz25 = CommonCases.hz25.freq
    public static let hz50 = CommonCases.hz50.freq
    public static let hz100 = CommonCases.hz100.freq
    public static let hz1000 = CommonCases.hz1000.freq
    public static let every5sec = CommonCases.every5sec.freq
    public static let every10sec = CommonCases.every10sec.freq
    public static let every20sec = CommonCases.every20sec.freq
    public static let every30sec = CommonCases.every30sec.freq
    public static let every1min = CommonCases.every1min.freq
    public static let every2min = CommonCases.every2min.freq
    public static let every5min = CommonCases.every5min.freq
    public static let every10min = CommonCases.every10min.freq
    public static let every15min = CommonCases.every15min.freq
    public static let every20min = CommonCases.every20min.freq
    public static let every30min = CommonCases.every30min.freq
    public static let every1hr = CommonCases.every1hr.freq
    public static let every2hr = CommonCases.every2hr.freq
    public static let every3hr = CommonCases.every3hr.freq
    public static let every4hr = CommonCases.every4hr.freq
    public static let every5hr = CommonCases.every5hr.freq
    public static let every6hr = CommonCases.every6hr.freq
    public static let every8hr = CommonCases.every8hr.freq
    public static let every12hr = CommonCases.every12hr.freq
    public static let every24hr = CommonCases.every24hr.freq

    public enum CommonCases: String, CaseIterable, IdentifiableByRawValue {
        case hz1
        case hz10
        case hz20
        case hz25
        case hz50
        case hz100
        case hz1000
        case every5sec
        case every10sec
        case every20sec
        case every30sec
        case every1min
        case every2min
        case every5min
        case every10min
        case every15min
        case every20min
        case every30min
        case every1hr
        case every2hr
        case every3hr
        case every4hr
        case every5hr
        case every6hr
        case every8hr
        case every12hr
        case every24hr

        /// Human-readable name
        public var label: String {
            var value = rawValue

            if value.hasPrefix("hz") {
                value.removeFirst(2)
                value.append(" Hz")

            } else if value.hasSuffix("sec") {
                value.removeFirst(5)
                value.removeLast(3)
                value = "Every \(value) sec"

            } else if value.hasSuffix("min") {
                value.removeFirst(5)
                value.removeLast(3)
                value = "Every \(value) min"

            } else if value.hasSuffix("hr") {
                value.removeFirst(5)
                value.removeLast(2)
                value = "Every \(value) hr"
            }
            return value
        }

        public var freq: MWFrequency {
            switch self {
                case .hz1: return .init(hz: 1)
                case .hz10: return .init(hz: 10)
                case .hz20: return .init(hz: 20)
                case .hz25: return .init(hz: 25)
                case .hz50: return .init(hz: 50)
                case .hz100: return .init(hz: 100)
                case .hz1000: return .init(hz: 1000)
                case .every5sec: return .init(eventsPerMin: 12)
                case .every10sec: return .init(eventsPerMin: 6)
                case .every20sec: return .init(eventsPerMin: 3)
                case .every30sec: return .init(eventsPerMin: 2)
                case .every1min: return .init(eventsPerMin: 1)
                case .every2min: return .init(eventsPerHour: 30)
                case .every5min: return .init(eventsPerHour: 12)
                case .every10min: return .init(eventsPerHour: 6)
                case .every15min: return .init(eventsPerHour: 4)
                case .every20min: return .init(eventsPerHour: 3)
                case .every30min: return .init(eventsPerHour: 2)
                case .every1hr: return .init(eventsPerHour: 1)
                case .every2hr: return .init(eventsPerDay: 12)
                case .every3hr: return .init(eventsPerDay: 8)
                case .every4hr: return .init(eventsPerDay: 6)
                case .every5hr: return .init(eventsPerDay: 4.8)
                case .every6hr: return .init(eventsPerDay: 4)
                case .every8hr: return .init(eventsPerDay: 3)
                case .every12hr: return .init(eventsPerDay: 2)
                case .every24hr: return .init(eventsPerDay: 1)
            }
        }
    }
}

extension MWFrequency: Comparable {
    public static func < (lhs: MWFrequency, rhs: MWFrequency) -> Bool {
        lhs.rateHz < rhs.rateHz
    }
}

extension MWFrequency: AdditiveArithmetic {
    public static func - (lhs: MWFrequency, rhs: MWFrequency) -> MWFrequency {
        .init(hz: lhs.rateHz - rhs.rateHz)
    }

    public static func + (lhs: MWFrequency, rhs: MWFrequency) -> MWFrequency {
        .init(hz: lhs.rateHz + rhs.rateHz)
    }

    public static var zero: MWFrequency {
        .init(hz: 0)
    }

    public static func * (lhs: MWFrequency, rhs: MWFrequency) -> MWFrequency {
        .init(hz: lhs.rateHz * rhs.rateHz)
    }
}
