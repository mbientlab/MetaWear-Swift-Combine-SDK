// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

/// Not true tests, just quickly reset w/o assertions to escape bad state.
///
final class QuickResetUtilityTests: XCTestCase {

    func test_FactoryReset_RL() {
        TestDevices.useOnly(.metamotionRL)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear
                .publish()
                .command(.resetFactoryDefaults)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
            exp.fulfill()
        }
    }

    func test_FactoryReset_S() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear
                .publish()
                .command(.resetFactoryDefaults)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
            exp.fulfill()
        }
    }
}


final class ResetActivitiesTests: XCTestCase {

    func test_ResetActivities_RL() {
        TestDevices.useOnly(.metamotionRL)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear
                .publish()
                .command(.resetActivities)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_ResetActivities_S() {
        TestDevices.useOnly(.metamotionS)
        connectNearbyMetaWear(timeout: .read) { metawear, exp, subs in
            metawear
                .publish()
                .command(.resetActivities)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }
}
