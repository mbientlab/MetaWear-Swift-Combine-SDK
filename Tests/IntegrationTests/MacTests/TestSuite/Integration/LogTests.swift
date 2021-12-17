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

    // MARK: - Single

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
        _testLog( .gyroscope(range: .dps1000, freq: .hz25) )
    }

    func test_LogThenDownload_Magnetometer() {
        _testLog( .magnetometer(freq: .hz25) )
    }

    /// Remember to depress the button, otherwise there will be no logged data
    func test_LogThenDownload_MechanicalButton() {
        _testLog( .mechanicalButton )
    }

    /// Remember to move
    func test_LogThenDownload_Motion_ActivityClassification() {
        _testLog( .motionActivityClassification )
    }

    /// Remember to move
    func test_LogThenDownload_Motion_Any() {
        _testLog( .motionAny )
    }

    /// Remember to move
    func test_LogThenDownload_Motion_Significant() {
        _testLog( .motionSignificant )
    }

    /// Remember to NOT move
    func test_LogThenDownload_Motion_None() {
        _testLog( .motionNone )
    }

    func test_LogThenDownload_Orientation() {
        TestDevices.useOnly(.metamotionRL)
        _testLog( .orientation )
    }

    func test_LogThenDownload_Orientation_WhenUnsupported() {
        TestDevices.useOnly(.metamotionS)
        _testLog(.orientation, expectFailure: "Operation failed: Orientation requires a BMI160 module, which this device lacks.")
    }

#warning("Failing -> Empty logger name string")
    func test_LogThenDownload_StepDetectionBMI270() {
        TestDevices.useOnly(.metamotionS)
        _testLog( .stepDetector(sensitivity: .sensitive) )
    }

#warning("Failing -> Empty logger name string")
    func test_LogThenDownload_StepDetectionBMI160() {
        TestDevices.useOnly(.metamotionRL)
        _testLog( .stepDetector(sensitivity: .sensitive) )
    }

#warning("Failing -> Empty logger name string")
    func test_LogThenDownload_StepCounterBMI270() {
        TestDevices.useOnly(.metamotionS)
        _testLog( .stepCounter(sensitivity: .sensitive) )
    }

#warning("Failing -> Empty logger name string")
    func test_LogThenDownload_StepCounterBMI160() {
        TestDevices.useOnly(.metamotionRL)
        _testLog( .stepCounter(sensitivity: .sensitive) )
    }

    // MARK: - Pollable

#warning("Failing -> Crash")
    func test_LogThenDownload_Temperature() throws {
        _testLog(byPolling: {
            try! MWThermometer(type: .onboard, board: $0.board, rate: .init(hz: 1))
        })
    }

    func test_LogThenDownload_Humidity() throws {
        _testLog(byPolling: { _ in .humidity() })
    }

    // MARK: - Multiple

    func test_LogThenDownload_TwoSensors_AccelerometerMagnetometer() {
        _testLog2(
            .accelerometer(rate: .hz50, gravity: .g2),
            .magnetometer(freq: .hz25)
        )
    }

    // MARK: - Related Reads

    func test_Read_LogLength_WhenCleared() {
        connectNearbyMetaWear(timeout: .read, useLogger: false) { metawear, exp, subs in
            // Prepare
            metawear.publish()
                .deleteLoggedEntries()
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
        let log: some MWLoggable = .accelerometer(rate: .hz50, gravity: .g2)

        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            // Prepare
            metawear.publish()
                .deleteLoggedEntries()
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                .log(log)
                ._assertLoggers([log.signalName], metawear: metawear)
                .delay(for: 10, tolerance: 0, scheduler: metawear.bleQueue)

            // Act
                .read(.logLength)
                .handleEvents(receiveOutput: { output in
                    XCTAssertGreaterThan(output.value, 1)
                })
                .map { _ in metawear }
                .command(.resetActivities)

            // Assert
                ._sinkNoFailure(&subs, receiveValue: { _ in  exp.fulfill() })
        }
    }
}

