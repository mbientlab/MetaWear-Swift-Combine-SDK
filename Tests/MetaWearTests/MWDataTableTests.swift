// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class MWDataTableTests: XCTestCase {

    func test_MWDataConvertible_CreatesCSVStrings() {
        let exp = """
Epoch,X,Y,Z
1639715268.2441,-0.0450,0.0048,1.0206
1639715268.2441,-0.0455,0.0063,1.0309
1639715268.2441,-0.0468,0.0046,1.0305
1639715268.2441,-0.0440,0.0046,1.0290
1639715268.2441,-0.0448,0.0065,1.0294
"""
        let date = Date(timeIntervalSince1970: 1639715268.2441)
        let streamableData: [(time: Date, value: MWAccelerometer.DataType)] = [
            (date, SIMD3<Float>(-0.04498291, 0.004760742, 1.0205688)),
            (date, SIMD3<Float>(-0.04547119, 0.0063476562, 1.0308838)),
            (date, SIMD3<Float>(-0.04675293, 0.0045776367, 1.0304565)),
            (date, SIMD3<Float>(-0.044006348, 0.0045776367, 1.0289917)),
            (date, SIMD3<Float>(-0.044799805, 0.0065307617, 1.029419)),
        ]
        let sut = MWDataTable(streamed: streamableData,
                              .accelerometer(rate: .hz100, gravity: .g16),
                              startDate: date
        )
        let result = sut.makeCSV()

        XCTAssertEqual(exp.count, result.count)
        XCTAssertEqual(exp, result)
    }
}
