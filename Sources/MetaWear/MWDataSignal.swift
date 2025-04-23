//
//  DataSignal.swift
//  MetaWear
//
//  Created by Laura Kassovic on 10/11/24.
//
import Foundation
import CoreBluetooth
import Combine

// MARK: - DataInterpreter Enum
enum DataInterpreter: UInt8 {
    case INT32 = 0
    case UINT32
    case TEMPERATURE
    case BOSCH_PRESSURE
    case BOSCH_ALTITUDE
    case BOSCH_ROTATION
    case BOSCH_ROTATION_SINGLE_AXIS
    case BOSCH_ACCELERATION
    case BOSCH_ACCELERATION_SINGLE_AXIS
    case MMA8452Q_ACCELERATION
    case MMA8452Q_ACCELERATION_SINGLE_AXIS
    case BYTE_ARRAY
    case BMM150_B_FIELD
    case BMM150_B_FIELD_SINGLE_AXIS
    case SETTINGS_BATTERY_STATE
    case TCS34725_COLOR_ADC
    case BME280_HUMIDITY
    case Q16_16_FIXED_POINT
    case BOSCH_ROTATION_UNSIGNED_SINGLE_AXIS
    case BOSCH_ACCELERATION_UNSIGNED_SINGLE_AXIS
    case MMA8452Q_ACCELERATION_UNSIGNED_SINGLE_AXIS
    case BMM150_B_FIELD_UNSIGNED_SINGLE_AXIS
    case SENSOR_FUSION_QUATERNION
    case SENSOR_FUSION_EULER_ANGLE
    case SENSOR_FUSION_CORRECTED_FLOAT_VECTOR3
    case SENSOR_FUSION_FLOAT_VECTOR3
    case SENSOR_FUSION_CORRECTED_ACC
    case DEBUG_OVERFLOW_STATE
    case SENSOR_ORIENTATION
    case MAC_ADDRESS
    case SENSOR_ORIENTATION_MMA8452Q
    case LOGGING_TIME
    case BTLE_ADDRESS
    case BOSCH_ANY_MOTION
    case SENSOR_FUSION_CALIB_STATE
    case FUSED_DATA
    case BOSCH_TAP
    case BMI270_GESTURE
    case BMI270_ACTIVITY
}

// MARK: - FirmwareConverter Enum
enum FirmwareConverter: UInt8 {
    case DEFAULT = 0
    case BME280_HUMIDITY
    case BOSCH_ACCELERATION
    case BOSCH_BAROMETER
    case BOSCH_ROTATION
    case MMA8452Q_ACCELERATION
    case TEMPERATURE
    case Q16_16_FIXED_POINT
    case BOSCH_MAGNETOMETER
}

struct ResponseHeader: Hashable {
    var moduleID: UInt8
    var registerID: UInt8
    var dataID: UInt8?

    private let SILENT_MASK: UInt8 = 0x40
    private let READ_MASK: UInt8 = 0x80
    private let NO_DATA_ID: UInt8 = 0xFF
    
    //init state stream TODO?
    
    init(moduleID: UInt8, registerID: UInt8) {
        self.moduleID = moduleID
        self.registerID = registerID
    }
    
    init(moduleID: UInt8, registerID: UInt8, dataID: UInt8? = nil) {
        self.moduleID = moduleID
        self.registerID = registerID
        self.dataID = dataID
    }
    
    init(responseHeader: ResponseHeader) {
        self.moduleID = responseHeader.moduleID
        self.registerID = responseHeader.registerID
        self.dataID = responseHeader.dataID
    }

    mutating func disableSilent() {
        registerID &= ~SILENT_MASK
    }

    mutating func enableSilent() {
        registerID |= SILENT_MASK
    }

    mutating func markReadable() {
        registerID |= READ_MASK
    }

    mutating func markUnreadable() {
        registerID &= ~READ_MASK
    }

    func isReadable() -> Bool {
        return (READ_MASK & registerID) == READ_MASK
    }

    func hasDataID() -> Bool {
        return dataID == NO_DATA_ID
    }
    
    // Helper function to mimic the COMPARE macro
    private func compare(_ lhs: UInt8, _ rhs: UInt8) -> Int {
        return lhs > rhs ? 1 : (lhs == rhs ? 0 : -1)
    }

