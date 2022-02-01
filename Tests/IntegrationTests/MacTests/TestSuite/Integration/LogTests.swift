// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class LogTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.metamotionS)
    }

    // MARK: - Multiple

    func test_LogThenDownload_TwoSensors_AccelerometerMagnetometer() {
        _testLog2(
            .accelerometer(rate: .hz50, gravity: .g2),
            .magnetometer(rate: .hz25)
        )
    }

    // MARK: - Related Reads

    func test_Read_LogLength_WhenCleared() {
        connectNearbyMetaWear(timeout: .read, useLogger: false) { metawear, exp, subs in
            // Prepare
            metawear.publish()
                .command(.deleteLoggedData)
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)

            // Act
                .read(.logLength)

            // Assert
                ._sinkNoFailure(&subs, receiveValue: {
                    XCTAssertEqual($0.value, 0)
                    exp.fulfill()
                })
        }
    }

    func test_Read_LogLength_WhenPopulated() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            // Prepare
            let log: some MWLoggable = .accelerometer(rate: .hz50, gravity: .g2)
            
            metawear.publish()
                .command(.deleteLoggedData)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                .log(log)
                ._assertLoggers([log.signalName], metawear: metawear)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)

            // Act
                .read(.logLength)

            // Assert
                .handleEvents(receiveOutput: { output in
                    XCTAssertGreaterThan(output.value, 1)
                })

            // Cleanup
                .map { _ in metawear }
                .command(.resetActivities)
                .command(.deleteLoggedData)
                ._sinkNoFailure(&subs, receiveValue: { _ in  exp.fulfill() })
        }
    }

    // MARK: - Granular Commands

    func test_Logs_SetupWithLazyStart() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let kickoff = metawear.publish()
            kickoff
                ._assertLoggers([], metawear: metawear)

            // ACT I
                .log(.accelerometer(rate: .hz50, gravity: .g16), overwriting: false, startImmediately: false)
                ._assertLoggers([.acceleration], metawear: metawear)
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                .read(.logLength)
            // Assert I
                .handleEvents(receiveOutput: { logLength in
                    XCTAssertEqual(logLength.value, 0)
                })

            // Act II
                .flatMap { _ in kickoff.loggersStart(overwriting: false) }
                .delay(for: 2, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLogs(startDate: .init())
                .drop(while: { $0.percentComplete < 1 })
                ._sinkNoFailure(&subs, #file, #line, finished: { exp.fulfill() }, receiveValue: { output in
            // Assert II
                    XCTAssertGreaterThan(output.data.first?.rows.endIndex ?? 0, 0)
                    exp.fulfill()
                })
        }
    }

    func test_RemovesSpecificLoggers() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let expDeleted = MWAccelerometer(rate: .hz50, gravity: .g16)
            let expRetained = MWGyroscope(rate: .hz50, range: .dps125)

            metawear.publish()
                ._assertLoggers([], metawear: metawear)

            // Arrange
                .log(expDeleted, overwriting: false, startImmediately: false)
                .log(expRetained, overwriting: false, startImmediately: false)
                ._assertLoggers([expDeleted.signalName, expRetained.signalName], metawear: metawear)
                .loggerSignalsCollectAll()
                .compactMap { $0.first(where: { $0.id == expDeleted.signalName })?.log }

            // Act
                .flatMap { loggerSignal in
                    metawear.publish().loggersRemoveAll([loggerSignal])
                }
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                ._assertLoggers([expRetained.signalName], metawear: metawear)

            // Cleanup
                .command(.resetActivities)
                ._sinkNoFailure(&subs, receiveValue: { _ in  exp.fulfill() })
        }
    }

    // MARK: - Single

    func test_NotLogging() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                .loggerSignalsCollectAll()
                ._sinkNoFailure(&subs, finished: {  }, receiveValue: { signals in
                    XCTAssertEqual(signals.map(\.id), [])
                })
        }
    }

    func test_LogThenDownload_Accelerometer() {
        _testLog( .accelerometer(rate: .hz12_5, gravity: .g2) )
    }

    func test_LogThenDownload_AmbientLight() {
        _testLog( .ambientLight(rate: .ms500, gain: .x1, integrationTime: .ms100) )
    }

    func test_LogThenDownload_Altitude() {
        _testLog( .absoluteAltitude(standby: .ms250, iir: .avg2, oversampling: .standard) )
    }

    /// Remember to plug or unplug the device once while logging, otherwise there will be no logged data
    func test_LogThenDownload_ChargingStatus() {
        _testLog( .chargingStatus )
    }

    func test_LogThenDownload_Pressure() {
        _testLog( .relativePressure(standby: .ms250, iir: .avg2, oversampling: .standard) )
    }

    func test_LogThenDownload_Gryoscope() {
        _testLog( .gyroscope(rate: .hz25, range: .dps1000) )
    }

    func test_LogThenDownload_Magnetometer() {
        _testLog( .magnetometer(rate: .hz25) )
    }

    /// Remember to depress the button, otherwise there will be no logged data
    func test_LogThenDownload_MechanicalButton() {
        _testLog( .mechanicalButton )
    }

    func test_LogFakeButtonCommands_MechanicalButton() {
        let testValue = UInt8(4)

        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                ._assertLoggers([], metawear: metawear)
                .log(.mechanicalButton)
                ._assertLoggers([.mechanicalButton], metawear: metawear)
                .share()
                .command(.logUserEvent(flag: testValue))
                .command(.logUserEvent(flag: testValue))
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLog(.mechanicalButton)

            // Assert
                .drop(while: { $0.percentComplete < 1 })
                .map(\.data)
                .handleEvents(receiveOutput: { data in
                    data.map(\.value).forEach {
                        XCTAssertEqual($0, .custom(testValue))
                    }
                    XCTAssertEqual(data.count, 2)
                })
                ._assertLoggers([], metawear: metawear)
                ._sinkNoFailure(&subs, finished: { exp.fulfill() }, receiveValue: { output in exp.fulfill() })
        }
    }

