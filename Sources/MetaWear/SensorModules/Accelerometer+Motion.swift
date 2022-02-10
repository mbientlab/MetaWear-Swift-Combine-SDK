// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWMotion.Activity {
    /// The BMI270 can detect simple user activities (unknown, still, walking, running)
    /// and send an interrupt if those are changed, e.g. from walking to running.
    public static var motionActivityClassification: Self { Self() }
}

//extension MWLoggable where Self == MWMotion.Activity {
//    /// The BMI270 can detect simple user activities (unknown, still, walking, running)
//    /// and send an interrupt if those are changed, e.g. from walking to running.
//    public static var motionActivityClassification: Self { Self() }
//}


extension MWStreamable where Self == MWMotion.Significant {
    /// The BMI270 can detect motions including walking, biking, sitting in a moving car, coach or train, etc.
    /// Situations that don't typically trigger include phone in pocket while stationary or
    /// phone at rest on a table which is in normal office use.
    public static var motionSignificant: Self { Self() }
}

//extension MWLoggable where Self == MWMotion.Significant {
//    /// The BMI270 can detect motions including walking, biking, sitting in a moving car, coach or train, etc.
//    /// Situations that don't typically trigger include phone in pocket while stationary or
//    /// phone at rest on a table which is in normal office use.
//    public static var motionSignificant: Self { Self() }
//}


extension MWStreamable where Self == MWMotion.AnyMotion {
    /// The BMI270 uses the slope between two acceleration signals to detect changes in motion.
    public static var motionAny: Self { Self() }
}

//extension MWLoggable where Self == MWMotion.AnyMotion {
//    /// The BMI270 uses the slope between two acceleration signals to detect changes in motion.
//    public static var motionAny: Self { Self() }
//}


extension MWStreamable where Self == MWMotion.NoMotion {
    /// Detect when there is no motion for a certain amount of time.
    public static var motionNone: Self { Self() }
}

//extension MWLoggable where Self == MWMotion.NoMotion {
//    /// Detect when there is no motion for a certain amount of time.
//    public static var motionNone: Self { Self() }
//}


// MARK: - Signals

/// User activity detector on the MMS
public struct MWMotion { }

public extension MWMotion {

    /// The BMI270 can detect simple user activities (unknown, still, walking, running)
    /// and send an interrupt if those are changed, e.g. from walking to running.
    struct Activity: MWStreamable, MWLoggable {
        /// The BMI270 can detect simple user activities (unknown, still, walking, running)
        /// and send an interrupt if those are changed, e.g. from walking to running.
        public init() { }
        public typealias DataType = Classification
        public typealias RawDataType = MblMwAccBoschActivity
        public let signalName: MWNamedSignal = .motion
        public var columnHeadings = ["Date", "Activity"]
    }

    /// The BMI270 can detect motions including walking, biking, sitting in a moving car, coach or train, etc.
    /// Situations that don't typically trigger include phone in pocket while stationary or
    /// phone at rest on a table which is in normal office use.
    struct Significant: MWStreamable, MWLoggable, _BoschMotion {
        /// The BMI270 can detect motions including walking, biking, sitting in a moving car, coach or train, etc.
        /// Situations that don't typically trigger include phone in pocket while stationary or
        /// phone at rest on a table which is in normal office use.
        public init() { }
        public let signalName: MWNamedSignal = .motion
        public let boschType: MWMotion.Activity._BoschMotion = .sigMotion
        public let columnHeadings: [String] = ["Date", "Significant Motion"]
    }

    /// The BMI270 uses the slope between two acceleration signals to detect changes in motion.
    struct AnyMotion: MWStreamable, MWLoggable, _BoschMotion {
        /// The BMI270 uses the slope between two acceleration signals to detect changes in motion.
        public init() { }
        public let signalName: MWNamedSignal = .motion
        public let boschType: MWMotion.Activity._BoschMotion = .anyMotion
        public let columnHeadings: [String] = ["Date", "Motion"]
    }

    /// Detect when there is no motion for a certain amount of time.
    struct NoMotion: MWStreamable, MWLoggable, _BoschMotion {
        /// Detect when there is no motion for a certain amount of time.
        public init() { }
        public let signalName: MWNamedSignal = .motion
        public let boschType: MWMotion.Activity._BoschMotion = .noMotion
        public let columnHeadings: [String] = ["Date", "No Motion"]
    }
}


// MARK: - Signal Implementations

public extension MWMotion.Activity {

    func streamConfigure(board: MWBoard) {}

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard case .bmi270 = MWAccelerometer.Model(board: board)
        else { throw MWError.operationFailed("Requires BMI270 Bosch accelerometer.") }
        return mbl_mw_acc_bmi270_get_activity_detector_data_signal(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_acc_bmi270_enable_activity_detection(board)
        mbl_mw_acc_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bmi270_disable_activity_detection(board)
    }
}

// Bosch Motions

public extension MWMotion.Significant {

