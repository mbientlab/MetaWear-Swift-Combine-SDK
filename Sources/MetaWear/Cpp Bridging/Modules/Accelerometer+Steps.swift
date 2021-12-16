// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWStepDetector {
    public static func steps(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWDataConvertible where Self == MWStepCounter {
    public static var steps: Self { Self() }
}


// MARK: - Signals

public struct MWStepCounter: MWDataConvertible {
    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let columnHeadings = ["Epoch", "Steps"]

    #warning("IMPLEMENT STEP COUNTER")
//    guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
//        throw MWError.operationFailed("Steps requires a BMI160 module, which this device lacks.")
//    }
}

/// Requires counting steps by counting each closure returned as one step
public struct MWStepDetector: MWStreamable {

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

    func streamConfigure(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        guard case .bmi160 = model else { return }
        mbl_mw_acc_bmi160_set_step_counter_mode(board, (sensitivity ?? .normal).cppEnumValue)
        mbl_mw_acc_bmi160_write_step_counter_config(board)
    }

    func streamStart(board: MWBoard) {
        guard let model = MWAccelerometer.Model(board: board) else { return }
        switch model {
            case .bmi160: mbl_mw_acc_bmi160_enable_step_detector(board)
            case .bmi270: mbl_mw_acc_bmi270_enable_step_detector(board)
            default: return
        }
        mbl_mw_acc_start(board)
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
