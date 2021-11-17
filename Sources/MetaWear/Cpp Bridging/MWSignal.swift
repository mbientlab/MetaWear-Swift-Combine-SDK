////Copyright

import Foundation
import Combine
import MetaWearCpp


// These are code completion-friendly presets
// for obtaining a data signal from a MetaWear
// without directly calling C++ functions or
// casting incoming data as the correct type.
//
// The generics DataType and Frequency
// ensure code completion offers only relevant
// suggestions that can be read once, streamed,
// or provide a logger reference and output the
// correctly casted data type.
//
// Try them in functions like`.readOnce` and `.stream`.

extension MWSignal where DataType == String, Frequency == MWReadableOnce {

    /// Values:
    public static let macAddress = MWSignal("MAC Address", mbl_mw_settings_get_mac_data_signal)

}

extension MWSignal where DataType == Int8, Frequency == MWReadableOnce {

    /// Values: 0 to 100
    public static let batteryPercentage = MWSignal("Battery Level", mbl_mw_settings_get_battery_state_data_signal)

}

extension MWSignal where DataType == MblMwCartesianFloat, Frequency == MWLoggableStreamable {

    /// Runs the accelerometer in its existing or default configuration
    public static let accelerometer = _accelerometer(configure: nil)

    /// Runs the accelerometer in a new configuration
    public static func accelerometer(range: MWAccelerometerGravityRange,
                                     rate: MWAccelerometerSampleFrequency) -> MWSignal {
        _accelerometer(configure: { board in
            mbl_mw_acc_bosch_set_range(board, range.cppEnumValue)
            mbl_mw_acc_set_odr(board, rate.frequency)
            mbl_mw_acc_bosch_write_acceleration_config(board)
        })
    }

    private static func _accelerometer(configure: ((OpaquePointer) -> Void)? ) -> MWSignal {
        .init(
            "Accelerometer",
            dataSignal: mbl_mw_acc_bosch_get_acceleration_data_signal,
            loggerKey: .acceleration,
            configure: configure ?? { _ in },
            signalStart: { board in
                mbl_mw_acc_enable_acceleration_sampling(board)
                mbl_mw_acc_start(board)
            },
            streamCleanup: { board in
                mbl_mw_acc_stop(board)
                mbl_mw_acc_disable_acceleration_sampling(board)
            },
            logCleanup: { board in
                mbl_mw_acc_stop(board)
                mbl_mw_acc_disable_acceleration_sampling(board)
                guard MWAccelerometerModel(board: board) == .bmi270 else { return }
                mbl_mw_logging_flush_page(board)
            }
        )
    }
}

extension MWSignal where DataType == MblMwSensorOrientation, Frequency == MWLoggableStreamable {

    /// Requires the BMI160 accelerometer module. (The BMI270 does not support orientation and stepping.)
    public static let orientation = MWSignal(
        "Orientation",
        dataSignal: { board in
            guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
                throw MetaWearError.operationFailed("Orientation requires a BMI160 module, which this device lacks.")
            }
            return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
        },
        loggerKey: .orientation,
        configure: { _ in },
        signalStart: { board in
            mbl_mw_acc_bosch_enable_orientation_detection(board)
            mbl_mw_acc_start(board)
        },
        streamCleanup: { board in
            mbl_mw_acc_stop(board)
            mbl_mw_acc_bosch_disable_orientation_detection(board)
        },
        logCleanup: { board in
            mbl_mw_acc_stop(board)
            mbl_mw_acc_bosch_disable_orientation_detection(board)
        }
    )

}

#warning("What is the correct return? Can this work on 270 per docs?")
extension MWSignal where DataType == Int32, Frequency == MWLoggableStreamable {

    public static let stepDetector = _steps(configure: nil)
//
//    public static func steps(sensitivity: MWStepCounterSensitivity = .normal) -> MWSignal {
//        _steps(configure: { board in
//            mbl_mw_acc_bmi160_set_step_counter_mode(board, sensitivity.cppEnumValue)
//            mbl_mw_acc_bmi160_write_step_counter_config(board)
//        })
//    }

