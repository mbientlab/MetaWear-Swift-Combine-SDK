// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp


/// If you stop logging activity with the intent of downloading data hours later (using `.loggersPause()`, this command will turn off power hungry sensors.
///
/// If you pause and restart logging activity in a short period of time, it's not necessary to use this function. If you do, you need to call configuration and start methods for each specific sensor.
///
public struct MWPowerDownSensors: MWCommand {
    /// Turns off all sensors to save battery.
    public init() {}
    public func command(board: MWBoard) {


        mbl_mw_acc_stop(board)
        mbl_mw_sensor_fusion_stop(board)

        MWAccelerometer(rate: .hz100, gravity: .g16).loggerCleanup(board: board)
        MWGyroscope(rate: nil, range: nil).loggerCleanup(board: board)

        if let _ = MWModules.lookup(in: board, .magnetometer) {
            MWMagnetometer(freq: .hz10).loggerCleanup(board: board)
        }

        if let _ = MWModules.lookup(in: board, .illuminance) {
            MWAmbientLight(gain: nil, integrationTime: nil, rate: nil).loggerCleanup(board: board)
        }

        if let _ = MWModules.lookup(in: board, .barometer) {
            MWBarometer.MWAltitude().loggerCleanup(board: board)
        }

        if let _ = MWModules.lookup(in: board, .humidity) {
            MWHumidity(oversampling: .x1, rate: .hz10).pollCleanup(board: board)
        }
    }
}

// MARK: - Public Presets

public extension MWCommand where Self == MWPowerDownSensors {
    /// Turns off all sensors to save battery.
    static var powerDownSensors: Self { Self() }
}
