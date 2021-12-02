// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine
import AppKit


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWAccelerometer {

    /// Prepares the accelerometer module. If any
    ///  parameters are nil, the device uses the
    ///  last setting or a default.
    ///
    /// - Parameters:
    ///   - rate: Sampling frequency (if nil, device uses last setting or a default)
    ///   - gravity: Range of detection
    /// - Returns: Accelerometer module configuration
    static func accelerometer(rate: Self.SampleFrequency? = nil, gravity: Self.GravityRange? = nil) -> Self {
        Self(rate: rate, gravity: gravity)
    }
}

extension MWLoggable where Self == MWAccelerometer {

    /// Prepares the accelerometer module. If any
    ///  parameters are nil, the device uses the
    ///  last setting or a default.
    ///
    /// - Parameters:
    ///   - rate: Sampling frequency (if nil, device uses last setting or a default)
    ///   - gravity: Range of detection
    /// - Returns: Accelerometer module configuration
    static func accelerometer(rate: Self.SampleFrequency? = nil, gravity: Self.GravityRange? = nil) -> Self {
        Self(rate: rate, gravity: gravity)
    }
}

extension MWStreamable where Self == MWOrientationSensor {
    static var orientation: Self { Self() }
}

extension MWLoggable where Self == MWOrientationSensor {
    static var orientation: Self { Self() }
}

extension MWStreamable where Self == MWStepDetector {
    static func steps(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWDataConvertible where Self == MWStepCounter {
    static var steps: Self { Self() }
}


// MARK: - Signals

public struct MWAccelerometer: MWLoggable, MWStreamable {

    public typealias DataType = SIMD3<Float>
    public typealias RawDataType = MblMwCartesianFloat
    public let loggerName: MWLogger = .acceleration

    public var gravity: GravityRange? = nil
    public var rate: SampleFrequency? = nil
    public var needsConfiguration: Bool { gravity != nil || rate != nil }

    public init(rate: SampleFrequency?, gravity: GravityRange?) {
        self.gravity = gravity
        self.rate = rate
    }
}

public struct MWOrientationSensor: MWStreamable, MWLoggable {
    public typealias DataType = MWAccelerometer.Orientation
    public typealias RawDataType = MblMwSensorOrientation
    public let loggerName: MWLogger = .orientation
}

public struct MWStepCounter: MWDataConvertible {
    public typealias DataType = Int32
    public typealias RawDataType = Int32
    public let columnHeadings = ["Epoch", "Steps"]
}

/// Requires counting steps by counting each closure returned as one step
public struct MWStepDetector: MWStreamable {

    public typealias DataType = Int
    public typealias RawDataType = Int32
    public let columnHeadings = ["Epoch", "Steps"]

    public var sensitivity: MWAccelerometer.StepCounterSensitivity? = nil
    public var needsConfiguration: Bool { sensitivity != nil }

    public init(sensitivity: MWAccelerometer.StepCounterSensitivity?) {
        self.sensitivity = sensitivity
    }
}

// MARK: - Signal Implementations


public extension MWAccelerometer {

    func streamSignal(board: MWBoard) -> MWDataSignal? {
        mbl_mw_acc_bosch_get_acceleration_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        guard needsConfiguration else { return }
        guard let model = Model(board: board) else { return }
        if let range = gravity { mbl_mw_acc_bosch_set_range(board, range.cppEnumValue) }
        if let rate = rate { mbl_mw_acc_set_odr(board, rate.supported(by: model).cppOdrValue) }
        mbl_mw_acc_bosch_write_acceleration_config(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_acc_enable_acceleration_sampling(board)
        mbl_mw_acc_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_disable_acceleration_sampling(board)
    }

    func loggerCleanup(board: MWBoard) {
        self.streamCleanup(board: board)
        guard Model(board: board) == .bmi270 else { return }
        mbl_mw_logging_flush_page(board)
    }
}

public extension MWOrientationSensor {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
            throw MWError.operationFailed("Orientation requires a BMI160 module, which this device lacks.")
        }
        return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {}

    func streamStart(board: MWBoard) {
        mbl_mw_acc_bosch_enable_orientation_detection(board)
        mbl_mw_acc_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bosch_disable_orientation_detection(board)
    }
}

public extension MWStepDetector {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        fatalError("Get correct methods")
        guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
            throw MWError.operationFailed("Steps requires a BMI160 module, which this device lacks.")
        }
        return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        guard let sensitivity = sensitivity else { return }
        mbl_mw_acc_bmi160_set_step_counter_mode(board, sensitivity.cppEnumValue)
        mbl_mw_acc_bmi160_write_step_counter_config(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_acc_bmi160_enable_step_detector(board)
        mbl_mw_acc_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bmi160_disable_step_detector(board)
    }
}


// MARK: - C++ Constants

extension MWAccelerometer {