    /// Requires the BMI160 accelerometer module. (The BMI270 does not support orientation and stepping.)
    private static func _steps(configure: ((OpaquePointer) -> Void)? ) -> MWSignal {
        .init("Steps",
              dataSignal: { board in
            guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
                throw MetaWearError.operationFailed("Orientation requires a BMI160 module, which this device lacks.")
            }
            return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
        },
              loggerKey: .steps,
              configure: configure ?? { _ in },
              signalStart: { board in
            mbl_mw_acc_bmi160_enable_step_detector(board)
            mbl_mw_acc_start(board)
        },
              streamCleanup: { board in
            mbl_mw_acc_stop(board)
            mbl_mw_acc_bmi160_disable_step_detector(board)
        },
              logCleanup: { board in
            mbl_mw_acc_stop(board)
            mbl_mw_acc_bmi160_disable_step_detector(board)
        })
    }
}


// MARK: - Internal

/// Defines a signal `OpaquePointer` generated from a MetaWear board.
/// Use presets above in functions like `readOnce` or `stream`.
///
public struct MWSignal<DataType, Frequency> {

    /// Used for error messages
    public let name: String

    /// Cpp function to obtain the signal from the provided `MetaWear` board
    public let `from`: (OpaquePointer) throws -> OpaquePointer?

    /// When relevant, signal configuration methods
    public let configure: (OpaquePointer) -> Void
    /// When relevant, signal kickoff methods
    public let signalStart: (OpaquePointer) -> Void
    /// When relevant, streaming cleanup methods
    public let streamCleanup: (OpaquePointer) -> Void
    /// When relevant, logging cleanup methods
    public let logCleanup: (OpaquePointer) -> Void
    /// When relevant, logger key
    public let loggerKey: MWLoggerKey

    private init() { fatalError() }
}

/// Flags a signal as Loggable or Streamable in that it emits multiple times and can obtain a logger signal
public struct MWLoggableStreamable {}

/// Flags a signal as emitting only once
public struct MWReadableOnce {}

internal extension MWSignal where Frequency == MWLoggableStreamable {
    init(
        _ name: String,
        dataSignal: @escaping (MetaWearBoard) throws -> MWDataSignal?,
        loggerKey: MWLoggerKey,
        configure: @escaping (MetaWearBoard) -> Void,
        signalStart: @escaping (MetaWearBoard) -> Void,
        streamCleanup: @escaping (MetaWearBoard) -> Void,
        logCleanup: @escaping (MetaWearBoard) -> Void
    ) {
        self.name = name
        self.`from` = dataSignal
        self.loggerKey = loggerKey
        self.signalStart = signalStart
        self.streamCleanup = streamCleanup
        self.logCleanup = logCleanup
        self.configure = configure
    }
}


internal extension MWSignal where Frequency == MWReadableOnce {
    init(
        _ name: String,
        _ cppBoardSignal: @escaping (MetaWearBoard) -> MWDataSignal?
    ) {
        self.name = name
        self.`from` = cppBoardSignal
        self.loggerKey = .acceleration
        self.signalStart = { _ in }
        self.streamCleanup = { _ in }
        self.logCleanup = { _ in }
        self.configure = { _ in }
    }
}

//
//extension Publisher where Output == MetaWear, Failure == MetaWearError {
//
//    func _signal<D>(for signal: MWSignal<D,MWLoggableStreamable>) -> AnyPublisher<OpaquePointer, MetaWearError> {
//        tryMap { metaWear -> MWDataSignal in
//            guard let pointer = signal.from(metaWear.board) else {
//                throw MetaWearError.operationFailed("Board unavailable for \(signal.name).")
//            }
//            return pointer
//        }
//        .mapToMetaWearError()
//        .eraseToAnyPublisher()
//    }
//}
// MARK: - Loggers

#warning("What is the orientation logger key")
public enum MWLoggerKey: String {
    case acceleration
    case orientation // Unknown
    case steps // Unknown
}


// MARK: - Accelerometer

