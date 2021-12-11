// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

/// String key returned with a logger signal for a module
///
public enum MWNamedSignal: Equatable, Hashable {
    case custom(String)
    case acceleration
    case altitude
    case ambientLight
    case eulerAngles
    case gravity
    case gyroscope
    case humidity
    case linearAcceleration
    case magnetometer
    case orientation
    case pressure
    case quaternion
    case steps
    case temperature

    public var name: String {
        switch self {
            case .acceleration: return "acceleration"
            case .altitude: return "altitude"
            case .ambientLight: return "ambient-light"
            case .eulerAngles: return "euler-angles"
            case .gravity: return "gravity"
            case .gyroscope: return "angular-velocity"
            case .humidity: return "relative-humidity"
            case .linearAcceleration: return "linear-acceleration"
            case .magnetometer: return "magnetic-field"
            case .pressure: return "pressure"
            case .quaternion: return "quaternion"
            case .custom(let string): return string
            case .orientation: return "orientation"
            case .steps: return "steps"
            case .temperature: return "temperature"
        }
    }

    public static let allCases: [MWNamedSignal] = [
        .acceleration,
        .altitude,
        .ambientLight,
        .eulerAngles,
        .gravity,
        .gyroscope,
        .humidity,
        .linearAcceleration,
        .magnetometer,
        .orientation,
        .pressure,
        .quaternion,
        .steps
    ]

    public init(identifier: String) {
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
            case .orientation: return .init(loggable: .orientation)  // Does orientation have any logging issues? Check MetaBase.
//            case .steps: return .init(loggable: .steps)
//            case .pressure: return .init(loggable: .relativeAltitude)
//            case .altitude: return .init(loggable: .absoluteAltitude)
            case .gyroscope: return .init(loggable: .gyroscope(range: .dps1000, freq: .hz100))
            case .magnetometer: return .init(loggable: .magnetometer(freq: .hz10))
            case .humidity: return .init(pollable: .humidity())
            case .eulerAngles: return .init(loggable: .sensorFusionEulerAngles(mode: .compass))
            case .gravity: return .init(loggable: .sensorFusionGravity(mode: .compass))
            case .quaternion: return .init(loggable: .sensorFusionQuaternion(mode: .compass))
            case .linearAcceleration: return .init(loggable: .sensorFusionLinearAcceleration(mode: .compass))
            case .temperature: return .init(pollable: MWThermometer(type: .onboard, channel: 0, rate: .hz1))
            case .custom(let id): return Self.customDownloads[id]!
            default: fatalError()
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
