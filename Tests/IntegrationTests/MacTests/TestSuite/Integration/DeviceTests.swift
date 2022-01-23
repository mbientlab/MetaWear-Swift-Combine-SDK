// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class DeviceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Targets vary. Defined in test method.
    }

    // MARK: - Info Tests

    func test_DiscoversName() {
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            XCTAssertFalse(metawear.name.isEmpty)
            XCTAssertTrue(MetaWear.isNameValid(metawear.name))
            exp.fulfill()
        }
    }

    func test_DiscoversDeviceInfo() {
        TestDevices.useOnly(.metamotionS)

        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            let sut = metawear.info
            XCTAssertEqual(sut.model, .motionS)
            XCTAssertEqual(sut.hardwareRevision, "0.1")
            XCTAssertEqual(sut.mac, "E2:ED:DF:1A:1A:A4")
            XCTAssertEqual(sut.manufacturer, "MbientLab Inc")
            XCTAssertEqual(sut.serialNumber, "055DF0")
            XCTAssertTrue(sut.firmwareRevision.isMetaWearVersion(greaterThanOrEqualTo: "1.5.0"), sut.firmwareRevision)
            exp.fulfill()
        }
    }

    func test_ReportsCBPeripheralUUID() {
        TestDevices.useOnly(.metamotionS)

        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            XCTAssertEqual(metawear.localBluetoothID.uuidString, TestDevices.current?.getTestTargetLocalUUID())
            exp.fulfill()
        }
    }

    // MARK: - Describe Capabilities

    func test_DescribeCapabilities_MetamotionS() {
        TestDevices.useOnly(.metamotionS)

        let modulesExp: [MWModules.ID:MWModules] = [
            .accelerometer : .accelerometer(.bmi270),
            .barometer : .barometer(.bmp280),
            .gyroscope : .gyroscope(.bmi270),
            .illuminance : .illuminance,
            .magnetometer : .magnetometer,
            .thermometer : .thermometer([.onDie, .onboard, .external, .bmp280]),
            .sensorFusion : .sensorFusion,
            .mechanicalSwitch : .mechanicalSwitch,
            .led : .led,
            .gpio : .gpio,
            .haptic : .haptic,
            .iBeacon : .iBeacon,
            .i2c : .i2c
        ]

        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear
                .describeModules()
                ._sinkNoFailure(&subs, receiveValue: { modules in
                    MWModules.ID.allCases.forEach {
                        XCTAssertEqual(modulesExp[$0], modules[$0], String(describing: $0))
                    }
                    exp.fulfill()
                })
        }
    }

    func test_DescribeCapabilities_MetaMotionRL() {
        TestDevices.useOnly(.metamotionRL)

        let modulesExp: [MWModules.ID:MWModules] = [
            .accelerometer : .accelerometer(.bmi160),
            .gyroscope : .gyroscope(.bmi160),
            .magnetometer : .magnetometer,
            .thermometer : .thermometer([.onDie, .onboard, .external, .bmp280]),
            .sensorFusion : .sensorFusion,
            .mechanicalSwitch : .mechanicalSwitch,
            .led : .led,
            .gpio : .gpio,
            .haptic : .haptic,
            .iBeacon : .iBeacon,
            .i2c : .i2c
        ]

        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear
                .describeModules()
                ._sinkNoFailure(&subs, receiveValue: { modules in
                    MWModules.ID.allCases.forEach {
                        XCTAssertEqual(modulesExp[$0], modules[$0], String(describing: $0))
                    }
                    exp.fulfill()
                })
        }
    }


    // MARK: - RSSI Updates

    func test_RSSI_DoesUpdateWhileScannerStopped() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear
                .rssiPublisher
                .mapToMWError()
                .collect(3)
                ._sinkNoFailure(&subs, receiveValue: { values in
                    values.forEach { XCTAssertNotEqual(-100, $0) }
                    XCTAssertFalse(Host.scanner.isScanning)
                    exp.fulfill()
                })
        }
    }

    func test_RSSI_DoesUpdateWhileScannerOn() {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            metawear
                .rssiPublisher
                .mapToMWError()
                .collect(3)
                ._sinkNoFailure(&subs, receiveValue: { values in
                    values.forEach { XCTAssertNotEqual(-100, $0) }
                    XCTAssertTrue(Host.scanner.isScanning)
                    exp.fulfill()
                })

            Host.scanner.startScan(higherPerformanceMode: true)
        }
    }


    // MARK: - Reset

    func test_FactoryReset() {
        TestDevices.useAnyNearbyDevice()
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            var lastReset = Date()

            // Arrange
            metawear.publish()
                .read(.lastResetTime)
                .handleEvents(receiveOutput: { output in
                    lastReset = output.value.time
                })
                .map { _ in metawear }

            // Act
                .command(.resetFactoryDefaults)
                ._sinkNoFailure(&subs)

            // Assert
            metawear
                .publishWhenDisconnected()
                .first()
                .delay(for: 3, tolerance: 0, scheduler: metawear.bleQueue)
                .flatMap { $0.connectPublisher() }
                ._assertLoggers([], metawear: metawear)
                .read(.lastResetTime)
                ._sinkNoFailure(&subs, finished: { }) { _, reset in
                    let elapsed = lastReset.distance(to: reset.time) / 1000
                    XCTAssertGreaterThan(elapsed, 0)
                    XCTAssertLessThan(elapsed, .download)
                    exp.fulfill()
                }
        }
    }
}