public enum MWAccelerometerGravityRange: Int, CaseIterable, Identifiable {
    case g2
    case g4
    case g8
    case g16

    public var fullScale: Int {
        switch self {
            case .g2: return 2
            case .g4: return 4
            case .g8: return 8
            case .g16: return 16
        }
    }

    /// Raw Cpp constant
    public var cppEnumValue: MblMwAccBoschRange {
        switch self {
            case .g2: return MBL_MW_ACC_BOSCH_RANGE_2G
            case .g4: return MBL_MW_ACC_BOSCH_RANGE_4G
            case .g8: return MBL_MW_ACC_BOSCH_RANGE_8G
            case .g16: return MBL_MW_ACC_BOSCH_RANGE_16G
        }
    }

    public var id: Int { fullScale }
}


public enum MWAccelerometerSampleFrequency: Int, CaseIterable, Identifiable {
    case hz800
    case hz400
    case hz200
    case hz100
    case hz50
    case hz12_5

    public var frequency: Float {
        switch self {
            case .hz800:  return 800
            case .hz400:  return 400
            case .hz200:  return 200
            case .hz100:  return 100
            case .hz50:   return 50
            case .hz12_5: return 12.5
        }
    }

    public var frequencyLabel: String {
        switch self {
            case .hz12_5: return "12.5"
            default: return String(format: "%1.0f", frequency)
        }
    }

    public var id: Int { rawValue }
}


/// Available on the BMI160 only.
public enum MWStepCounterSensitivity: String, CaseIterable, Identifiable {
    case normal
    case sensitive
    case robust

    /// Raw Cpp constant
    public var cppEnumValue: MblMwAccBmi160StepCounterMode {
        switch self {
            case .normal: return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_NORMAL
            case .sensitive: return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_SENSITIVE
            case .robust: return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_ROBUST
        }
    }

    public var id: RawValue { rawValue }
}


public enum MWAccelerometerModel: CaseIterable {
    case bmi270
    case bmi160

    /// Raw Cpp constant
    public var int8Value: UInt8 {
        switch self {
            case .bmi270: return MetaWearCpp.MBL_MW_MODULE_ACC_TYPE_BMI270
            case .bmi160: return MetaWearCpp.MBL_MW_MODULE_ACC_TYPE_BMI160
        }
    }

    /// Cpp constant for Swift
    public var int32Value: Int32 {
        Int32(int8Value)
    }

    public init?(value: Int32) {
        switch value {
            case Self.bmi270.int32Value: self = .bmi270
            case Self.bmi160.int32Value: self = .bmi160
            default: return nil
        }
    }

    public init?(board: OpaquePointer?) {
        let accelerometer = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER)
        self.init(value: accelerometer)
    }
}

enum MWOrientation: CaseIterable {
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
            case .faceUpPortraitUpright:
                return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPRIGHT

            case .faceUpPortraitUpsideDown:
                return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPSIDE_DOWN

            case .faceUpLandscapeLeft:
                return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_LEFT

            case .faceUpLandscapeRight:
                return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_RIGHT


            case .faceDownPortraitUpright:
                return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPRIGHT

            case .faceDownPortraitUpsideDown:
                return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPSIDE_DOWN

            case .faceDownLandscapeLeft:
                return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_LEFT

            case .faceDownLandscapeRight:
                return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_RIGHT
        }
    }

    public var displayName: String {
        switch self {
            case .faceUpPortraitUpright:
                return "Portrait Upright\nFace Up"
            case .faceUpPortraitUpsideDown:
                return "Portrait Upsidedown\nFace Up"
            case .faceUpLandscapeLeft:
                return "Landscape Left\nFace Up"
            case .faceUpLandscapeRight:
                return "Landscape Right\nFace Up"
            case .faceDownPortraitUpright:
                return "Portrait Upright\nFace Down"
            case .faceDownPortraitUpsideDown:
                return "Portrait Upsidedown\nFace Down"
            case .faceDownLandscapeLeft:
                return "Landscape Left\nFace Down"
            case .faceDownLandscapeRight:
                return "Landscape Right\nFace Down"
        }
    }

    init?(sensor: MblMwSensorOrientation) {
        guard let match = Self.allCases.first(where: { $0.cppEnumValue == sensor })
        else { return nil }
        self = match
    }
}



