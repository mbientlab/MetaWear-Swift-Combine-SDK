// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation
import Combine

// MARK: - Public - General Operators

public extension Publisher {

    /// Sugar to ensure operations upstream of this are performed async on the provided queue.
    ///
    func erase(subscribeOn queue: DispatchQueue) -> AnyPublisher<Self.Output,Self.Failure> {
        self
            .subscribe(on: queue)
            .receive(on: queue)
            .eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == MWError {

    /// Sugar to erase a MetaWearError publisher to an Error publisher
    ///
    func eraseErrorType() -> AnyPublisher<Output,Error> {
        mapError({ $0 as Error }).eraseToAnyPublisher()
    }

}
