// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWOrientationSensor {
    public static var orientation: Self { Self() }
}

extension MWLoggable where Self == MWOrientationSensor {
    public static var orientation: Self { Self() }
}


// MARK: - Signals

public struct MWOrientationSensor: MWStreamable, MWLoggable {
    public typealias DataType = MWAccelerometer.Orientation
    public typealias RawDataType = MblMwSensorOrientation
    public let signalName: MWNamedSignal = .orientation
}


// MARK: - Signal Implementations

public extension MWOrientationSensor {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard case .bmi160 = MWAccelerometer.Model(board: board) else {
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


// MARK: - C++ Constants

extension MWAccelerometer {

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
