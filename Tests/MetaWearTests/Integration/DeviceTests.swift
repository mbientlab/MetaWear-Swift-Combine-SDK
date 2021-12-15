// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class DeviceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.S_A4)
    }

    // MARK: - Reset

    func test_QuickDebugReset() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish().factoryReset()._sinkNoFailure(&subs)
            exp.fulfill()
        }
    }

    func test_FactoryReset() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            var lastReset = Date()
            var lastResetID = UInt8(0)

            // Act
            metawear.publish()
                .read(.lastResetTime)
                .handleEvents(receiveOutput: { output in 
                    lastReset = output.value.time
                    lastResetID = mbl_mw_logging_get_latest_reset_uid(metawear.board)
                })
                .map { _ in metawear }
                .factoryReset()
                ._sinkNoFailure(&subs)

            // Assert
            metawear
                .publishWhenDisconnected()
                .first()
                .delay(for: 3, tolerance: 0, scheduler: metawear.bleQueue)
                .mapToMWError()
                .flatMap { $0.connectPublisher() }
                ._assertLoggers([], metawear: metawear)
                .read(.lastResetTime)
                ._sinkNoFailure(&subs, finished: {  }) { _, reset in
                    let elapsed = lastReset.distance(to: reset.time) / 1000
                    XCTAssertGreaterThan(elapsed, 0)
                    XCTAssertLessThan(elapsed, .download)
                    XCTAssertGreaterThan(reset.resetID, lastResetID)
                    exp.fulfill()
                }
        }
    }
}
