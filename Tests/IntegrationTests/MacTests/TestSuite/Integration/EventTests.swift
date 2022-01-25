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

    static func makeThrottledSensorFusionSUT(_ metawear: MetaWear) throws
    -> AnyPublisher<MetaWear, MWError> {

        let config = MWSensorFusion.EulerAngles(mode: .ndof)

        config.loggerConfigure(board: metawear.board)

        guard let eulerSignal = try config.loggerDataSignal(board: metawear.board)
        else { fatalError() }

        let throttled = eulerSignal
            .throttled(mode: .noMutation, rate: .hz1)
            .eraseToAnyPublisher()

        return metawear
            .publish()
            .flatMap { _ in throttled }
            .log(board: metawear.board,
                 overwriting: false,
                 startImmediately: true,
                 start: { config.loggerStart(board: metawear.board) }
            )
            .map { loggerID in print("-> ", loggerID); return metawear }
            .eraseToAnyPublisher()
    }

    func test_EventTimer_SlowSensorFusion_Download() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            // Arrange
            let mockCachedDate = Date()
            let sut = try Self.makeThrottledSensorFusionSUT(metawear)

            sut
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLogs(startDate: mockCachedDate)
                .drop(while: { $0.percentComplete < 1 })
                .map(\.data)
                ._sinkNoFailure(&subs, finished: { }) { dataTables in
                    XCTAssertGreaterThan(dataTables.first?.rows.endIndex ?? 0, 0)
                    XCTAssertLessThanOrEqual(dataTables.first?.rows.endIndex ?? 0, 10)
                    exp.fulfill()
                }
        }
    }

    func test_EventTimer_SlowSensorFusion_ReadLength() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            // Arrange
            let sut = try Self.makeThrottledSensorFusionSUT(metawear)

            sut
            // Assert
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)
                .read(.logLength)
                ._sinkNoFailure(&subs, finished: { }) { bytes in
                    XCTAssertGreaterThan(bytes.value, 1)
                    exp.fulfill()
                }
        }
    }

    func test_EventTimer_SlowSensorFusion_VerifySignals() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            let sut = try Self.makeThrottledSensorFusionSUT(metawear)

            sut
            // Assert
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)
                ._assertLoggers([.eulerAngles], metawear: metawear)
                ._sinkNoFailure(&subs, finished: { }) { _ in exp.fulfill() }
        }
    }
}
