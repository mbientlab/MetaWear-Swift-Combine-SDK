// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class MWDataTableTests: XCTestCase {

    func test_MWDataConvertible_CreatesCSVStrings_EpochOnly() {
        let exp = """
Epoch,X,Y,Z
1639715268.244,-0.0450,0.0048,1.0206
1639715268.245,-0.0455,0.0063,1.0309
1639715268.246,-0.0468,0.0046,1.0305
1639715268.247,-0.0440,0.0046,1.0290
1639715268.248,-0.0448,0.0065,1.0294
"""
        let date = Date(timeIntervalSince1970: 1639715268.2441)
        let streamableData: [(time: Date, value: MWAccelerometer.DataType)] = [
            (date.addingTimeInterval(0.000), SIMD3<Float>(-0.04498291, 0.004760742, 1.0205688)),
            (date.addingTimeInterval(0.001), SIMD3<Float>(-0.04547119, 0.0063476562, 1.0308838)),
            (date.addingTimeInterval(0.002), SIMD3<Float>(-0.04675293, 0.0045776367, 1.0304565)),
            (date.addingTimeInterval(0.003), SIMD3<Float>(-0.044006348, 0.0045776367, 1.0289917)),
            (date.addingTimeInterval(0.004), SIMD3<Float>(-0.044799805, 0.0065307617, 1.029419)),
        ]
        let sut = MWDataTable(streamed: streamableData,
                              .accelerometer(rate: .hz100, gravity: .g16),
                              startDate: date,
                              dateColumns: []
        )
        let result = sut.makeCSV()

        XCTAssertEqual(exp.count, result.count)
        XCTAssertEqual(exp, result)
    }

    func test_MWDataConvertible_CreatesCSVStrings_EpochElapsed() {
        let exp = """
Epoch,Elapsed (s),X,Y,Z
1639715268.244,0.000,-0.0450,0.0048,1.0206
1639715268.245,0.001,-0.0455,0.0063,1.0309
1639715268.246,0.002,-0.0468,0.0046,1.0305
1639715268.247,0.003,-0.0440,0.0046,1.0290
1639715268.248,0.004,-0.0448,0.0065,1.0294
"""
        let date = Date(timeIntervalSince1970: 1639715268.2441)
        let streamableData: [(time: Date, value: MWAccelerometer.DataType)] = [
            (date.addingTimeInterval(0.000), SIMD3<Float>(-0.04498291, 0.004760742, 1.0205688)),
            (date.addingTimeInterval(0.001), SIMD3<Float>(-0.04547119, 0.0063476562, 1.0308838)),
            (date.addingTimeInterval(0.002), SIMD3<Float>(-0.04675293, 0.0045776367, 1.0304565)),
            (date.addingTimeInterval(0.003), SIMD3<Float>(-0.044006348, 0.0045776367, 1.0289917)),
            (date.addingTimeInterval(0.004), SIMD3<Float>(-0.044799805, 0.0065307617, 1.029419)),
        ]
        let sut = MWDataTable(streamed: streamableData,
                              .accelerometer(rate: .hz100, gravity: .g16),
                              startDate: date,
                              dateColumns: [.elapsed]
        )
        let result = sut.makeCSV()

        XCTAssertEqual(exp.count, result.count)
        XCTAssertEqual(exp, result)
    }

    func test_MWDataConvertible_CreatesCSVStrings_EpochTimestampElapsed() {
        let exp = """
Epoch,Timestamp (-0800),Elapsed (s),X,Y,Z
1639715268.244,2021-12-16T20.27.48.244,0.000,-0.0450,0.0048,1.0206
1639715268.245,2021-12-16T20.27.48.245,0.001,-0.0455,0.0063,1.0309
1639715268.246,2021-12-16T20.27.48.246,0.002,-0.0468,0.0046,1.0305
1639715268.247,2021-12-16T20.27.48.247,0.003,-0.0440,0.0046,1.0290
1639715268.248,2021-12-16T20.27.48.248,0.004,-0.0448,0.0065,1.0294
"""
        let date = Date(timeIntervalSince1970: 1639715268.2441)
        let streamableData: [(time: Date, value: MWAccelerometer.DataType)] = [
            (date.addingTimeInterval(0.000), SIMD3<Float>(-0.04498291, 0.004760742, 1.0205688)),
            (date.addingTimeInterval(0.001), SIMD3<Float>(-0.04547119, 0.0063476562, 1.0308838)),
            (date.addingTimeInterval(0.002), SIMD3<Float>(-0.04675293, 0.0045776367, 1.0304565)),
            (date.addingTimeInterval(0.003), SIMD3<Float>(-0.044006348, 0.0045776367, 1.0289917)),
            (date.addingTimeInterval(0.004), SIMD3<Float>(-0.044799805, 0.0065307617, 1.029419)),
        ]
        let sut = MWDataTable(streamed: streamableData,
                              .accelerometer(rate: .hz100, gravity: .g16),
                              startDate: date,
                              dateColumns: MWDataTable.ExtraDateColumns.allCases
        )
        let result = sut.makeCSV()

        XCTAssertEqual(exp.count, result.count)
        XCTAssertEqual(exp, result)
    }
}
