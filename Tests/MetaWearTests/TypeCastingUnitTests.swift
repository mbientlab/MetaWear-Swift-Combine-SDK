// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear

class TypeCastingTests: XCTestCase {

    func testParse_ByteArray() {
        let exp: [UInt8] = [0, 1, 2, 3]
        let data = Data(exp)
        let sut = MWData(timestamp: Date(), data: data, typeId: MblMwDataTypeId.MBL_MW_DT_ID_BYTE_ARRAY)
        let result = sut.valueAs() as [UInt8]
        XCTAssertEqual(result, exp)
    }
}
