// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

/// Sugar for Just with an Error output.
func _Just<O>(_ output: O) -> AnyPublisher<O,Error> {
    Just(output).setFailureType(to: Error.self).eraseToAnyPublisher()
}

func _JustMW<O>(_ output: O) -> AnyPublisher<O,MWError> {
    Just(output).setFailureType(to: MWError.self).eraseToAnyPublisher()
}

/// Sugar for Just with a MetaWear output.
func _JustMW(_ bool: Bool) -> AnyPublisher<Bool,MWError> {
    Just(bool).setFailureType(to: MWError.self).eraseToAnyPublisher()
}

func _Fail<Output>(_ error: MWError) -> AnyPublisher<Output,Error> {
    Fail(outputType: Output.self, failure: error)
        .eraseToAnyPublisher()
}

func _Fail<Output>(mw: MWError) -> AnyPublisher<Output, MWError> {
    Fail(outputType: Output.self, failure: mw)
        .eraseToAnyPublisher()
}

func _Fail<Output>(mapping: Error) -> AnyPublisher<Output, MWError> {
    if let mw = mapping as? MWError {
        return Fail(outputType: Output.self, failure: mw)
            .eraseToAnyPublisher()
    } else {
        return Fail(outputType: Output.self,
                    failure: MWError.operationFailed(mapping.localizedDescription))
            .eraseToAnyPublisher()
    }
}

public extension Publisher {

    /// Wraps any preceding error into a `MetaWearError`.
    func mapToMWError() -> AnyPublisher<Output,MWError> {
        mapError { error -> MWError in
            if let mwe = error as? MWError {
                return mwe
            } else {
                return MWError.operationFailed(error.localizedDescription)
            }
        }
        .eraseToAnyPublisher()
    }

    internal func replaceMWError(_ replacement: MWError) -> AnyPublisher<Output,MWError> {
        mapError { _ -> MWError in replacement }
        .eraseToAnyPublisher()
    }
}
