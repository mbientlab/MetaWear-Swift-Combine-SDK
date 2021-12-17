// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

// MARK: - Assert Async

extension Publisher {

    func _assertNoFailure(_ file: StaticString = #file,
                          _ line: UInt = #line,
                          finished: @escaping () -> Void = { },
                          receiveValue: @escaping ((Self.Output) -> Void) = { _ in }
    ) -> AnyPublisher<Output,Failure> {

        handleEvents(receiveOutput: receiveValue, receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTFail(error.localizedDescription, file: file, line: line)
                case .finished: break
            }
            finished()
        })
            .eraseToAnyPublisher()
    }

    func _sinkNoFailure(_ subs: inout Set<AnyCancellable>,
                        _ file: StaticString = #file,
                        _ line: UInt = #line,
                        finished: @escaping () -> Void = { },
                        receiveValue: @escaping (Self.Output) -> Void = { _ in }
    ) {

        sink(receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTFail(error.localizedDescription, file: file, line: line)
                case .finished: break
            }
            finished()
        }, receiveValue: receiveValue)
            .store(in: &subs)
    }

    func _sinkExpectFailure(_ subs: inout Set<AnyCancellable>,
                            _ file: StaticString = #file,
                            _ line: UInt = #line,
                            exp: XCTestExpectation,
                            errorMessage: String
    ) {

        sink(receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTAssertEqual(error.localizedDescription, errorMessage, file: file, line: line)
                    exp.fulfill()

                case .finished:
                    XCTFail("Expected to fail", file: file, line: line)
            }
        }, receiveValue: { _ in XCTFail("Expected to fail", file: file, line: line) })
            .store(in: &subs)
    }
}

// MARK: - Loggers

extension Publisher {

    func _assertLoggers(_ loggers: [MWNamedSignal],
                        metawear: MetaWear,
                        _ file: StaticString = #file,
                        _ line: UInt = #line
    ) -> AnyPublisher<Output,MWError> {

        mapToMWError()
            .flatMap { output -> AnyPublisher<Output,MWError> in
                metawear.publish()
                    .collectAnonymousLoggerSignals()
                    .map { result -> Output in
                        Swift.print("Loggers found: ", result.map(\.id.name))
                        XCTAssertEqual(loggers.count, result.count, file: file, line: line)
                        XCTAssertEqual(Set(loggers), Set(result.map(\.id)), file: file, line: line)
                        return output
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
