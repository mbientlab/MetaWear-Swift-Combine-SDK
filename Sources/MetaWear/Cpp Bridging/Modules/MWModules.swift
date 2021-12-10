// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

/// - Tip: Use the `id` property as a dictionary key that ignores associated values.
///
public enum MWModules: Equatable, Identifiable {

    case accelerometer(MWAccelerometer.Model)
    case barometer(MWBarometer.Model)
    case color
    case gyroscope(MWGyroscope.Model)
    case humidity
    case illuminance
    case magnetometer
    case proximity
    case sensorFusion
    case thermometer([MWThermometer.Source])

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

        if let _ = lookup(in: board, MBL_MW_MODULE_MAGNETOMETER) {
            detected[.magnetometer] = .magnetometer
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_HUMIDITY) {
            detected[.humidity] = .humidity
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_AMBIENT_LIGHT) {
            detected[.illuminance] = .illuminance
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_COLOR_DETECTOR) {
            detected[.color] = .color
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_PROXIMITY) {
            detected[.proximity] = .proximity
        }

        let sources = MWThermometer.Source.availableChannels(on: board)
        if sources.isEmpty == false {
            detected[.thermometer] = .thermometer(sources)
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_SENSOR_FUSION) {
                detected[.sensorFusion] = .sensorFusion
        }

        return detected
    }

    public static func lookup(in board: MWBoard, _ module: MblMwModule) -> Int32? {
        let result = mbl_mw_metawearboard_lookup_module(board, module)
        return result == NA ? nil : result
    }

    /// Not available
    public static let NA = MBL_MW_MODULE_TYPE_NA

    /// Use for creating a dictionary keyed regardless of associated values.
    public enum ID: Int, Equatable, Hashable, IdentifiableByRawValue, CaseIterable {
        case accelerometer
        case barometer
        case color
        case gyroscope
        case humidity
        case illuminance
        case magnetometer
        case proximity
        case sensorFusion
        case thermometer
    }

    /// Use for creating a dictionary keyed regardless of associated values.
    public var id: ID {
        switch self {
            case .accelerometer: return .accelerometer
            case .barometer: return .barometer
            case .color: return .color
            case .gyroscope: return .gyroscope
            case .humidity: return .humidity
            case .illuminance: return .illuminance
            case .magnetometer: return .magnetometer
            case .proximity: return .proximity
            case .sensorFusion: return .sensorFusion
            case .thermometer: return .thermometer
        }
    }
}
