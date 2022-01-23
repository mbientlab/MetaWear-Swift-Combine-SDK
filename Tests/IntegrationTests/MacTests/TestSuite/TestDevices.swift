// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import SwiftCombineSDKTestHost
@testable import MetaWear

// MARK: - Configure Tests for Your Local MetaWears

extension TestDevices {

    /// Designate a stable of known devices to use
    static var machine: HostMachine = .RyanMacMini

}

extension TestDevices {

    /// Restricts tests to run on one device (or, if nil, any random device)
    static fileprivate(set) var current: TestDevices? = nil

    /// Restrict tests to one device
    static func useOnly(_ device: TestDevices) { current = device }

    /// Run tests on a random (first detected) device
    static func useAnyNearbyDevice() { current = nil }
}


// MARK: - Configure Connection Constraints

/// Will not connect to devices with lower RSSI
let minimumRSSI = -75

/// Test timeout walls
extension TimeInterval {
    static let read: TimeInterval = 20
    static let download: TimeInterval = 60
}


// MARK: - Implementation Details

enum TestDevices {
    case metamotionS
    case metamotionRL

    /// Stables of known devices
    enum HostMachine {
        case RyanMacBook
        case RyanMacMini
        case Laura

        var localDevices: LocalDevices {
            switch self {
                case .RyanMacMini: return LocalDevices(
                    s:  "89683858-2908-5016-24FA-AD30465633C2", // E2:ED:DF:1A:1A:A4 // No Orientation, Steps (BMI 270)
                    rl: "931C9F87-18F8-02E3-D2B4-31E9E3D34D92"  // FF:9F:C6:B8:89:BE // No Ambient, Baro (BMI 160)
                )
                case .RyanMacBook: return LocalDevices(
                    s:  "62ED70A8-0BEC-DB6B-D720-D825FEEFCDF1", // E2:ED:DF:1A:1A:A4 // No Orientation, Steps (BMI 270)
                    rl: "208541A1-4094-8729-D138-E74B6F43CEC6"  // FF:9F:C6:B8:89:BE // No Ambient, Baro (BMI 160)
                )
                case .Laura: fatalError("Setup yours")
            }
        }
    }

    struct LocalDevices {
        let s: String
        let rl: String
    }

    func getTestTargetLocalUUID() -> String {
        switch self {
            case .metamotionS: return TestDevices.machine.localDevices.s
            case .metamotionRL: return TestDevices.machine.localDevices.rl
        }
    }
}

