// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

public extension Publisher where Output: FloatingPoint {

    func removeDuplicates(within percentage: Output) -> AnyPublisher<Output,Failure> {
        removeDuplicates(by: { first, second in
            let diff = first * percentage
            let range = (first - diff)...(first + diff)
            return  range.contains(second)
        })
            .eraseToAnyPublisher()
    }
}

public extension Publisher where Output == Int {

    func removeDuplicates(within value: Output) -> AnyPublisher<Output,Failure> {
        removeDuplicates(by: { first, second in
            let range = (first - value)...(first + value)
            return  range.contains(second)
        })
            .eraseToAnyPublisher()
    }
}

public extension Publisher where Output == MetaWear {

    /// Ensurers block is executed and subscribed on the proper queue.
    ///
    func handleOutputOnBleQueue(_ block: @escaping (MetaWear) -> Void) -> MWPublisher<MetaWear> {
        mapToMWError()
            .flatMap { metawear in
                _JustMW(metawear)
                    .handleEvents(receiveOutput: { metaWear in
                        block(metawear)
                    })
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }
}
