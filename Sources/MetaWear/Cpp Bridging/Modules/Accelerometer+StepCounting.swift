// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWStepCounter_BMI270 {
    /// Tracks step counts, reporting the current count every ~20 steps
    public static var stepCounter_BMI270: Self { Self() }
}

extension MWLoggable where Self == MWStepCounter_BMI270 {
    /// Tracks step counts, reporting the current count every ~20 steps
    public static var stepCounter_BMI270: Self { Self() }
}

extension MWPollable where Self == MWStepCounter_BMI160 {
    /// Tracks step counts, reporting the current count every ~20 steps
    public static func stepCounter_BMI160(rate: MWFrequency, sensitivity: MWAccelerometer.StepCounterSensitivity) -> Self {
        Self(sensitivity: sensitivity, pollingRate: rate)
    }
}


// MARK: - Signals

/// Emits steps detected in 20 step intervals.
///
/// - Important: Use the presets marked for your MetaWear's accelerometer model. MetaMotion S has a BMI270, while the RL and older have a BMI 160. Bosch changed the sensor design substantially, which the SDK must handle differently.
///
/// BMI270
///  - Can stream and log normally
///  - Cannot "poll"
///
/// BMI160
///  - Cannot stream and log normally
///  - Can "poll" to stream/log (implemented using a timer)
///
public struct MWStepCounter_BMI160: MWReadable, MWPollable {

    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .custom("")
    public let columnHeadings = ["Epoch", "Steps"]
    public var pollingRate: MWFrequency

    public var sensitivity: MWAccelerometer.StepCounterSensitivity


    public init(sensitivity: MWAccelerometer.StepCounterSensitivity, pollingRate: MWFrequency = .every30sec) {
        self.sensitivity = sensitivity
        self.pollingRate = pollingRate
    }
}

/// Emits steps detected in 20 step intervals.
///
/// - Important: Use the presets marked for your MetaWear's accelerometer model. MetaMotion S has a BMI270, while the RL and older have a BMI 160. Bosch changed the sensor design substantially, which the SDK must handle differently.
///
/// BMI270
///  - Can stream and log normally
///  - Cannot "poll" or "read once"
///
/// BMI160
///  - Cannot stream and log normally
///  - Can "poll" to stream/log (implemented using a timer) and "read once" for a total since the last read
///
public struct MWStepCounter_BMI270: MWStreamable, MWLoggable {

    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .steps
    public let columnHeadings = ["Epoch", "Steps"]

    public init() { }
}


// MARK: - Signal Implementations

public extension MWStepCounter_BMI160 {

    func readConfigure(board: MWBoard) {
        guard case .bmi160 = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometerForStepping(board)
        mbl_mw_acc_bmi160_enable_step_counter(board)
        mbl_mw_acc_bmi160_set_step_counter_mode(board, sensitivity.cppEnumValue)
        // No 20-step trigger config method
        mbl_mw_acc_bmi160_write_step_counter_config(board)
        mbl_mw_acc_bmi160_reset_step_counter(board)
    }

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        guard case .bmi160 = MWAccelerometer.Model(board: board) else {
            throw MWError.operationFailed("This preset is specific to the BMI160. If you have a MetaMotion S, use the BMI270 preset instead.")
        }
        return mbl_mw_acc_bmi160_get_step_counter_data_signal(board)
    }

    func readCleanup(board: MWBoard) {
        mbl_mw_acc_bmi160_reset_step_counter(board)
        mbl_mw_acc_bmi160_disable_step_counter(board)
        mbl_mw_acc_stop(board)
    }
}

public extension MWStepCounter_BMI270 {

    func streamConfigure(board: MWBoard) {
        guard case .bmi270 = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometerForStepping(board)
        // No sensitivity adjustment
        mbl_mw_acc_bmi270_set_step_counter_trigger(board, 1) //every 20 steps
        mbl_mw_acc_bmi270_write_step_counter_config(board)
        mbl_mw_acc_bmi270_reset_step_counter(board)
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard case .bmi270 = MWAccelerometer.Model(board: board) else {
            throw MWError.operationFailed("Accelerometer invalid for streaming or logging step counting. Use the BMI160 preset instead.")
        }
        return mbl_mw_acc_bmi270_get_step_counter_data_signal(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_acc_bmi270_enable_step_counter(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_bmi270_reset_step_counter(board)
        mbl_mw_acc_bmi270_disable_step_counter(board)
        mbl_mw_acc_stop(board)
    }
}

// MARK: - Shared setup method

fileprivate func configureAccelerometerForStepping(_ board: MWBoard) {
    mbl_mw_acc_start(board)
    mbl_mw_acc_set_range(board, 8.0) // Max range in gs
    mbl_mw_acc_set_odr(board, 100) // Must be at least 25 Hz
    mbl_mw_acc_write_acceleration_config(board)
}

// MARK: - C++ Constants

extension MWAccelerometer {

    /// Step sensitivity available on BMI160 (e.g., MetaMotion RL devices only)
    public enum StepCounterSensitivity: String, CaseIterable, IdentifiableByRawValue {

        /// Balanced between false positives and false negatives, recommended for most applications
        case normal
        /// Few false negatives but eventually more false positives, recommended for light weighted people
        case sensitive
        // Few false positives but eventually more false negatives
        case robust

        /// Raw Cpp constant
        public var cppEnumValue: MblMwAccBmi160StepCounterMode {
            switch self {
                case .normal:    return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_NORMAL
                case .sensitive: return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_SENSITIVE
                case .robust:    return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_ROBUST
            }
        }

        /// Returns a sensitivity valid for use on this model. (Setting is available only on the BMI160.)
        public func supported(by accelerometer: Model) -> StepCounterSensitivity? {
            guard accelerometer == .bmi160 else { return nil }
            return self
        }
    }

}
