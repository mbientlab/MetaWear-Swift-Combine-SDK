// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class NameTests: XCTestCase {

    func test_IsNameValid_AcceptsValidNames() {
        let cases = [
            "Antidisestablishmentarian",
            "MetaWear",
            "MetaWear ",
            " MetaWear",
            "_",
            "-"
        ]

        let sut = MetaWear.isNameValid

        cases.forEach { print(sut($0)); XCTAssertTrue(sut($0), $0) }
    }

    func test_IsNameValid_RejectsInvalidNames() {
        let cases = [
            "Pneumonoultramicroscopicsilicovolcanoconiosis",
            "MetaWear $",
            "MetaWear ~",
            "MetaWear —",
            "* MetaWear ",
            "MetaWear ∀",
            "😂",
            ""
        ]

        let sut = MetaWear.isNameValid

        cases.forEach { XCTAssertFalse(sut($0), $0) }
    }

}
