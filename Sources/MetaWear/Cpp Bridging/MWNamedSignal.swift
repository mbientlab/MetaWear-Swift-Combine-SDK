// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

/// String key returned with a logger signal for a module
///
public enum MWNamedSignal: Equatable, Hashable {
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
    case temperature(MWThermometer.Source)
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
            case .temperature(let source):  return "temperature\(source.loggerIndex)"
            case .custom(let string):       return string
            case .steps:                    return "steps"
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
        .temperature(.onboard),
        .temperature(.onDie),
        .temperature(.external),
        .temperature(.bmp280),
    ]

    public init(identifier: String) {
        print("-> Logger ", identifier)
        self = Self.allCases.first(where: { $0.name == identifier }) ?? .custom(identifier)
    }
}

// MARK: - Support Downloading of Custom and Preset Types

public extension MWNamedSignal {

    /// Registry of custom loggables and functions to stop their logging and convert their raw data download into CSV-ready columns. For example, if you define a data processor chain, the `download` publisher will check here to correctly process its data according to your specifications.
    static var customDownloads: [String: MWNamedSignal.DownloadUtilities] = [:]

    var downloadUtilities: MWNamedSignal.DownloadUtilities {
        switch self {
            case .acceleration: return .init(loggable: .accelerometer(rate: .hz100, gravity: .g16))
            case .altitude: return .init(loggable: .absoluteAltitude(standby: .ms10, iir: .off, oversampling: .standard))
            case .ambientLight: return .init(loggable: .ambientLight(rate: .ms1000, gain: .x1, integrationTime: .ms100))
            case .chargingStatus: return .init(loggable: .chargingStatus)
            case .eulerAngles: return .init(loggable: .sensorFusionEulerAngles(mode: .compass))
            case .gravity: return .init(loggable: .sensorFusionGravity(mode: .compass))
            case .gyroscope: return .init(loggable: .gyroscope(range: .dps1000, freq: .hz100))
            case .humidity: return .init(pollable: .humidity())
            case .linearAcceleration: return .init(loggable: .sensorFusionLinearAcceleration(mode: .compass))
            case .magnetometer: return .init(loggable: .magnetometer(freq: .hz10))
            case .mechanicalButton: return .init(loggable: .mechanicalButton)
            case .motion: fatalError("C++ library is being rewritten to support logging.")
//                return .init(loggable: .motionActivityClassification)
            case .orientation: return .init(loggable: .orientation)
            case .pressure: return .init(loggable: .relativePressure(standby: .ms10, iir: .off, oversampling: .standard))
            case .quaternion: return .init(loggable: .sensorFusionQuaternion(mode: .compass))
            case .steps: return .init(loggable: .stepDetector(sensitivity: .normal))
            case .temperature: return .init(pollable: MWThermometer(type: .onboard, channel: 0, rate: .hz1))
            case .custom(let id): return Self.customDownloads[id]!
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