#warning("Await C++ library update for Bosch Motion")
    /// Disabled until C++ library support complete
    //    /// Remember to move
//    func test_LogThenDownload_Motion_ActivityClassification() {
//        _testLog( .motionActivityClassification )
//    }
//
//    /// Remember to move
//    func test_LogThenDownload_Motion_Any() {
//        _testLog( .motionAny )
//    }
//
//    /// Remember to move
//    func test_LogThenDownload_Motion_Significant() {
//        _testLog( .motionSignificant )
//    }
//
//    /// Remember to NOT move
//    func test_LogThenDownload_Motion_None() {
//        _testLog( .motionNone )
//    }

    func test_LogThenDownload_Orientation() {
        TestDevices.useOnly(.metamotionRL)
        _testLog( .orientation )
    }

    func test_LogThenDownload_Orientation_WhenUnsupported() {
        TestDevices.useOnly(.metamotionS)
        _testLog(.orientation, expectFailure: "Operation failed: Orientation requires a BMI160 module, which this device lacks.")
    }

    func test_LogThenDownload_StepDetectionBMI270() {
        XCTExpectFailure("Log StepsDetection: Empty logger name string")
        TestDevices.useOnly(.metamotionS)
        _testLog( .stepDetector(sensitivity: .sensitive) )
    }

    func test_LogThenDownload_StepDetectionBMI160() {
        XCTExpectFailure("Log StepsDetection: Empty logger name string")
        TestDevices.useOnly(.metamotionRL)
        _testLog( .stepDetector(sensitivity: .sensitive) )
    }

    func test_LogThenDownload_StepCounterBMI270() {
        XCTExpectFailure("Log StepsCounter: Empty logger name string")
        TestDevices.useOnly(.metamotionS)
        _testLog( .stepCounter(sensitivity: .sensitive) )
    }

    func test_LogThenDownload_StepCounterBMI160() {
        XCTExpectFailure("Log StepsCounter: Empty logger name string")
        TestDevices.useOnly(.metamotionRL)
        _testLog( .stepCounter(sensitivity: .sensitive) )
    }

    // MARK: - Pollable

    func test_LogThenDownload_Temperature() throws {
        _testLog(byPolling: {
            try! MWThermometer(rate: .init(hz: 1), type: .onboard, board: $0.board)
        })
    }

    func test_LogThenDownload_Humidity() throws {
        _testLog(byPolling: { _ in .humidity() })
    }
}

extension XCTestCase {