// MARK: - Gyroscope

public enum MWGyroscopeGraphRange: Int, CaseIterable, Identifiable {
    case dps125 = 125
    case dps250 = 250
    case dps500 = 500
    case dps1000 = 1000
    case dps2000 = 2000

    public var fullScale: Int {
        switch self {
            case .dps125: return 1
            case .dps250: return 2
            case .dps500: return 4
            case .dps1000: return 8
            case .dps2000: return 16
        }
    }

    /// Raw Cpp constant
    public var cppEnumValue: MblMwGyroBoschRange {
        switch self {
            case .dps125: return MBL_MW_GYRO_BOSCH_RANGE_125dps
            case .dps250: return MBL_MW_GYRO_BOSCH_RANGE_250dps
            case .dps500: return MBL_MW_GYRO_BOSCH_RANGE_500dps
            case .dps1000: return MBL_MW_GYRO_BOSCH_RANGE_1000dps
            case .dps2000: return MBL_MW_GYRO_BOSCH_RANGE_2000dps
        }
    }

    public var displayName: String { String(rawValue) }

    public var id: Int { fullScale }

}

public enum MWGyroscopeFrequency: Int, CaseIterable, Identifiable {
case hz1600 = 1600
case hz800 = 800
case hz400 = 400
case hs200 = 200
case hz100 = 100
case hz50 = 50
case hz25 = 25

    /// Raw Cpp constant
    public var cppEnumValue: MblMwGyroBoschOdr {
        switch self {
            case .hz1600: return MBL_MW_GYRO_BOSCH_ODR_1600Hz
            case .hz800: return MBL_MW_GYRO_BOSCH_ODR_800Hz
            case .hz400: return MBL_MW_GYRO_BOSCH_ODR_400Hz
            case .hs200: return MBL_MW_GYRO_BOSCH_ODR_200Hz
            case .hz100: return MBL_MW_GYRO_BOSCH_ODR_100Hz
            case .hz50: return MBL_MW_GYRO_BOSCH_ODR_50Hz
            case .hz25: return MBL_MW_GYRO_BOSCH_ODR_25Hz
        }
    }

    var frequencyLabel: String { String(rawValue) }

    public var id: Int { rawValue }

}

// MARK: - Ambient Light

public enum MWAmbientLightGain: Int, CaseIterable, Identifiable {
    case gain1 = 1
    case gain2 = 2
    case gain4 = 4
    case gain8 = 8
    case gain48 = 48
    case gain96 = 96

    public var cppEnumValue: MblMwAlsLtr329Gain {
        switch self {
            case .gain1: return MBL_MW_ALS_LTR329_GAIN_1X
            case .gain2: return MBL_MW_ALS_LTR329_GAIN_2X
            case .gain4: return MBL_MW_ALS_LTR329_GAIN_4X
            case .gain8: return MBL_MW_ALS_LTR329_GAIN_8X
            case .gain48: return MBL_MW_ALS_LTR329_GAIN_48X
            case .gain96: return MBL_MW_ALS_LTR329_GAIN_96X
        }
    }

    var displayName: String { String(rawValue) }

    public var id: Int { rawValue }
}

public enum MWAmbientLightTR329IntegrationTime: Int, CaseIterable, Identifiable {
    case ms50 = 50
    case ms100 = 100
    case ms150 = 150
    case ms200 = 200
    case ms250 = 250
    case ms300 = 300
    case ms350 = 350
    case ms400 = 400

    public var cppEnumValue: MblMwAlsLtr329IntegrationTime {
        switch self {
            case .ms50: return MBL_MW_ALS_LTR329_TIME_50ms
            case .ms100: return MBL_MW_ALS_LTR329_TIME_100ms
            case .ms150: return MBL_MW_ALS_LTR329_TIME_150ms
            case .ms200: return MBL_MW_ALS_LTR329_TIME_200ms
            case .ms250: return MBL_MW_ALS_LTR329_TIME_250ms
            case .ms300: return MBL_MW_ALS_LTR329_TIME_300ms
            case .ms350: return MBL_MW_ALS_LTR329_TIME_350ms
            case .ms400: return MBL_MW_ALS_LTR329_TIME_400ms
        }
    }

