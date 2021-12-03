// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class StreamBMI160Tests: XCTestCase {

    func testStream_Steps() {
        _testStream(.steps(sensitivity: .sensitive))
    }

    /// Remember to manually move the device to trigger streaming updates.
    func testStream_Orientation_OnSupportedDevice() {
        TestDevices.useOnly(.RL_BE)
        _testStream(.orientation, timeout: .download)
    }

    func testStream_Orientation_FailsOnNonBMI160() {
        TestDevices.useOnly(.S_A4)
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
}
