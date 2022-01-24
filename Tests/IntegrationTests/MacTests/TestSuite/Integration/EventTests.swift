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

    /// Remember to manually tap button to observe LED flashes (up = purple, down = blue)
    func test_MacroEventRecording_LEDFlashOnButtonUpDown() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
            // Act
                .command(.macroStartRecording(runOnStartup: true))
                .recordEvents(for: .buttonUp, { recording in
                    recording.command(.ledFlash(.Presets.eight.pattern))
                })
                .recordEvents(for: .buttonDown, { recording in
                    recording.command(.ledFlash(.Presets.zero.pattern))
                })
                .command(.macroStopRecordingAndGenerateIdentifier)
            // Assert
                .handleEvents(receiveOutput: { macroId in
                    XCTAssertEqual(Int(macroId.result), 0)
                })
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .map { _ in metawear }
            // Cleanup
                .command(.resetActivities)
                .command(.macroEraseAll)
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    /// Remember to manually tap the button and observe for LED flashes (PURPLE)
    func testEventRecording_MechanicalButtonUp() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
                .recordEvents(for: .buttonUp, { recording in
                    recording.command(.ledFlash(.Presets.eight.pattern))
                })
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
            // Cleanup
                .map { _ in metawear }
                .command(.resetActivities)
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    /// Remember to manually tap the button and observe for LED flashes (BLUE)
    func testEventRecording_MechanicalButtonDown() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
                .recordEvents(for: .buttonDown, { recording in
                    recording.command(.ledFlash(.Presets.zero.pattern))
                })
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
            // Cleanup
                .map { _ in metawear }
                .command(.resetActivities)
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