    func streamConfigure(board: MWBoard) {
        guard case .bmi270 = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometer(board)
        mbl_mw_acc_bosch_set_sig_motion_blocksize(board, 250)
        mbl_mw_acc_bosch_write_motion_config(board, boschType.cppEnumValue)
    }
}

public extension MWMotion.AnyMotion {

    func streamConfigure(board: MWBoard) {
        guard case .bmi270 = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometer(board)
        mbl_mw_acc_bosch_set_any_motion_count(board, 5)
        mbl_mw_acc_bosch_set_any_motion_threshold(board, 170.0)
        mbl_mw_acc_bosch_write_motion_config(board, boschType.cppEnumValue)
    }
}

public extension MWMotion.NoMotion {

    func streamConfigure(board: MWBoard) {
        guard case .bmi270 = MWAccelerometer.Model(board: board) else { return }
        configureAccelerometer(board)
        mbl_mw_acc_bosch_set_no_motion_count(board, 5)
        mbl_mw_acc_bosch_set_no_motion_threshold(board, 144.0)
        mbl_mw_acc_bosch_write_motion_config(board, boschType.cppEnumValue)
    }
}

// MARK: - DRY Methods for Bosch Motion

public protocol _BoschMotion {
    var boschType: MWMotion.Activity._BoschMotion { get }
    var columnHeadings: [String] { get }
}

public extension _BoschMotion {

    typealias DataType = Bool
    typealias RawDataType = UInt32

    func convert(from raw: Timestamped<UInt32>) -> Timestamped<Bool> {
        (raw.time, raw.value == 0 ? false : true)
    }

    func asColumns(_ datum: Timestamped<Bool>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value ? "Detected" : "–"]
    }

    func configureAccelerometer(_ board: MWBoard) {
        mbl_mw_acc_start(board)
        mbl_mw_acc_set_odr(board, 100) // Must be at least 25 Hz
        mbl_mw_acc_write_acceleration_config(board)
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard case .bmi270 = MWAccelerometer.Model(board: board)
        else { throw MWError.operationFailed("Requires BMI270 Bosch accelerometer.") }
        return  mbl_mw_acc_bosch_get_motion_data_signal(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_acc_bosch_enable_motion_detection(board, boschType.cppEnumValue)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bosch_disable_motion_detection(board, boschType.cppEnumValue)
    }
}


// MARK: - C++ Constants

extension MWMotion.Activity {

    /// Supported only by BMI160
    public enum Classification: String, CaseIterable, IdentifiableByRawValue {
        case still
        case walking
        case running
        case unknown

        /// Raw Cpp constant
        public var cppEnumValue: MblMwAccBoschActivity {
            switch self {
                case .still:     return MBL_MW_ACC_BOSCH_ACTIVITY_STILL
                case .walking:   return MBL_MW_ACC_BOSCH_ACTIVITY_WALKING
                case .running:   return MBL_MW_ACC_BOSCH_ACTIVITY_RUNNING
                case .unknown:   return MBL_MW_ACC_BOSCH_ACTIVITY_UNKNOWN
            }
        }

        public var label: String {
            switch self {
                case .still:     return "Still"
                case .walking:   return "Walking"
                case .running:   return "Running"
                case .unknown:   return "Unknown"
            }
        }

        public init(cppValue: MblMwAccBoschActivity) {
            self = Self.allCases.first(where: { $0.cppEnumValue == cppValue }) ?? .unknown
        }
    }

    public enum _BoschMotion: UInt32, CaseIterable, IdentifiableByRawValue, Equatable, Hashable {
        case anyMotion
        case noMotion
        case sigMotion

        public var cppEnumValue: MblMwAccBoschMotion {
            switch self {
                case .anyMotion: return MBL_MW_ACC_BOSCH_MOTION_ANYMOTION
                case .noMotion:  return MBL_MW_ACC_BOSCH_MOTION_NOMOTION
                case .sigMotion: return MBL_MW_ACC_BOSCH_MOTION_SIGMOTION
            }
        }
    }

    public struct AnyMotionTrigger: Equatable, Hashable {
        public var motionSlopeWasNegative: Bool
        public var triggers: Set<Axis>

        public enum Axis: String, IdentifiableByRawValue {
            case x, y, z
        }

        public init(motionSlopeWasNegative: Bool, triggers: Set<MWMotion.Activity.AnyMotionTrigger.Axis>) {
            self.motionSlopeWasNegative = motionSlopeWasNegative
            self.triggers = triggers
        }

        public init(raw: MblMwBoschAnyMotion) {
            self.motionSlopeWasNegative = raw.sign == 0
            var _triggers = Set<Axis>()
            if raw.x_axis_active != 0 { _triggers.insert(.x) }
            if raw.y_axis_active != 0 { _triggers.insert(.y) }
            if raw.z_axis_active != 0 { _triggers.insert(.z) }
            self.triggers = _triggers
        }

        public func stringify() -> [String] {
            let slope = motionSlopeWasNegative ? "-" : "+"
            let axes = triggers.map(\.rawValue).joined(separator: " ")
            return [slope + " " + axes]
        }
    }

}
