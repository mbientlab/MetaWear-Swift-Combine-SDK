// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine
import simd

// MARK: - Signals

public struct MWSensorFusion { }

public extension MWSensorFusion {

    /// Pitch, Roll, Yaw (Degrees)
    struct EulerAngles: MWStreamable, MWLoggable {

        /// Pitch, Roll, Yaw (Degrees)
        public typealias DataType = SIMD3<Float>
        public typealias RawDataType = MblMwEulerAngles
        public let columnHeadings = ["Epoch", "Pitch", "Roll", "Yaw"]
        public let signalName: MWNamedSignal = .eulerAngles
        public let output: OutputType = .eulerAngles

        public var mode: MWSensorFusion.Mode

        public init(mode: MWSensorFusion.Mode) {
            self.mode = mode
        }

    }

    /// WXYZ
    struct Quaternion: MWStreamable, MWLoggable {

        /// WXYZ
        public typealias DataType = simd_quatf
        public typealias RawDataType = MblMwQuaternion
        public let signalName: MWNamedSignal = .quaternion
        public let output: OutputType = .quaternion

        public var mode: MWSensorFusion.Mode

        public init(mode: MWSensorFusion.Mode) {
            self.mode = mode
        }

        public func convert(data: MWData) -> Timestamped<DataType> {
            let raw = data.valueAs() as MblMwQuaternion
            return (data.timestamp, .init(ix: raw.x, iy: raw.y, iz: raw.z, r: raw.w))
        }
    }

    /// XYZ (Gs)
    struct Gravity: MWStreamable, MWLoggable {

        /// XYZ (Gs)
        public typealias DataType = SIMD3<Float>
        public typealias RawDataType = MblMwCartesianFloat
        public let signalName: MWNamedSignal = .gravity
        public let output: OutputType = .gravity

        public var mode: MWSensorFusion.Mode

        public init(mode: MWSensorFusion.Mode) {
            self.mode = mode
        }
    }

    /// XYZ (Gs)
    struct LinearAcceleration: MWStreamable, MWLoggable {

        /// XYZ (Gs)
        public typealias DataType = SIMD3<Float>
        public typealias RawDataType = MblMwCartesianFloat
        public let signalName: MWNamedSignal = .linearAcceleration
        public let output: OutputType = .linearAcceleration

        public var mode: MWSensorFusion.Mode

        public init(mode: MWSensorFusion.Mode) {
            self.mode = mode
        }
    }
}

public extension MWSensorFusion.EulerAngles {
    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        MWSensorFusion.signal(board: board, output: output)
    }
    func streamConfigure(board: MWBoard) {
        MWSensorFusion.configure(board: board, mode: mode)
    }
    func streamStart(board: MWBoard) {
        MWSensorFusion.start(board: board, output: output)
    }
    func streamCleanup(board: MWBoard) {
        MWSensorFusion.cleanup(board: board, output: output)
    }
}

public extension MWSensorFusion.Quaternion {
    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        MWSensorFusion.signal(board: board, output: output)
    }
    func streamConfigure(board: MWBoard) {
        MWSensorFusion.configure(board: board, mode: mode)
    }
    func streamStart(board: MWBoard) {
        MWSensorFusion.start(board: board, output: output)
    }
    func streamCleanup(board: MWBoard) {
        MWSensorFusion.cleanup(board: board, output: output)
    }
}

public extension MWSensorFusion.Gravity {
    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        MWSensorFusion.signal(board: board, output: output)
    }
    func streamConfigure(board: MWBoard) {
        MWSensorFusion.configure(board: board, mode: mode)
    }
    func streamStart(board: MWBoard) {
        MWSensorFusion.start(board: board, output: output)
    }
    func streamCleanup(board: MWBoard) {
        MWSensorFusion.cleanup(board: board, output: output)
    }
}

public extension MWSensorFusion.LinearAcceleration {
    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        MWSensorFusion.signal(board: board, output: output)
    }
    func streamConfigure(board: MWBoard) {
        MWSensorFusion.configure(board: board, mode: mode)
    }
    func streamStart(board: MWBoard) {
        MWSensorFusion.start(board: board, output: output)
    }
    func streamCleanup(board: MWBoard) {
        MWSensorFusion.cleanup(board: board, output: output)
    }
}

internal extension MWSensorFusion {

