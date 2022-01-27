// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

/// - Tip: Use the `id` property as a dictionary key that ignores associated values.
///
/// - Warning: Do not depend on `Codable` conformance for persistence.
///            Use for in-memory drag and drop only.
///
public enum MWModules: Equatable, Identifiable, Codable {

    case accelerometer(MWAccelerometer.Model)
    case barometer(MWBarometer.Model)
    case gyroscope(MWGyroscope.Model)
    case humidity
    case illuminance
    case magnetometer
    case sensorFusion
    case thermometer([MWThermometer.Source])

    case mechanicalSwitch
    case led
    case gpio
    case iBeacon
    case haptic
    case i2c

    /// - Tip: Use the `id` property as a dictionary key that ignores associated values.
    ///
    public static func detect(in board: MWBoard) -> [MWModules.ID:MWModules] {
        var detected = [MWModules.ID:MWModules]()

        if let model = MWBarometer.Model(board: board) {
            detected[.barometer] = .barometer(model)
        }

        if let model = MWAccelerometer.Model(board: board) {
            detected[.accelerometer] = .accelerometer(model)
        }

        if let model = MWGyroscope.Model(board: board) {
            detected[.gyroscope] = gyroscope(model)
        }

        if let _ = lookup(in: board, .magnetometer) {
            detected[.magnetometer] = .magnetometer
        }

        if let _ = lookup(in: board, .humidity) {
            detected[.humidity] = .humidity
        }

        if let _ = lookup(in: board, .illuminance) {
            detected[.illuminance] = .illuminance
        }

        let sources = MWThermometer.Source.availableChannels(on: board)
        if sources.isEmpty == false {
            detected[.thermometer] = .thermometer(sources)
        }

        if let _ = lookup(in: board, .sensorFusion) {
                detected[.sensorFusion] = .sensorFusion
        }

        if let _ = lookup(in: board, .mechanicalSwitch) {
            detected[.mechanicalSwitch] = .mechanicalSwitch
        }

        if let _ = lookup(in: board, .led) {
            detected[.led] = .led
        }

        if let _ = lookup(in: board, .gpio) {
            detected[.gpio] = .gpio
        }

        if let _ = lookup(in: board, .iBeacon) {
            detected[.iBeacon] = .iBeacon
        }

        if let _ = lookup(in: board, .haptic) {
            detected[.haptic] = .haptic
        }

        if let _ = lookup(in: board, .i2c) {
            detected[.i2c] = .i2c
        }

        return detected
    }

    public static func lookup(in board: MWBoard, _ module: ID) -> Int32? {
        let result = mbl_mw_metawearboard_lookup_module(board, module.cppValue)
        return result == NA ? nil : result
    }

    /// Not available
    public static let NA = MBL_MW_MODULE_TYPE_NA

    /// Use for creating a dictionary keyed regardless of associated values.
    ///
    /// - Warning: Do not depend on `Codable` conformance for persistence.
    ///            Use for in-memory drag and drop only.
    ///
    public enum ID: String, Equatable, Hashable, IdentifiableByRawValue, CaseIterable, Codable {
        case accelerometer
        case barometer
        case gyroscope
        case humidity
        case illuminance
        case magnetometer
        case sensorFusion
        case thermometer

        case mechanicalSwitch
        case led
        case gpio
        case iBeacon
        case haptic
        case i2c

        public var cppValue: MblMwModule {
            switch self {
                case .accelerometer: return MBL_MW_MODULE_ACCELEROMETER
                case .barometer: return MBL_MW_MODULE_BAROMETER
                case .gyroscope: return MBL_MW_MODULE_GYRO
                case .humidity: return MBL_MW_MODULE_HUMIDITY
                case .illuminance: return MBL_MW_MODULE_AMBIENT_LIGHT
                case .magnetometer: return MBL_MW_MODULE_MAGNETOMETER
                case .sensorFusion: return MBL_MW_MODULE_SENSOR_FUSION
                case .thermometer: return MBL_MW_MODULE_TEMPERATURE
                case .mechanicalSwitch: return MBL_MW_MODULE_SWITCH
                case .led: return MBL_MW_MODULE_LED
                case .gpio: return MBL_MW_MODULE_GPIO
                case .iBeacon: return MBL_MW_MODULE_IBEACON
                case .haptic: return MBL_MW_MODULE_HAPTIC
                case .i2c: return MBL_MW_MODULE_I2C
            }
        }
    }

    /// Use for creating a dictionary keyed regardless of associated values.
    public var id: ID {
        switch self {
            case .accelerometer: return .accelerometer
            case .barometer: return .barometer
            case .gyroscope: return .gyroscope
            case .humidity: return .humidity
            case .illuminance: return .illuminance
            case .magnetometer: return .magnetometer
            case .sensorFusion: return .sensorFusion
            case .thermometer: return .thermometer

            case .mechanicalSwitch: return .mechanicalSwitch
            case .led: return .led
            case .gpio: return .gpio
            case .iBeacon: return .iBeacon
            case .haptic: return .haptic
            case .i2c: return .i2c
        }
    }

    public var cppValue: MblMwModule { self.id.cppValue }
}
