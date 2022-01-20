// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

/// String key returned with a logger signal for a module by the C++ library.
/// Subscripts can indicate a particular aspect (e.g., which thermistor),
/// a custom slice into a Cartesian float, or other more advanced operations.
///
/// You can use .custom and customDownloads to capture custom logger signals
/// into Swift types during a download or stream.
///
public enum MWNamedSignal: Equatable, Hashable, Identifiable {
    case acceleration
    case altitude
    case ambientLight
    case chargingStatus
    case eulerAngles
    case gravity
    case gyroscope
    case humidity
    case linearAcceleration
    case magnetometer
    case mechanicalButton
    case motion
    case orientation
    case pressure
    case quaternion
    case steps
    case temperature
    case custom(String)

    public var name: String {
        switch self {
            case .acceleration:             return "acceleration"
            case .altitude:                 return "altitude"
            case .ambientLight:             return "illuminance"
            case .chargingStatus:           return "charge-status"
            case .eulerAngles:              return "euler-angles"
            case .gravity:                  return "gravity"
            case .gyroscope:                return "angular-velocity"
            case .humidity:                 return "relative-humidity"
            case .linearAcceleration:       return "linear-acceleration"
            case .magnetometer:             return "magnetic-field"
            case .mechanicalButton:         return "switch"
            case .motion:                   return "bosch-motion"
            case .pressure:                 return "pressure"
            case .quaternion:               return "quaternion"
            case .orientation:              return "orientation"
            case .temperature:              return "temperature"
            case .steps:
#warning("The step counter and detector sensors can currently be streamed, but have a bug when logging them. Fix forthcoming.")
                print("MetaWear Combine SDK Beta: Steps logging has bugs.")
                return "steps"
            case .custom(let string):       return string
        }
    }

    public static let allCases: [MWNamedSignal] = [
        .acceleration,
        .altitude,
        .ambientLight,
        .chargingStatus,
        .eulerAngles,
        .gravity,
        .gyroscope,
        .humidity,
        .linearAcceleration,
        .magnetometer,
        .mechanicalButton,
        .motion,
        .orientation,
        .pressure,
        .quaternion,
        .steps,
        .temperature
    ]

    public var id: String { name }

    public init(identifier: String) {

        // Remove up temperature and [1] index shortcuts
        var isolatedName = String(identifier.prefix { !"[:".contains($0) })
        Self.removeTemperatureSuffix(&isolatedName)

        var signal: MWNamedSignal? = nil

        if (isolatedName.endIndex == identifier.endIndex || isolatedName == "temperature") && identifier.isEmpty == false {
            signal = Self.allCases.first(where: { $0.name == isolatedName })

        } else if identifier.isEmpty && Self.customDownloads[""] == nil {
            // Workaround
            signal = .steps

        } else if Self.customDownloads.keys.contains(identifier) {
            signal = .custom(identifier)

        } else { fatalError("customDownloads id not set for \(identifier)") }

        self = signal!
    }

    /// Removes source type and any other labeling (e.g., temperature[1]:account?id=0)
    private static func removeTemperatureSuffix(_ isolatedName: inout String) {
        guard isolatedName.hasPrefix("temperature") else { return }
        isolatedName = "temperature"
    }
}

// MARK: - Support Downloading of Custom and Preset Types

public extension MWNamedSignal {

    /// Registry of custom loggables and functions to stop their logging and convert their raw data download into CSV-ready columns. For example, if you define a data processor chain, the `download` publisher will check here to correctly process its data according to your specifications.
    static var customDownloads: [String: MWNamedSignal.DownloadUtilities] = [:]