extension XCTestCase {

    func _testLog<P: MWPollable>(byPolling sut: @escaping (MetaWear) -> P, file: StaticString = #file, line: UInt = #line, expectFailure: String? = nil) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let _sut = sut(metawear)

            let pipline =
            metawear.publish()
                ._assertLoggers([], metawear: metawear, file, line)
                .log(byPolling: _sut)
                .share()
                .delay(for: 5, tolerance: 0, scheduler: metawear.bleQueue)
                ._assertLoggers([_sut.signalName], metawear: metawear, file, line)
            //                .share()
            //                .logsDownload()
            //
            //            // Assert
            //                .handleEvents(receiveOutput: { tables, percentComplete in
            //                    _printProgress(percentComplete)
            //                    if percentComplete < 1 { XCTAssertTrue(tables.isEmpty, file: file, line: line) }
            //                    guard percentComplete == 1.0 else { return }
            //                    XCTAssertEqual(tables.endIndex, 1, file: file, line: line)
            //                    XCTAssertEqual(Set(tables.map(\.source)), Set([_sut.loggerName]), file: file, line: line)
            //                    XCTAssertTrue(tables.allSatisfy({ $0.rows.isEmpty == false }), file: file, line: line)
            //                })
            //                .drop(while: { $0.percentComplete < 1 })
            //                ._assertLoggers([], metawear: metawear, file,  line)

            if let message = expectFailure {
                pipline._sinkExpectFailure(&subs, file, line, exp: exp, errorMessage: message)
            } else {
                pipline._sinkNoFailure(&subs, file, line, finished: { exp.fulfill() }, receiveValue: { _ in print(_sut.signalName); exp.fulfill() })
            }
        }
    }

    func _testLog<L: MWLoggable>(_ sut: L, file: StaticString = #file, line: UInt = #line, expectFailure: String? = nil) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let pipline =
            metawear.publish()
                ._assertLoggers([], metawear: metawear, file, line)
                .log(sut)
                ._assertLoggers([sut.signalName], metawear: metawear, file, line)
                .share()
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLog(sut)

            // Assert
                .handleEvents(receiveOutput: { data, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(data.isEmpty, file: file, line: line) }
                    guard percentComplete == 1.0 else { return }
                    XCTAssertGreaterThan(data.endIndex, 0, file: file, line: line)
                })
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear, file, line)

            if let message = expectFailure {
                pipline._sinkExpectFailure(&subs, file, line, exp: exp, errorMessage: message)
            } else {
                pipline._sinkNoFailure(&subs, file, line, finished: { exp.fulfill() }, receiveValue: { _ in print(sut.signalName); exp.fulfill() })
            }
        }
    }

    func _testLog2<L1: MWLoggable, L2: MWLoggable>(_ sut1: L1, _ sut2: L2, file: StaticString = #file, line: UInt = #line) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                ._assertLoggers([], metawear: metawear, file, line)
                .log(sut1)
                .log(sut2)
                ._assertLoggers([sut1.signalName, sut2.signalName], metawear: metawear, file, line)
                .share()
                .delay(for: 1, tolerance: 0, scheduler: metawear.bleQueue)
                .downloadLogs()

            // Assert
                .handleEvents(receiveOutput: { tables, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(tables.isEmpty, file: file, line: line) }
                    guard percentComplete == 1 else { return }
                    XCTAssertEqual(tables.endIndex, 2, file: file, line: line)
                    XCTAssertEqual(Set(tables.map(\.source)), Set([sut1.signalName, sut2.signalName]), file: file, line: line)
                    XCTAssertTrue(tables.allSatisfy({ $0.rows.isEmpty == false }), file: file, line: line)
                })
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear, file, line)
                ._sinkNoFailure(&subs, file, line, receiveValue: { _ in exp.fulfill() })
        }
    }
}