    // Custom < operator
    static func < (lhs: ResponseHeader, rhs: ResponseHeader) -> Bool {
        return lhs.compare(lhs.moduleID, rhs.moduleID) * 4 +
               lhs.compare(lhs.registerID, rhs.registerID) * 2 +
               lhs.compare(lhs.dataID!, rhs.dataID!) < 0
    }

    // Serialization method
    func serialize() -> [UInt8] {
        return [moduleID, registerID, dataID!]
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(moduleID)
        hasher.combine(registerID)
        hasher.combine(dataID)
    }
}

extension ResponseHeader {
    /// Returns the expected Bluetooth characteristic UUID for this response header.
    var characteristicUUID: CBUUID {
        switch moduleID {
        case Module.button.byte:
            return CBUUID(string: "326A9006-85CB-9195-D9DD-464CFBBAE75A")
        case Module.accelerometer.byte:
            return CBUUID(string: "326A9006-85CB-9195-D9DD-464CFBBAE75A")
        case Module.temperature.byte:
            return CBUUID(string: "326A9006-85CB-9195-D9DD-464CFBBAE75A")
        //case Module.battery.byte:
        //    return CBUUID(string: "180F")
        //case Module.deviceInfo.byte:
        //    return CBUUID(string: "180A")
        default:
            fatalError("Unknown characteristic mapping for moduleID: \(moduleID)")
        }
    }
}

// MARK: - DataSignal Class
public class MWDataSignal {
    var header: ResponseHeader
    var interpreter: DataInterpreter
    var converter: FirmwareConverter?
    var nChannels: UInt8?
    var channelSize: UInt8?
    var isSigned: Bool?
    var offset: UInt8?
        
    var components: [MWDataSignal] = []
    var handler: ((Data) -> Void)?
    weak var owner: MWBoard?
        
    // MARK: - Initializers
    // init state stream
    // init event
    init(header: ResponseHeader, owner: MWBoard, interpreter: DataInterpreter) {
        self.header = header
        self.owner = owner
        self.interpreter = interpreter
    }
    
    init(header: ResponseHeader, owner: MWBoard, interpreter: DataInterpreter, nChannels: UInt8, channelSize: UInt8, isSigned: Bool, offset: UInt8) {
        self.header = header
        self.owner = owner
        self.interpreter = interpreter
        self.nChannels = nChannels
        self.channelSize = channelSize
        self.isSigned = isSigned
        self.offset = offset
    }
    
    init(header: ResponseHeader, owner: MWBoard, interpreter: DataInterpreter, converter: FirmwareConverter, nChannels: UInt8, channelSize: UInt8, isSigned: Bool, offset: UInt8) {
        self.header = header
        self.interpreter = interpreter
        self.converter = converter
        self.nChannels = nChannels
        self.channelSize = channelSize
        self.isSigned = isSigned
        self.offset = offset
        self.owner = owner
    }
    
    // MARK: - Subscription Handling
    // mbl_mw_datasignal_subscribe
    func subscribe() {
        if header.isReadable() {
            header.disableSilent()
        } else {
            if countSubscribers(for: self) == 1 {
                let command: [UInt8] = [header.moduleID, header.registerID, 1]
                let data = Data(command)
                owner?.peripheral?.writeValue(data, for: (owner?.commandCharacteristic)!, type: .withoutResponse)
            }
        }
    }

    // mbl_mw_datasignal_unsubscribe
    func unsubscribe() {
        if header.isReadable() {
            header.enableSilent()
        } else if countSubscribers(for: self) == 0 {
            let command: [UInt8] = [header.moduleID, header.registerID, 0]
            let data = Data(command)
            owner?.peripheral?.writeValue(data, for: (owner?.commandCharacteristic)!, type: .withoutResponse)
        }
    }
    
    // MARK: - Data Read
    // mbl_mw_datasignal_read
    func read() {
        if header.hasDataID() {
            let command: [UInt8] = [header.moduleID, header.registerID]
            let data = Data(command)
            owner?.peripheral?.writeValue(data, for: owner!.commandCharacteristic!, type: .withoutResponse)
        } else {
            let command: [UInt8] = [header.moduleID, header.registerID, header.dataID!]
            let data = Data(command)
            owner?.peripheral?.writeValue(data, for: owner!.commandCharacteristic!, type: .withoutResponse)
        }
    }
    