    var downloadUtilities: MWNamedSignal.DownloadUtilities {
        switch self {
            case .acceleration:       return .init(loggable: .accelerometer(rate: .hz100, gravity: .g16))
            case .altitude:           return .init(loggable: .absoluteAltitude(standby: .ms10, iir: .off, oversampling: .standard))
            case .ambientLight:       return .init(loggable: .ambientLight(rate: .ms1000, gain: .x1, integrationTime: .ms100))
            case .chargingStatus:     return .init(loggable: .chargingStatus)
            case .eulerAngles:        return .init(loggable: .sensorFusionEulerAngles(mode: .compass))
            case .gravity:            return .init(loggable: .sensorFusionGravity(mode: .compass))
            case .gyroscope:          return .init(loggable: .gyroscope(rate: .hz100, range: .dps1000))
            case .humidity:           return .init(pollable: .humidity())
            case .linearAcceleration: return .init(loggable: .sensorFusionLinearAcceleration(mode: .compass))
            case .magnetometer:       return .init(loggable: .magnetometer(rate: .hz10))
            case .mechanicalButton:   return .init(loggable: .mechanicalButton)
            case .motion: fatalError("C++ library is being rewritten to support logging.")
//                return .init(loggable: .motionActivityClassification)
            case .orientation:        return .init(loggable: .orientation)
            case .pressure:           return .init(loggable: .relativePressure(standby: .ms10, iir: .off, oversampling: .standard))
            case .quaternion:         return .init(loggable: .sensorFusionQuaternion(mode: .compass))
            case .steps:              return .init(loggable: .stepDetector(sensitivity: .normal))
            case .temperature:        return .init(pollable: MWThermometer(rate: .hz1, type: .onboard, channel: 0))
            case .custom(let id):     return Self.customDownloads[id]!
        }
    }

}

public extension MWNamedSignal {

    struct DownloadUtilities {
        public let columnHeadings: [String]
        public let stopModule: (MWBoard) -> Void
        public let convertRawDataToCSVColumns: ([MWData]) -> [[String]]

        public init(columnHeadings: [String],
                    stopModuleCommands: @escaping (MWBoard) -> Void,
                    convertRawDataToCSVColumns: @escaping ([MWData]) -> [[String]]) {
            self.stopModule = stopModuleCommands
            self.convertRawDataToCSVColumns = convertRawDataToCSVColumns
            self.columnHeadings = columnHeadings
        }

        public init<L: MWLoggable>(loggable: L) {
            self.columnHeadings = loggable.columnHeadings
            self.stopModule = loggable.loggerCleanup
            self.convertRawDataToCSVColumns = { $0.map(loggable.convertRawToColumns) }
        }

        public init<P: MWPollable>(pollable: P) {
            self.columnHeadings = pollable.columnHeadings
            self.stopModule = pollable.readCleanup
            self.convertRawDataToCSVColumns = { $0.map(pollable.convertRawToColumns) }
        }
    }

}

// MARK: - Conflicting Sensor Utilities

public extension MWNamedSignal {

    var isSensorFusion: Bool { Self.allSensorFusion.contains(self) }

    static let allSensorFusion: [MWNamedSignal] = [.eulerAngles, .gravity, .quaternion, .linearAcceleration]

    /// Cannot be streamed or logged at the same time.
    var conflictsWithSensorFusion: Bool { Self.allSensorFusionConflicts.contains(self) }

    /// Cannot be streamed or logged at the same time as these sensors' outputs are being fused together.
    static let allSensorFusionConflicts: [MWNamedSignal] = [.gyroscope, .acceleration, .magnetometer]

}

public extension Set where Element == MWNamedSignal {

    mutating func removeConflicts(for sensor: MWNamedSignal) {
        if sensor.isSensorFusion {
            removeAllSensorFusion()
            removeAllConflictsWithSensorFusion()
        } else if sensor.conflictsWithSensorFusion {
            removeAllSensorFusion()
        }
    }

    mutating func removeAllConflictsWithSensorFusion() {
        MWNamedSignal.allSensorFusionConflicts.forEach {
            self.remove($0)
        }
    }

    mutating func removeAllSensorFusion()  {
        MWNamedSignal.allSensorFusion.forEach {
            self.remove($0)
        }
    }
}
