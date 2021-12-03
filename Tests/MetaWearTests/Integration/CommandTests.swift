// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class CommandTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useAnyNearbyDevice()
    }

    // MARK: - REQUIRES MANUALLY WATCHING FOR LED FLASHES

    func test_LEDFlash() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.ledFlash(
                    color: .green,
                    intensity: .init(1),
                    repetitions: 10)
                )
                .delay(for: 3, tolerance: 0, scheduler: metawear.apiAccessQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func testCommand_LEDOff() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            // Prepare
            metawear
                .publish()
                .command(.ledFlash(
                    color: .green,
                    intensity: .init(1),
                    repetitions: 10)
                )
                .delay(for: 1, tolerance: 0, scheduler: metawear.apiAccessQueue)

            // Act
                .command(.ledOff)
                .delay(for: 2, tolerance: 0, scheduler: metawear.apiAccessQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }
}
