// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class StreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.metamotionRL)
    }

    func testStream_Accelerometer() {
        _testStream(.accelerometer(rate: .hz50, gravity: .g2))
    }

    func testStream_AmbientLight() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.ambientLight(rate: .ms500, gain: .x1, integrationTime: .ms100))
    }

    func testStream_BarometerAbsolute()  {
        TestDevices.useOnly(.metamotionS)
        _testStream(.absoluteAltitude(standby: .ms125, iir: .avg2, oversampling: .standard))
    }

    func testStream_BarometerRelative() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.relativePressure(standby: .ms125, iir: .avg2, oversampling: .standard))
    }

    /// Remember to manually plug and unplug the device
    func test_Stream_ChargingStatus() throws {
        TestDevices.useOnly(.metamotionS)
        _testStream(.chargingStatus)
    }

    func testStream_Gyroscope() {
        _testStream(.gyroscope(range: .dps125, freq: .hz50))
    }

    func testStream_Magnetometer() {
        _testStream(.magnetometer(freq: .hz15))
    }

    /// Remember to manually tap the button
    func testStream_MechanicalButton() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.mechanicalButton)
    }

    /// Remember to move the device
    func testStream_Motion_ActivityClassification() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.motionActivityClassification, timeout: .download)
    }

    /// Remember to move the device
    func testStream_Motion_Any() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.motionAny)
    }

    /// Remember to move the device
    func testStream_Motion_Significant() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.motionSignificant, timeout: .download)
    }

    /// Remember to NOT move the device
    func testStream_Motion_None() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.motionNone)
    }


    /// Remember to manually move the device to trigger streaming updates.
    func testStream_Orientation_OnSupportedDevice() {
        TestDevices.useOnly(.metamotionRL)
        _testStream(.orientation, timeout: .download)
    }

    func testStream_Orientation_FailsOnNonBMI160() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .read, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                .stream(.orientation)
                .sink { completion in
                    switch completion {
                        case .failure(let error):
                            XCTAssertEqual(error.localizedDescription, "Operation failed: Orientation requires a BMI160 module, which this device lacks.")
                            exp.fulfill()
                        case .finished: XCTFail("Should have failed.")
                    }
                } receiveValue: { _ in
                    XCTFail("No data should be received.")
                }
                .store(in: &subs)
        }
    }

    // Where steps are "counted" by closure received, rather than by value
    func testStream_StepDetection_BMI270() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.stepDetector()) { value in
            XCTAssertEqual(value, 1)
        }
    }

    // Where steps are "counted" by closure received, rather than by value
    func testStream_StepDetection_BMI160() {
        TestDevices.useOnly(.metamotionRL)
        _testStream(.stepDetector(sensitivity: .sensitive)) { value in
            XCTAssertEqual(value, 1)
        }
    }

    // Where steps are reported in chunks of 20
    func testStream_StepCounting_BMI270() {
        TestDevices.useOnly(.metamotionS)
        _testStream(.stepCounter(), timeout: .download, dataCountTarget: 1) { value in
            XCTAssertEqual(value, 20)
        }
    }

    // Where steps are reported in chunks of 20
    #warning("Failing -> no response received")
    func testStream_StepCounting_BMI160() {
        TestDevices.useOnly(.metamotionRL)
        _testStream(.stepCounter(sensitivity: .sensitive), timeout: .download, dataCountTarget: 1) { value in
            XCTAssertEqual(value, 20)
        }
    }

    // MARK: - Pollables

    func testStreamPoll_Temperature() throws {
        try _testPoll { metawear in
            try [MWThermometer.Source.onboard, .bmp280, .onDie, .external]
                .map { try .thermometer(type: $0, board: metawear.board, rate: .init(hz: 2)) }
        }
    }

    func testStreamPoll_Humidity() throws {
        try _testPoll { _ in
            [.humidity(oversampling: .x1, rate: .init(periodMs: 1))]
        }
    }

    // MARK: - Sensor Fusion All Modes

    func testStream_SensorFusion_EulerAngles() {
        _testStreamFusion(sut: { .sensorFusionEulerAngles(mode: $0) })
    }

    func testStream_SensorFusion_Gravity() {
        _testStreamFusion(sut: { .sensorFusionGravity(mode: $0) })
    }

    func testStream_SensorFusion_Quaternion() {
        _testStreamFusion(sut: { .sensorFusionQuaternion(mode: $0) })
    }

    func testStream_SensorFusion_LinearAcceleration() {
        _testStreamFusion(sut: { .sensorFusionLinearAcceleration(mode: $0) })
    }
}

// MARK: - Helpers

extension XCTestCase {

    func _testPoll<P: MWPollable>(makeSUTs: @escaping (MetaWear) throws -> [P] ) throws {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            var dataCount = 0
            var sub: AnyCancellable? = nil
            var suts = try makeSUTs(metawear)
            let sutCount = suts.count

            func test() {
                dataCount = 0
                if suts.endIndex != 0 { print(""); print("Starting #", sutCount - suts.count + 1) }
                guard let sut = suts.popLast() else {
                    sub?.cancel()
                    exp.fulfill()
                    return
                }
                sub = metawear
                    .publish()
                    .stream(sut)
                    .sink { completion in
                        guard case let .failure(error) = completion else { return }
                        XCTFail(error.localizedDescription)
                    } receiveValue: { _, value in
                        dataCount += 1
                        Swift.print("Polled", dataCount, value)

                        if dataCount == 5 {
                            sub?.cancel()
                            test()
                        }
                    }

            }
            test()
        }
    }

    func _testStream<S: MWStreamable>(_ sut: S,
                                      timeout: TimeInterval = .read,
                                      dataCountTarget: Int = 5,
                                      valueAssertion: ((S.DataType) -> Void)? = nil) {

        connectNearbyMetaWear(timeout: timeout, useLogger: false) { metawear, exp, subs in
            var dataCount = 0
            var sub: AnyCancellable? = nil

            sub = metawear
                .publish()
                .stream(sut)
                .sink { completion in
                    guard case let .failure(error) = completion else { return }
                    XCTFail(error.localizedDescription)
                } receiveValue: { _, value in
                    dataCount += 1
                    Swift.print("Streamed", dataCount, value)
                    valueAssertion?(value)

                    if dataCount == dataCountTarget {
                        sub?.cancel()
                        exp.fulfill()
                    }
                }
        }
    }

    func _testStreamFusion<S: MWStreamable>(sut: @escaping (MWSensorFusion.Mode) -> S) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            var modes = MWSensorFusion.Mode.allCases
            var dataCount = 0
            var sub: AnyCancellable? = nil

            func test() {
                dataCount = 0
                guard let mode = modes.popLast() else {
                    exp.fulfill()
                    return
                }
                sub = metawear
                    .publish()
                    .stream(sut(mode))
                    .sink { completion in
                        guard case let .failure(error) = completion else { return }
                        XCTFail(error.localizedDescription)
                    } receiveValue: { _, value in
                        dataCount += 1
                        Swift.print("Streamed", dataCount, value)

                        if dataCount == 5 {
                            sub?.cancel()
                            test()
                        }
                    }
            }

            test()
        }
    }
}
