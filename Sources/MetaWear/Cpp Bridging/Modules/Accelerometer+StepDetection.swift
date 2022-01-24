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

extension MWLoggable where Self == MWStepDetector {
    /// Reports steps one by one (e.g., you can react to them or sum all the "1"s you receive)
    public static func stepDetector(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}


// MARK: - Signals

/// Emits each time a step is detected, leaving summation to you.
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


// MARK: - Signal Implementations

public extension MWStepDetector {

    func streamConfigure(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometerForStepping(board)
        guard case .bmi160 = model else { return }
        print("-> mbl_mw_acc_bmi160_set_step_counter_mode", #function)
        mbl_mw_acc_bmi160_set_step_counter_mode(board, (sensitivity ?? .normal).cppEnumValue)
        print("-> mbl_mw_acc_bmi160_write_step_counter_config", #function)
        mbl_mw_acc_bmi160_write_step_counter_config(board)
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard let model = MWAccelerometer.Model(board: board) else {
            throw MWError.operationFailed("Accelerometer invalid for step detection.")
        }
        print("-> mbl_mw_acc_bmiXXX_get_step_detector_data_signal", #function)
        switch model {
            case .bmi160: return mbl_mw_acc_bmi160_get_step_detector_data_signal(board)
            case .bmi270: return mbl_mw_acc_bmi270_get_step_detector_data_signal(board)
            case .bma255: throw MWError.operationFailed("Accelerometer invalid for step detection.")
        }
    }

    func streamStart(board: MWBoard) {
        print("-> mbl_mw_acc_bmiXXX_enable_step_detector", #function)
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_enable_step_detector(board)
            case .bmi270: mbl_mw_acc_bmi270_enable_step_detector(board)
            default: return
        }
    }

    func streamCleanup(board: MWBoard) {
        print("-> mbl_mw_acc_stop", #function)
        mbl_mw_acc_stop(board)
        guard let model = MWAccelerometer.Model(board: board) else { return }
        print("-> mbl_mw_acc_bmiXXX_disable_step_detector", #function)
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_disable_step_detector(board)
            case .bmi270: mbl_mw_acc_bmi270_disable_step_detector(board)
            default: return
        }
    }
}

fileprivate func configureAccelerometerForStepping(_ board: MWBoard) {
    print("-> mbl_mw_acc_start", #function)
    mbl_mw_acc_start(board)
    print("-> mbl_mw_acc_set_range(board, 8.0)", #function)
    mbl_mw_acc_set_range(board, 8.0) // Max range in gs
    print("-> mbl_mw_acc_set_odr(board, 100)", #function)
    mbl_mw_acc_set_odr(board, 100) // Must be at least 25 Hz
    print("-> mbl_mw_acc_write_acceleration_config", #function)
    mbl_mw_acc_write_acceleration_config(board)
}
