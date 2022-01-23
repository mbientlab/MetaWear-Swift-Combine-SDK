// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class EventTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.metamotionS)
    }

    /// Remember to manually tap the button and observe for LED flashes (PURPLE)
    func testEventRecording_MechanicalButtonUp() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
            // Act
                .recordEventsOnButtonUp { record in
                    record.command(.ledFlash(.Presets.eight.pattern))
                }
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    /// Remember to manually tap the button and observe for LED flashes (BLUE)
    func testEventRecording_MechanicalButtonDown() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
            // Act
                .recordEventsOnButtonDown { record in
                    record.command(.ledFlash(.Presets.zero.pattern))
                }
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    func testRemoveEvents() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
            // Act
                .command(.resetActivities)
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }
}
