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

    func testRemoveEvents_NoFailure() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
                .command(.resetActivities) // No values to assert
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    /// Remember to manually tap the button and observe for LED flashes (PURPLE)
    func testEventRecording_MechanicalButtonUp() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
                .recordEvents(for: .buttonUp, { recording in
                    recording.command(.led(groupIndex: 9))
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
                    recording.command(.led(groupPreset: .zero))
                })
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
            // Cleanup
                .map { _ in metawear }
                .command(.resetActivities)
                ._sinkNoFailure(&subs, finished: {}, receiveValue: { _ in exp.fulfill() })
        }
    }

    /// Remember to manually tap button to observe LED flashes (up = purple, down = blue)
    func test_MacroEventRecording_LEDFlashOnButtonUpDown() {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            metawear
                .publish()
            // Act
                .command(.macroStartRecording(runOnStartup: true))
                .recordEvents(for: .buttonUp, { recording in
                    recording.command(.led(.blue, .pulse(repetitions: 2)))
                })
                .recordEvents(for: .buttonDown, { recording in
                    recording.command(.led(.purple, .pulse(repetitions: 2)))
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

    func test_EventTimeThrottling_SlowSensorFusion_Download_AbstractedConstruction() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            let mockCachedDate = Date()

            metawear
                .publishWhenConnected()
            // Act
                .log(.sensorFusionEulerAngles(mode: .ndof)) { signal in
                    signal.throttleData(mode: .passthrough, rate: .hz1)
                }
            // Assert
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLogs(startDate: mockCachedDate)
                .drop(while: { $0.percentComplete < 1 })
                .map(\.data)
                ._sinkNoFailure(&subs, finished: { }) { dataTables in
                    let rowCount = dataTables.first?.rows.endIndex ?? 0
                    XCTAssertEqual(rowCount, 10, accuracy: 2)
                    exp.fulfill()
                }
        }
    }

    func test_EventTimeThrottling_SlowSensorFusion_Download_PointerConstruction() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: true) { metawear, exp, subs in
            let mockCachedDate = Date()

            metawear
                .publish()
            // Act
                .getLoggerMutablePointer(.sensorFusionEulerAngles(mode: .ndof))
                .throttleData(mode: .passthrough, rate: .hz1)
                .logUpstreamPointer(
                    ofType: .sensorFusionEulerAngles(mode: .ndof),
                    board: metawear.board,
                    overwriting: false,
                    startImmediately: true
                )
            // Assert
                .handleEvents(receiveOutput: { output in
                    XCTAssertEqual(output.id, .eulerAngles)
                })
                .map { _ in metawear }
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLogs(startDate: mockCachedDate)
                .drop(while: { $0.percentComplete < 1 })
                .map(\.data)
                ._sinkNoFailure(&subs, finished: { }) { dataTables in
                    let rowCount = dataTables.first?.rows.endIndex ?? 0
                    XCTAssertEqual(rowCount, 10, accuracy: 2)
                    exp.fulfill()
                }
        }
    }
}
