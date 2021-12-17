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

#warning("Ryan lacks an equipped test device")
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

    // MARK: - REQUIRES MANUALLY WATCHING FOR LED FLASHES

    func test_LEDFlash() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            let sut = MWLED.Flash.Pattern(color: .brown, intensity: 1, repetitions: 10, duration: 500, period: 1000)
            metawear.publish()
                .command(.ledFlash(sut))
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func testCommand_LEDOff() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            // Prepare
            metawear
                .publish()
                .command(.ledFlash(
                    color: .green,
                    intensity: .init(1),
                    repetitions: 10)
                )
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)

            // Act
                .command(.ledOff)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }
}