    /// ± Gs
    /// Not all accelerometer models support all ranges. Use `supported(by:)` for valid values.
    public enum GravityRange: Int, CaseIterable, IdentifiableByRawValue {
        case g2  = 2
        case g4  = 4
        case g8  = 8
        case g16 = 16 /// Not supported by MMA module

        /// Raw Cpp constant
        public var cppEnumValue: MblMwAccBoschRange {
            switch self {
                case .g2:  return MBL_MW_ACC_BOSCH_RANGE_2G
                case .g4:  return MBL_MW_ACC_BOSCH_RANGE_4G
                case .g8:  return MBL_MW_ACC_BOSCH_RANGE_8G
                case .g16: return MBL_MW_ACC_BOSCH_RANGE_16G
            }
        }
    }

    /// Hertz
    public enum SampleFrequency: Float, CaseIterable, IdentifiableByRawValue {
        /// Too fast to stream by Bluetooth Low Energy.
        /// BMI160/270
        case hz800   = 800
        /// Too fast to stream by Bluetooth Low Energy.
        /// BMI160/270
        case hz400   = 400
        /// Too fast to stream by Bluetooth Low Energy.
        /// BMI160/270
        case hz200   = 200
        /// BMI160/270
        case hz100   = 100
        /// BMI160/270
        case hz50    = 50
        /// BMI160/270
        case hz12_5  = 12.5

        /// — BMA255 only
        case hz500   = 500
        /// — BMA255 only
        case hz250   = 250
        /// — BMA255 only
        case hz125   = 125
        /// — BMA255 only
        case hz62_5  = 62.5
        /// — BMA255 only
        case hz31_26 = 31.26
        /// — BMA255 only
        case hz15_62 = 15.62


        /// Returns an integer string, except for those with fractional values.
        public var frequencyLabel: String {
            switch self {
                case .hz12_5:  return "12.5"
                case .hz62_5:  return "62.5"
                case .hz31_26: return "31.26"
                case .hz15_62: return "15.62"
                default: return String(format: "%1.0f", rawValue)
            }
        }

        public var cppOdrValue: Float { rawValue }

        public static let bma255: [SampleFrequency] = [.hz500, .hz250, .hz125, .hz62_5, .hz31_26, .hz15_62]
        public static let bmi: [SampleFrequency] = [.hz800, .hz400, .hz200, .hz100, .hz50, .hz12_5]

        public static func supported(by accelerometer: Model) -> [SampleFrequency] {
            switch accelerometer {
                case .bmi160: fallthrough
                case .bmi270: return Self.bmi
                case .bma255: return Self.bma255
            }
        }

        public func supported(by accelerometer: Model) -> SampleFrequency {
            switch accelerometer {
                case .bmi160: fallthrough
                case .bmi270:
                    switch self {
                        case .hz500:   return .hz800
                        case .hz250:   return .hz400
                        case .hz125:   return .hz200
                        case .hz62_5:  return .hz100
                        case .hz31_26: return .hz50
                        case .hz15_62: return .hz50
                        default: return self
                    }

                case .bma255:
                    switch self {
                        case .hz800:   return .hz500
                        case .hz400:   return .hz500
                        case .hz200:   return .hz250
                        case .hz100:   return .hz125
                        case .hz50:    return .hz62_5
                        case .hz12_5:  return .hz15_62
                        default: return self
                    }
            }
        }
    }

