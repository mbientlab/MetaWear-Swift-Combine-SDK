// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

class ReadTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useAnyNearbyDevice()
    }

    func test_Read_Temperature() throws {
        try _testRead { metawear in
            try [MWThermometer.Source.onboard, .bmp280, .onDie, .external]
                .map { try .thermometer(type: $0, board: metawear.board) }
        }
    }

    func test_Read_BatteryLevel() throws {
        _testRead { _ in .batteryLevel }
    }

    func test_Read_LastResetTime() throws {
        _testRead { _ in .lastResetTime }
    }

    func test_Read_LogLength() throws {
        _testRead { _ in .logLength }
    }

    func test_Read_Humidity() throws {
        _testRead { _ in .humidity() }
    }

    func test_Read_MACAddress() {
        _testRead { _ in .macAddress }
    }
}

extension XCTestCase {

    func _testRead<R: MWReadable>(_ makeSUT: @escaping (MetaWear) -> R ) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            let sut = makeSUT(metawear)
            metawear
                .publish()
                .read(sut)
                ._sinkNoFailure(&subs, receiveValue: { _, value in
                    if R.self == MWThermometer.self, let _sut = sut as? MWThermometer {
                        print("")
                        Swift.print(_sut.type.displayName)
                    }
                    Swift.print("Read", value)
                    exp.fulfill()
                })
        }
    }

    func _testRead<R: MWReadable>(makeSUTs: @escaping (MetaWear) throws -> [R] ) throws {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            var sub: AnyCancellable? = nil
            var suts = try makeSUTs(metawear)

            func test() {
                guard let sut = suts.popLast() else {
                    sub?.cancel()
                    exp.fulfill()
                    return
                }
                sub = metawear
                    .publish()
                    .read(sut)
                    .sink { completion in
                        guard case let .failure(error) = completion else { return }
                        XCTFail(error.localizedDescription)
                    } receiveValue: { _, value in

                        if R.self == MWThermometer.self, let _sut = sut as? MWThermometer {
                            Swift.print(_sut.type.displayName)
                        }

                        if R.DataType.self == Float.self {
                            Swift.print("Read", Int(value as! Float))
                        } else {
                            Swift.print("Read", value)
                        }

                        test()
                    }
            }
            test()
        }
    }
}