    static func configure(board: MWBoard, mode: Mode) {
        var mode = mode
        let hasMagnetometer = MWModules.lookup(in: board, .magnetometer) != nil
        if mode == .ndof, hasMagnetometer == false { mode = .imuplus }
        mbl_mw_sensor_fusion_set_mode(board, mode.cppMode)
        mbl_mw_sensor_fusion_set_acc_range(board, MBL_MW_SENSOR_FUSION_ACC_RANGE_16G)
        mbl_mw_sensor_fusion_set_gyro_range(board, MBL_MW_SENSOR_FUSION_GYRO_RANGE_2000DPS)
        mbl_mw_sensor_fusion_write_config(board)
    }

    static func start(board: MWBoard, output: OutputType) {
        mbl_mw_sensor_fusion_enable_data(board, output.cppEnumValue)
        mbl_mw_sensor_fusion_start(board)
    }

    static func signal(board: MWBoard, output: OutputType) -> OpaquePointer? {
        mbl_mw_sensor_fusion_get_data_signal(board, output.cppEnumValue)
    }

    static func cleanup(board: MWBoard, output: OutputType) {
        mbl_mw_sensor_fusion_stop(board)
    }
}

// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWSensorFusion.EulerAngles {
    static func sensorFusionEulerAngles(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}
public extension MWLoggable where Self == MWSensorFusion.EulerAngles {
    static func sensorFusionEulerAngles(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}

public extension MWStreamable where Self == MWSensorFusion.Quaternion {
    static func sensorFusionQuaternion(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}
public extension MWLoggable where Self == MWSensorFusion.Quaternion {
    static func sensorFusionQuaternion(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}

public extension MWStreamable where Self == MWSensorFusion.Gravity {
    static func sensorFusionGravity(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}
public extension MWLoggable where Self == MWSensorFusion.Gravity {
    static func sensorFusionGravity(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}

public extension MWStreamable where Self == MWSensorFusion.LinearAcceleration {
    static func sensorFusionLinearAcceleration(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}
public extension MWLoggable where Self == MWSensorFusion.LinearAcceleration {
    static func sensorFusionLinearAcceleration(mode: MWSensorFusion.Mode) -> Self {
        Self(mode: mode)
    }
}

// MARK: - C++ Constants

public extension MWSensorFusion {

    enum Mode: Int, CaseIterable, IdentifiableByRawValue {
        case compass
        case imuplus
        case m4g
        case ndof

        public var cppValue: UInt32 {
            switch self {
                case .ndof: return 1
                case .imuplus: return 2
                case .compass: return 3
                case .m4g: return 4
            }
        }

        public var cppMode: MblMwSensorFusionMode { MblMwSensorFusionMode(cppValue) }

        public var label: String {
            switch self {
                case .ndof: return "NDoF"
                case .imuplus: return "IMUPlus"
                case .compass: return "Compass"
                case .m4g: return "M4G"
            }
        }
    }

    enum OutputType: String, CaseIterable, IdentifiableByRawValue {
        case eulerAngles
        case gravity
        case linearAcceleration
        case quaternion

        public var cppEnumValue: MblMwSensorFusionData {
            switch self {
                case .eulerAngles: return MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE
                case .quaternion: return MBL_MW_SENSOR_FUSION_DATA_QUATERNION
                case .gravity: return MBL_MW_SENSOR_FUSION_DATA_GRAVITY_VECTOR
                case .linearAcceleration: return MBL_MW_SENSOR_FUSION_DATA_LINEAR_ACC
            }
        }

        public var channelCount: Int { channelLabels.endIndex }

        public var channelLabels: [String] {
            switch self {
                case .eulerAngles: return ["Pitch", "Roll", "Yaw"]
                case .quaternion: return ["W", "X", "Y", "Z"]
                case .gravity: return ["X", "Y", "Z"]
                case .linearAcceleration: return ["X", "Y", "Z"]
            }
        }

        public var label: String {
            switch self {
                case .eulerAngles: return "Euler Angles"
                case .quaternion: return "Quaternion"
                case .gravity: return "Gravity"
                case .linearAcceleration: return "Linear Acceleration"
            }
        }

        public var scale: Float {
            switch self {
                case .eulerAngles: return 360
                case .quaternion: return 1
                case .gravity: return 1
                case .linearAcceleration: return 8
            }
        }

    }
}
