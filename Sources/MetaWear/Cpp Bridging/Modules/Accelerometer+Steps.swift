// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWStepDetector {
    /// Reports steps one by one (e.g., you can react to them or sum all the "1"s you receive)
    public static func stepDetector(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWStreamable where Self == MWStepCounter {
    /// Tracks step counts, reporting the current count every ~20 steps
    public static func stepCounter(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWLoggable where Self == MWStepDetector {
    /// Reports steps one by one (e.g., you can react to them or sum all the "1"s you receive)
    public static func stepDetector(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWLoggable where Self == MWStepCounter {
    /// Tracks step counts, reporting the current count every ~20 steps
    public static func stepCounter(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}


// MARK: - Signals

/// Requires counting steps by counting each closure returned as one step
public struct MWStepDetector: MWStreamable, MWLoggable {

    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .steps
    public let columnHeadings = ["Epoch", "Step"]

    /// Sensitivity available on BMI160 (e.g., MetaMotion RL devices only)
    public var sensitivity: MWAccelerometer.StepCounterSensitivity? = nil
    public var needsConfiguration: Bool { sensitivity != nil }

    /// Sensitivity available on BMI160 (e.g., MetaMotion RL devices only)
    public init(sensitivity: MWAccelerometer.StepCounterSensitivity?) {
        self.sensitivity = sensitivity
    }

    /// C callback returns zero, but more logical/convenient to return "1" for "1 step occurred"
    public func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, 1)
    }

}

/// Reports steps detected in ~20 step intervals.
public struct MWStepCounter: MWStreamable, MWLoggable {

    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .steps
    public let columnHeadings = ["Epoch", "Steps"]

    /// Sensitivity available on BMI160 (e.g., MetaMotion RL devices only)
    public var sensitivity: MWAccelerometer.StepCounterSensitivity? = nil
    public var needsConfiguration: Bool { sensitivity != nil }

    /// Sensitivity available on BMI160 (e.g., MetaMotion RL devices only)
    public init(sensitivity: MWAccelerometer.StepCounterSensitivity?) {
        self.sensitivity = sensitivity
    }
}


// MARK: - Signal Implementations

public extension MWStepDetector {

    func streamConfigure(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometerForStepping(board)
        guard case .bmi160 = model else { return }
        mbl_mw_acc_bmi160_set_step_counter_mode(board, (sensitivity ?? .normal).cppEnumValue)
        mbl_mw_acc_bmi160_write_step_counter_config(board)
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard let model = MWAccelerometer.Model(board: board) else {
            throw MWError.operationFailed("Accelerometer invalid for step detection.")
        }
        switch model {
            case .bmi160: return mbl_mw_acc_bmi160_get_step_detector_data_signal(board)
            case .bmi270: return mbl_mw_acc_bmi270_get_step_detector_data_signal(board)
            case .bma255: throw MWError.operationFailed("Accelerometer invalid for step detection.")
        }
    }

    func streamStart(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_enable_step_detector(board)
            case .bmi270: mbl_mw_acc_bmi270_enable_step_detector(board)
            default: return
        }
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_disable_step_detector(board)
            case .bmi270: mbl_mw_acc_bmi270_disable_step_detector(board)
            default: return
        }
    }
}

public extension MWStepCounter {

    func streamConfigure(board: MWBoard) {
        configureAccelerometerForStepping(board)
        switch MWAccelerometer.Model(board: board) {
            case .bmi160:
                mbl_mw_acc_bmi160_set_step_counter_mode(board, (sensitivity ?? .normal).cppEnumValue)
                // No 20-step trigger config method
                mbl_mw_acc_bmi160_write_step_counter_config(board)
                mbl_mw_acc_bmi160_reset_step_counter(board)

            case .bmi270:
                // No sensitivity adjustment
                mbl_mw_acc_bmi270_set_step_counter_trigger(board, 1) //every 20 steps
                mbl_mw_acc_bmi270_write_step_counter_config(board)
                mbl_mw_acc_bmi270_reset_step_counter(board)


            default: return
        }
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard let model = MWAccelerometer.Model(board: board) else {
            throw MWError.operationFailed("Accelerometer invalid for step counting.")
        }
        switch model {
            case .bmi160: return mbl_mw_acc_bmi160_get_step_counter_data_signal(board)
            case .bmi270: return mbl_mw_acc_bmi270_get_step_counter_data_signal(board)
            case .bma255: throw MWError.operationFailed("Accelerometer invalid for step counting.")
        }
    }

    func streamStart(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_enable_step_counter(board)
            case .bmi270: mbl_mw_acc_bmi270_enable_step_counter(board)
            default: return
        }
    }

    func streamCleanup(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160:
                mbl_mw_acc_bmi160_reset_step_counter(board)
                mbl_mw_acc_bmi160_disable_step_counter(board)
            case .bmi270:
                mbl_mw_acc_bmi270_reset_step_counter(board)
                mbl_mw_acc_bmi270_disable_step_counter(board)
            default: return
        }
        mbl_mw_acc_stop(board)
    }
}

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
        case normal
        case sensitive
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