    var displayName: String { String(rawValue) }

    public var id: Int { rawValue }
}

public enum MWAmbientLightTR329MeasurementRate: Int, CaseIterable, Identifiable {
    case ms50 = 50
    case ms100 = 100
    case ms200 = 200
    case ms500 = 500
    case ms1000 = 1000
    case ms2000 = 2000

    public var cppEnumValue: MblMwAlsLtr329MeasurementRate {
        switch self {
            case .ms50: return MBL_MW_ALS_LTR329_RATE_50ms
            case .ms100: return MBL_MW_ALS_LTR329_RATE_100ms
            case .ms200: return MBL_MW_ALS_LTR329_RATE_200ms
            case .ms500: return MBL_MW_ALS_LTR329_RATE_500ms
            case .ms1000: return MBL_MW_ALS_LTR329_RATE_1000ms
            case .ms2000: return MBL_MW_ALS_LTR329_RATE_2000ms
        }
    }

    var displayName: String { String(rawValue) }

    public var id: Int { rawValue }
}

// MARK: - Barometer

public enum MWBarometerStandbyTime: Int, Identifiable {
    case ms0_5
    case ms10 // Not BMP
    case ms20 // Not BMP
    case ms62_5
    case ms125
    case ms250
    case ms500
    case ms1000

    case ms2000 // Not BME
    case ms4000 // Not BME

    static let BMPoptions: [Self] = [
        .ms0_5,
// Missing these two options
        .ms62_5,
        .ms125,
        .ms250,
        .ms500,
        .ms1000,
        .ms2000,
        .ms4000
    ]
    static let BMEoptions: [Self] = [
        .ms0_5,
        .ms10,
        .ms20,
        .ms62_5,
        .ms125,
        .ms250,
        .ms500,
        .ms1000
        // Missing these two options
    ]

    public var displayName: String {
        switch self {
            case .ms0_5: return "0.5"
            case .ms10: return "10"
            case .ms20: return "20"
            case .ms62_5: return "62.5"
            case .ms125: return "125"
            case .ms250: return "250"
            case .ms500: return "500"
            case .ms1000: return "100"
            case .ms2000: return "2000"
            case .ms4000: return "4000"
        }
    }

    public var BME_cppEnumValue: MblMwBaroBme280StandbyTime {
        switch self {
            case .ms0_5: return MBL_MW_BARO_BME280_STANDBY_TIME_0_5ms
            case .ms10: return MBL_MW_BARO_BME280_STANDBY_TIME_10ms
            case .ms20: return MBL_MW_BARO_BME280_STANDBY_TIME_20ms
            case .ms62_5: return MBL_MW_BARO_BME280_STANDBY_TIME_62_5ms
            case .ms125: return MBL_MW_BARO_BME280_STANDBY_TIME_125ms
            case .ms250: return MBL_MW_BARO_BME280_STANDBY_TIME_250ms
            case .ms500: return MBL_MW_BARO_BME280_STANDBY_TIME_500ms
            case .ms1000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms

            case .ms2000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
            case .ms4000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
        }
    }

    public var BMP_cppEnumValue: MblMwBaroBmp280StandbyTime {
        switch self {
            case .ms0_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_0_5ms

            case .ms62_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms
            case .ms125: return MBL_MW_BARO_BMP280_STANDBY_TIME_125ms
            case .ms250: return MBL_MW_BARO_BMP280_STANDBY_TIME_250ms
            case .ms500: return MBL_MW_BARO_BMP280_STANDBY_TIME_500ms
            case .ms1000: return MBL_MW_BARO_BMP280_STANDBY_TIME_1000ms
            case .ms2000: return MBL_MW_BARO_BMP280_STANDBY_TIME_2000ms
            case .ms4000: return MBL_MW_BARO_BMP280_STANDBY_TIME_4000ms

            case .ms10: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
            case .ms20: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
        }
    }

