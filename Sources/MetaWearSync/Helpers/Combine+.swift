// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

internal extension Publisher {

    /// Erase and share a publisher on the main queue.
    func shareOnMain() -> AnyPublisher<Output,Failure> {
        receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}