    /// Available on the BMI160 only.
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

    public enum Capabilities: String, CaseIterable, IdentifiableByRawValue {
        case stepCounter
        case stepDetector
        case orientation

        static func supported(by accelerometer: Model) -> Set<Capabilities> {
            switch accelerometer {
                case .bmi160:   return [.stepCounter, .stepDetector, .orientation]
                case .bmi270:   return [.stepCounter, .stepDetector]
                case .bma255:   return [.stepCounter, .stepDetector]
//                case .mma8452q: return [.stepCounter, .stepDetector]
            }
        }
    }

    public enum Model: String, CaseIterable, IdentifiableByRawValue {
        case bmi160
        case bmi270
        case bma255
//        case mma8452q  Not included in SDK

        /// Raw Cpp constant
        public var int8Value: UInt8 {
            switch self {
                case .bmi160:   return MBL_MW_MODULE_ACC_TYPE_BMI160
                case .bmi270:   return MBL_MW_MODULE_ACC_TYPE_BMI270
                case .bma255:   return MBL_MW_MODULE_ACC_TYPE_BMA255
//                case .mma8452q: return MBL_MW_MODULE_ACC_TYPE_MMA8452Q
            }
        }

        /// Cpp constant for Swift
        public var int32Value: Int32 { Int32(int8Value) }

        public init?(value: Int32) {
            switch value {
                case Self.bmi270.int32Value: self = .bmi270
                case Self.bmi160.int32Value: self = .bmi160
                case Self.bma255.int32Value: self = .bma255
//                case Self.mma8452q.int32Value: self = .mma8452q
                default: return nil
            }
        }

        public init?(board: OpaquePointer?) {
            let accelerometer = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER)
            self.init(value: accelerometer)
        }
    }

    /// Supported only by BMI160
    public enum Orientation: String, CaseIterable, IdentifiableByRawValue {
        case faceUpPortraitUpright
        case faceUpPortraitUpsideDown
        case faceUpLandscapeLeft
        case faceUpLandscapeRight

        case faceDownPortraitUpright
        case faceDownPortraitUpsideDown
        case faceDownLandscapeLeft
        case faceDownLandscapeRight

        /// Raw Cpp constant
        public var cppEnumValue: MblMwSensorOrientation {
            switch self {
                case .faceUpPortraitUpright:      return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPRIGHT
                case .faceUpPortraitUpsideDown:   return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPSIDE_DOWN
                case .faceUpLandscapeLeft:        return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_LEFT
                case .faceUpLandscapeRight:       return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_RIGHT

                case .faceDownPortraitUpright:    return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPRIGHT
                case .faceDownPortraitUpsideDown: return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPSIDE_DOWN
                case .faceDownLandscapeLeft:      return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_LEFT
                case .faceDownLandscapeRight:     return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_RIGHT
            }
        }

        public var nameOnTwoLines: String {
            switch self {
                case .faceUpPortraitUpright:        return "Portrait Upright\nFace Up"
                case .faceUpPortraitUpsideDown:     return "Portrait Upsidedown\nFace Up"
                case .faceUpLandscapeLeft:          return "Landscape Left\nFace Up"
                case .faceUpLandscapeRight:         return "Landscape Right\nFace Up"
                case .faceDownPortraitUpright:      return "Portrait Upright\nFace Down"
                case .faceDownPortraitUpsideDown:   return "Portrait Upsidedown\nFace Down"
                case .faceDownLandscapeLeft:        return "Landscape Left\nFace Down"
                case .faceDownLandscapeRight:       return "Landscape Right\nFace Down"
            }
        }

        public init?(sensor: MblMwSensorOrientation) {
            guard let match = Self.allCases.first(where: { $0.cppEnumValue == sensor })
            else { return nil }
            self = match
        }

        /// Returns whether orientation is support by this model
        public func supported(by accelerometer: Model) -> Bool {
            accelerometer == .bmi160
        }
    }

}