    public var id: Int { rawValue }
}

public enum MWBarometerIIRFilter: Int, CaseIterable, Identifiable {
    case off
    case avg2
    case avg4
    case avg8
    case avg16

    public var cppEnumValue: MblMwBaroBoschIirFilter {
        switch self {
            case .off: return MBL_MW_BARO_BOSCH_IIR_FILTER_OFF
            case .avg2: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_2
            case .avg4: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_4
            case .avg8: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_8
            case .avg16: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_16
        }
    }

    public var displayName: String {
        switch self {
            case .off: return "Off"
            case .avg2: return "2"
            case .avg4: return "4"
            case .avg8: return "8"
            case .avg16: return "16"
        }
    }

    public var id: Int { rawValue }
}

public enum MWBarometerOversampling: Int, CaseIterable, Identifiable {
    case ultraLowPower
    case lowPower
    case standard
    case high
    case ultraHigh

    public var cppEnumValue: MblMwBaroBoschOversampling {
        switch self {
            case .ultraLowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_LOW_POWER
            case .lowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_LOW_POWER
            case .standard: return MBL_MW_BARO_BOSCH_OVERSAMPLING_STANDARD
            case .high: return MBL_MW_BARO_BOSCH_OVERSAMPLING_HIGH
            case .ultraHigh: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_HIGH
        }
    }

    public var displayName: String {
        switch self {
            case .ultraLowPower: return "Ultra Low"
            case .lowPower: return "Low"
            case .standard: return "Standard"
            case .high: return "High"
            case .ultraHigh: return "Ultra High"
        }
    }

    public var id: Int { rawValue }
}

public enum MWBarometerModel: CaseIterable {
    case bmp280
    case bme280

    /// Raw Cpp constant
    public var int8Value: UInt8 {
        switch self {
            case .bmp280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BMP280
            case .bme280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BME280
        }
    }

    /// Cpp constant for Swift
    public var int32Value: Int32 {
        Int32(int8Value)
    }

    public init?(value: Int32) {
        switch value {
            case Self.bmp280.int32Value: self = .bmp280
            case Self.bme280.int32Value: self = .bme280
            default: return nil
        }
    }

    public init?(board: OpaquePointer?) {
        let device = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_BAROMETER)
        self.init(value: device)
    }
}

// MARK: - Hygrometer

public enum MWHumidityOversampling: Int, CaseIterable, Identifiable {
    case x1 = 1
    case x2 = 2
    case x4 = 4
    case x8 = 8
    case x16 = 16

    public var cppEnumValue: MblMwHumidityBme280Oversampling {
        switch self {
            case .x1: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_1X
            case .x2: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_2X
            case .x4: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_4X
            case .x8: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_8X
            case .x16: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_16X
        }
    }

    public var displayName: String { String(rawValue) }

    public var id: Int { rawValue }

}

// MARK: - GPIO

public enum MWGPIOPullMode: Int, CaseIterable, Identifiable {
    case up
    case down
    case pullNone

    public var cppEnumValue: MblMwGpioPullMode {
        switch self {
            case .up: return MBL_MW_GPIO_PULL_MODE_UP
            case .down: return MBL_MW_GPIO_PULL_MODE_DOWN
            case .pullNone: return MBL_MW_GPIO_PULL_MODE_NONE
        }
    }

    public var id: Int { rawValue }

}

public enum MWGPIOChangeType: Int, CaseIterable, Identifiable {
    case rising
    case falling
    case any

    public var cppEnumValue: MblMwGpioPinChangeType {
        switch self {
            case .rising: return MBL_MW_GPIO_PIN_CHANGE_TYPE_RISING
            case .falling: return MBL_MW_GPIO_PIN_CHANGE_TYPE_FALLING
            case .any: return MBL_MW_GPIO_PIN_CHANGE_TYPE_ANY
        }
    }