    func _testLog<P: MWPollable>(byPolling sut: @escaping (MetaWear) -> P, file: StaticString = #file, line: UInt = #line, expectFailure: String? = nil) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let _sut = sut(metawear)
            let date = Date()

            metawear.publish()
            // Assert there are no loggers active right now
                ._assertLoggers([], metawear: metawear, file, line)
            // Act Part I
                .log(byPolling: _sut)
            // Assert there is now the logger intended
                ._assertLoggers([_sut.signalName], metawear: metawear, file, line)
            // Ensure pipeline is idemmnopotent, passed as reference
                .share()
            // Let it log
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
            // Act Part II
                .downloadLogs(startDate: date)
            // Assert Part II
                .handleEvents(receiveOutput: { data, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(data.isEmpty, file: file, line: line) }
                    guard percentComplete == 1.0 else { return }
                    // Assert log obtains data
                    XCTAssertEqual(data.endIndex, 1, file: file, line: line)
                    XCTAssertGreaterThan(data.first?.rows.endIndex ?? 0, 0, file: file, line: line)
                    XCTAssertEqual(data.first?.source, _sut.signalName)
                })

            // Skip any updates before complete
            // Assert no loggers after download completes
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear, file, line)

            // Assert completes without error. Call .fulfill to end the test before the timeout period.
                ._sinkNoFailure(&subs, file, line, receiveValue: { value in print(value); exp.fulfill() })
        }
    }

    func _testLog<L: MWLoggable>(_ sut: L, file: StaticString = #file, line: UInt = #line, expectFailure: String? = nil) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let start = Date()

            let pipline = metawear.publish()
            // Assert there are no loggers active right now
                ._assertLoggers([], metawear: metawear, file, line)
            // Act
                .log(sut)
            // Assert there is now the logger intended
                ._assertLoggers([sut.signalName], metawear: metawear, file, line)
            // Ensure pipeline is idemmnopotent, passed as reference
                .share()
            // Let it log
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
            // Act
                .downloadLog(sut)

            // Assert
                .handleEvents(receiveOutput: { data, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(data.isEmpty, file: file, line: line) }
                    guard percentComplete == 1.0 else { return }
                    // Assert log obtains data
                    XCTAssertGreaterThan(data.endIndex, 0, file: file, line: line)
                    XCTAssertGreaterThan(start.distance(to: data.last!.time), 4)
                })

            // Skip any updates before complete
            // Assert no loggers after download completes
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear, file, line)

            // Assert completes without error. Call .fulfill to end the test before the timeout period.
            if let message = expectFailure {
                pipline._sinkExpectFailure(&subs, file, line, exp: exp, errorMessage: message)
            } else {
                pipline._sinkNoFailure(&subs, file, line, finished: { exp.fulfill() }, receiveValue: { output in exp.fulfill() })
            }
        }
    }

    func _testLog2<L1: MWLoggable, L2: MWLoggable>(_ sut1: L1, _ sut2: L2, file: StaticString = #file, line: UInt = #line) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let date = Date()
            metawear.publish()
            // Assert there are no loggers active right now
                ._assertLoggers([], metawear: metawear, file, line)
            // Act
                .log(sut1)
                .log(sut2)
            // Assert there is now the two loggers intended
                ._assertLoggers([sut1.signalName, sut2.signalName], metawear: metawear, file, line)
            // Ensure pipeline is idemmnopotent, passed as reference
                .share()
            // Let it log
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
            // Act
                .downloadLogs(startDate: date)

            // Assert
                .handleEvents(receiveOutput: { tables, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(tables.isEmpty, file: file, line: line) }
                    guard percentComplete == 1 else { return }

                    // Assert all dates are unique
                    tables.forEach { table in
                        let epochs = Set(table.rows.compactMap(\.first))
                        let dates = Set(table.rows.map { $0[1] })
                        let elapses = Set(table.rows.map { $0[2] })
                        XCTAssertTrue(epochs.count == table.rows.endIndex, table.source.name)
                        XCTAssertTrue(dates.count == table.rows.endIndex, table.source.name)
                        XCTAssertTrue(elapses.count == table.rows.endIndex, table.source.name)
                    }

                    // Assert both logs contain expected data, labeled for that logger
                    XCTAssertEqual(tables.endIndex, 2, file: file, line: line)
                    XCTAssertEqual(Set(tables.map(\.source)), Set([sut1.signalName, sut2.signalName]), file: file, line: line)
                    XCTAssertTrue(tables.allSatisfy({ $0.rows.isEmpty == false }), file: file, line: line)
                })

            // Skip any updates before complete
            // Assert no loggers after download completes
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear, file, line)

            // Assert completes without error. Call .fulfill to end the test before the timeout period.
                ._sinkNoFailure(&subs, file, line, receiveValue: { _ in exp.fulfill() })
        }
    }
}
