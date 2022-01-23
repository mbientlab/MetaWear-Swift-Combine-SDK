import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class ExampleTests: XCTestCase {

    func test_DiscoversDeviceInfo() {
        TestDevices.useOnly(.metamotionS)

        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            let sut = metawear.info
            XCTAssertEqual(sut.model, .motionS)
            ...
            exp.fulfill()
        }
    }

    func test_Read_LogLength_WhenPopulated() {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            // Prepare
            let log: some MWLoggable = .accelerometer(rate: .hz50, gravity: .g2)
            metawear.publish()
                .deleteLoggedEntries()
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
                .deleteLoggedEntries()
                ._sinkNoFailure(&subs, receiveValue: { _ in  exp.fulfill() })
        }
    }
}