    public var displayName: String {
        switch self {
            case .rising: return "Rising"
            case .falling: return "Falling"
            case .any: return "Any"
        }
    }

    init(previous: MWGPIOPullMode, next: MWGPIOPullMode) {
        switch previous {
            case .up:
                switch next {
                    case .pullNone: self = .any
                    case .up: self = .any
                    case .down: self = .falling
                }

            case .down:
                switch next {
                    case .pullNone: self = .any
                    case .up: self = .rising
                    case .down: self = .any
                }

            case .pullNone:
                switch next {
                    case .pullNone: self = .any
                    case .up: self = .rising
                    case .down: self = .falling
                }
        }
    }

    public var id: Int { rawValue }

}

public enum MWGPIOMode: Int, CaseIterable, Identifiable {
    case digital
    case analog

    public var displayName: String {
        switch self {
            case .digital: return "Digital"
            case .analog: return "Analog"
        }
    }

    public var id: Int { rawValue }

}

public enum MWGPIOPin: Int, CaseIterable, Identifiable {
    case zero
    case one
    case two
    case three
    case four
    case five

    public var pinValue: UInt8 { UInt8(rawValue) }

    public var displayName: String { String(rawValue) }

    public var isReadable: Bool { return true } // Not the case

    public var id: Int { rawValue }

}

// MARK: - I2C

public enum MWI2CSize: Int, CaseIterable, Identifiable {
    case byte
    case word
    case dword

    public var length: UInt8 {
        switch self {
            case .byte: return 1
            case .word: return 2
            case .dword: return 4
        }
    }

    public var displayName: String {
        switch self {
            case .byte: return "byte"
            case .word: return "word"
            case .dword: return "dword"
        }
    }

    public var id: Int { rawValue }
}


// MARK: - Sensor Fusion

public enum MWSensorFusionOutputType: Int, CaseIterable, Identifiable {
    case eulerAngles
    case quaternion
    case gravity
    case linearAcceleration

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

    public var fullName: String {
        switch self {
            case .eulerAngles: return "Euler Angles"
            case .quaternion: return "Quaternion"
            case .gravity: return "Gravity"
            case .linearAcceleration: return "Linear Acceleration"
        }
    }

    public var shortFileName: String {
        switch self {
            case .eulerAngles: return "Euler"
            case .quaternion: return "Quaternion"
            case .gravity: return "Gravity"
            case .linearAcceleration: return "LinearAcc"
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

    public var id: Int { rawValue }

}

public enum MWSensorFusionMode: Int, CaseIterable, Identifiable {
    case ndof
    case imuplus
    case compass
    case m4g

    var cppValue: UInt32 { UInt32(rawValue + 1) }

    var cppMode: MblMwSensorFusionMode { MblMwSensorFusionMode(cppValue) }

    var displayName: String {
        switch self {
            case .ndof: return "NDoF"
            case .imuplus: return "IMUPlus"
            case .compass: return "Compass"
            case .m4g: return "M4G"
        }
    }

    public var id: Int { rawValue }

}

// MARK: - Temperature

public enum MWTemperatureSource: Int, CaseIterable, Identifiable {
    case onDie
    case external
    case bmp280
    case onboard
    case custom

    init(cpp: MblMwTemperatureSource) {
        self = Self.allCases.first(where: { $0.cppValue == cpp }) ?? .custom
    }

    var cppValue: MblMwTemperatureSource? {
        switch self {
            case .onDie: return MBL_MW_TEMPERATURE_SOURCE_NRF_DIE
            case .external: return MBL_MW_TEMPERATURE_SOURCE_EXT_THERM
            case .bmp280: return MBL_MW_TEMPERATURE_SOURCE_BMP280
            case .onboard: return MBL_MW_TEMPERATURE_SOURCE_PRESET_THERM
            case .custom: return nil
        }
    }

    var displayName: String {
        switch self {
            case .onDie: return "On-Die"
            case .external: return "External"
            case .bmp280: return "BMP280"
            case .onboard: return "Onboard"
            case .custom: return "Custom"
        }
    }

    public var id: Int { rawValue }

}
