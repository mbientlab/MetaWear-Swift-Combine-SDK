// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class CommandTests: XCTestCase {

    func test_HapticMotor_Weak() {
        TestDevices.useOnly(.metamotionRL)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear.publish()
                .command(.buzzMMR(milliseconds: 1000, percentStrength: 0.35))
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_HapticMotor_Strong() {
        TestDevices.useOnly(.metamotionRL)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear.publish()
                .command(.buzzMMR(milliseconds: 500, percentStrength: 1))
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_Buzzer() {
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear.publish()
                .command(.buzz(milliseconds: 50))
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_Rename() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            let existingName = metawear.name
            let expName = "RENAMED"
            metawear.publish()
                .command(try! .rename(advertisingName: expName))
                .delay(for: 3, tolerance: 0, scheduler: metawear.bleQueue)
                .handleEvents(receiveOutput: { metawear in
                    metawear.disconnect()
                    metawear.bleQueue.asyncAfter(deadline: .now() + 1) {
                        metawear.connect()
                    }
                })
                .delay(for: 30, tolerance: 0, scheduler: metawear.bleQueue)
                .handleEvents(receiveOutput: { output in
                    XCTAssertEqual(expName, output.name)
                })
                .command(try! .rename(advertisingName: existingName))
                .delay(for: 3, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { output in
                    XCTAssertEqual(existingName, output.name)
                    exp.fulfill()
                })
        }
    }

    func test_PowerDownSensors() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear
                .publish()
                ._assertLoggers([], metawear: metawear)
                .log(.accelerometer(rate: .hz50, gravity: .g16), overwriting: false)
                ._assertLoggers([.acceleration], metawear: metawear)
            // Act
                .command(.powerDownSensors)
            // Assert
                .command(.deleteLoggedData)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                .read(.logLength)
                ._sinkNoFailure(&subs, #file, #line, finished: { }, receiveValue: { logLength in
                    XCTAssertEqual(logLength.value, 0)
                    exp.fulfill()
                })
        }
    }

    // MARK: - REQUIRES MANUALLY WATCHING FOR LED FLASHES

    func test_LED_EaseInOut() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.purple, .easeInOut(repetitions: 5) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_LED_Pulse() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.orange, .pulse(repetitions: 5) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_LED_Blink() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.blue, .blink(repetitions: 5) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }


    func test_LED_BlinkQuickly() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.green, .blinkQuickly(repetitions: 5) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_LED_BlinkInfrequently() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.blue, .blinkInfrequently(repetitions: 5) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_LED_BlinkSlowly_RaisedLowIntensityMode() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear.publish()
                .command(.led(.red, .blink(repetitions: 5, lowIntensity: 0.25) ))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .command(.ledOff)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func testCommand_Solid_LEDOff() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            // Prepare
            metawear
                .publish()
                .command(.led(.yellow, .solid()))
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)

            // Act
                .command(.ledOff)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }
}
