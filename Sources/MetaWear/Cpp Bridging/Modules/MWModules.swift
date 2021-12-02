// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

public enum MWModules: Hashable {

    case barometer(MWBarometer.Model)
    case accelerometer(MWAccelerometer.Model)
    case gyroscope(MWGyroscope.Model)
    case magnetometer
    case humidity
    case illuminance
    case color
    case proximity
    case thermometer([MWThermometer.Source])
    case sensorFusion

    public static func detect(in board: MWBoard) -> Set<MWModules> {
        var detected = Set<MWModules>()

        if let model = MWBarometer.Model(board: board) {
            detected.insert(.barometer(model))
        }

        if let model = MWAccelerometer.Model(board: board) {
            detected.insert(.accelerometer(model))
        }

        if let model = MWGyroscope.Model(board: board) {
            detected.insert(gyroscope(model))
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_MAGNETOMETER) {
            detected.insert(.magnetometer)
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_HUMIDITY) {
            detected.insert(.humidity)
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_AMBIENT_LIGHT) {
            detected.insert(.illuminance)
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_COLOR_DETECTOR) {
            detected.insert(.color)
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_PROXIMITY) {
            detected.insert(.proximity)
        }

        let sources = MWThermometer.Source.availableChannels(on: board)
        if sources.isEmpty == false {
            detected.insert(.thermometer(sources))
        }

        if let _ = lookup(in: board, MBL_MW_MODULE_SENSOR_FUSION) {
            detected.insert(.sensorFusion)
        }

        return detected
    }

    public static func lookup(in board: MWBoard, _ module: MblMwModule) -> Int32? {
        let result = mbl_mw_metawearboard_lookup_module(board, module)
        return result == NA ? nil : result
    }

    /// Not available
    public static let NA = MBL_MW_MODULE_TYPE_NA
}
