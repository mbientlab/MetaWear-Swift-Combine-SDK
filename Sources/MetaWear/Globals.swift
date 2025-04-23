//
//  Globals.swift
//  MetaWear
//
//  Created by Laura Kassovic on 3/8/25.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Constants
/// The size of a Cartesian Float
let CARTESIAN_FLOAT_SIZE: UInt8 = 6
/// Maximum time allowed per response in milliseconds
let MAX_TIME_PER_RESPONSE: UInt16 = 4000

let disCharacteristicUUIDs: [CBUUID] = [
    .disManufacturerName,
    .disSerialNumber,
    .disHardwareRev,
    .disFirmwareRev,
    .disModelNumber
]

// MARK: - Module Addresses
enum Module: UInt8 {
    case button         = 0x1
    case led            = 0x2
    case accelerometer  = 0x3
    case temperature    = 0x4
    case gpio           = 0x5
    case neoPixel       = 0x6
    case ibeacon        = 0x7
    case haptic         = 0x8
    case dataProcessor  = 0x9
    case event          = 0xA
    case logging        = 0xB
    case timer          = 0xC
    case i2c            = 0xD
    case macro          = 0xF
    case conductance    = 0x10
    case settings       = 0x11
    case barometer      = 0x12
    case gyro           = 0x13
    case ambientLight   = 0x14
    case magnetometer   = 0x15
    case humidity       = 0x16
    case colorDetector  = 0x17
    case proximity      = 0x18
    case sensorFusion   = 0x19
    case debug          = 0xFE
    
    var byte: UInt8 { self.rawValue }
}

func READ_REGISTER(_ x: UInt8) -> UInt8 {
    return 0x80 | x
}

let READ_INFO_REGISTER: UInt8 = READ_REGISTER(0x0)

let MODULE_DISCOVERY_CMDS: [[UInt8]] = [
    [Module.button.byte,        READ_INFO_REGISTER],
    [Module.led.byte,           READ_INFO_REGISTER],
    [Module.accelerometer.byte, READ_INFO_REGISTER],
    [Module.temperature.byte,   READ_INFO_REGISTER],
    [Module.gpio.byte,          READ_INFO_REGISTER],
    [Module.neoPixel.byte,      READ_INFO_REGISTER],
    [Module.ibeacon.byte,       READ_INFO_REGISTER],
    [Module.haptic.byte,        READ_INFO_REGISTER],
    [Module.dataProcessor.byte, READ_INFO_REGISTER],
    [Module.event.byte,         READ_INFO_REGISTER],
    [Module.logging.byte,       READ_INFO_REGISTER],
    [Module.timer.byte,         READ_INFO_REGISTER],
    [Module.i2c.byte,           READ_INFO_REGISTER],
    [Module.macro.byte,         READ_INFO_REGISTER],
    [Module.conductance.byte,   READ_INFO_REGISTER],
    [Module.settings.byte,      READ_INFO_REGISTER],
    [Module.barometer.byte,     READ_INFO_REGISTER],
    [Module.gyro.byte,          READ_INFO_REGISTER],
    [Module.ambientLight.byte,  READ_INFO_REGISTER],
    [Module.magnetometer.byte,  READ_INFO_REGISTER],
    [Module.humidity.byte,      READ_INFO_REGISTER],
    [Module.colorDetector.byte, READ_INFO_REGISTER],
    [Module.proximity.byte,     READ_INFO_REGISTER],
    [Module.sensorFusion.byte,  READ_INFO_REGISTER],
    [Module.debug.byte,         READ_INFO_REGISTER]
]