    // MARK: - Serialization
    func serialize() -> [UInt8] {
        var state: [UInt8] = []
        state.append(contentsOf: [UInt8(interpreter.hashValue), UInt8(converter.hashValue), nChannels!, channelSize!, isSigned! ? 1 : 0, offset!])
        return state
    }

    // MARK: - URI Creation
    func createURI() -> String {
        switch header.moduleID {
        case Module.button.byte:
            return "switch-uri"
        case Module.accelerometer.byte:
            return "accelerometer-uri"
        case Module.temperature.byte:
            return "temperature-uri"
        case Module.gpio.byte:
            return "gpio-uri"
        case Module.dataProcessor.byte:
            return "dataprocessor-state-uri"
        case Module.i2c.byte:
            return "i2c-uri"
        case Module.settings.byte:
            return "settings-uri"
        case Module.barometer.byte:
            return "barometer-uri"
        case Module.gyro.byte:
            return "gyro-uri"
        case Module.ambientLight.byte:
            return "ambient-light-uri"
        case Module.magnetometer.byte:
            return "magnetometer-uri"
        case Module.humidity.byte:
            return "humidity-uri"
        case Module.colorDetector.byte:
            return "color-detector-uri"
        case Module.proximity.byte:
            return "proximity-uri"
        case Module.sensorFusion.byte:
            return "sensor-fusion-uri"
        default:
            return "unknown-uri"
        }
    }

    // MARK: - Helpers
    func length() -> UInt8 {
        return (nChannels ?? 0) * (channelSize ?? 0)
    }

    func getDataUByte() -> UInt8 {
        return ((length() - 1) << 5) | offset!
    }

    func setChannelAttributes(nChannels: UInt8, channelSize: UInt8) {
        self.nChannels = nChannels
        self.channelSize = channelSize
    }

    func makeSigned() {
        isSigned = true

        switch interpreter {
        case .UINT32:
            interpreter = .INT32
        case .BOSCH_ROTATION_UNSIGNED_SINGLE_AXIS:
            interpreter = .BOSCH_ROTATION_SINGLE_AXIS
        case .BOSCH_ACCELERATION_UNSIGNED_SINGLE_AXIS:
            interpreter = .BOSCH_ACCELERATION_SINGLE_AXIS
        case .MMA8452Q_ACCELERATION_UNSIGNED_SINGLE_AXIS:
            interpreter = .MMA8452Q_ACCELERATION_SINGLE_AXIS
        case .BMM150_B_FIELD_UNSIGNED_SINGLE_AXIS:
            interpreter = .BMM150_B_FIELD_SINGLE_AXIS
        case .BOSCH_PRESSURE:
            interpreter = .BOSCH_ALTITUDE
        default:
            break
        }
    }
    
    func makeUnsigned() {
        isSigned = false

        switch interpreter {
        case .INT32:
            interpreter = .UINT32
        case .BOSCH_ROTATION_SINGLE_AXIS:
            interpreter = .BOSCH_ROTATION_UNSIGNED_SINGLE_AXIS
        case .BOSCH_ACCELERATION_SINGLE_AXIS:
            interpreter = .BOSCH_ACCELERATION_UNSIGNED_SINGLE_AXIS
        case .MMA8452Q_ACCELERATION_SINGLE_AXIS:
            interpreter = .MMA8452Q_ACCELERATION_UNSIGNED_SINGLE_AXIS
        case .BMM150_B_FIELD_SINGLE_AXIS:
            interpreter = .BMM150_B_FIELD_UNSIGNED_SINGLE_AXIS
        case .BOSCH_ALTITUDE:
            interpreter = .BOSCH_PRESSURE
        default:
            break
        }
    }
    
    func countSubscribers(for signal: MWDataSignal) -> UInt8 {
        // Retrieve the root signal from the owner's module events dictionary
        guard let root = signal.owner?.moduleEvents[signal.header] as? MWDataSignal else {
            return 0
        }

        // Start with a count of 1 if the root has a handler, otherwise 0
        var count: UInt8 = root.handler == nil ? 0 : 1

        // Add 1 for each component with a non-nil handler
        for component in root.components {
            if component.handler != nil {
                count += 1
            }
        }
        
        return count
    }
    
}
