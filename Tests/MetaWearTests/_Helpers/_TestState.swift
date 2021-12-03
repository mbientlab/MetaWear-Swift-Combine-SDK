// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
@testable import MetaWear

// MARK: - Your Local MetaWears

/// Specify a local device with capabilities that match your test function requirements by using your current machine's CBUUID.
enum TestDevices: String {
    case S_A4  = "89683858-2908-5016-24FA-AD30465633C2" // E2:ED:DF:1A:1A:A4 // No Orientation (has BMI160)
    case RL_BE = "931C9F87-18F8-02E3-D2B4-31E9E3D34D92" // FF:9F:C6:B8:89:BE
    case RL_A9 = ""

    /// Device that test methods will run on (or, if nil, any random device)
    static fileprivate(set) var current: TestDevices? = nil

    /// Ensure tests run on the device of choice
    static func useOnly(_ device: TestDevices) { current = device }

    /// Run tests on a random (first detected) device
    static func useAnyNearbyDevice() { current = nil }
}

let minimumRSSI = -75

// MARK: - Timing

extension TimeInterval {
    static let read: TimeInterval = 20
    static let download: TimeInterval = 60
}


// MARK: - Shared Scanner

let scanner = MetaWearScanner.sharedRestore
