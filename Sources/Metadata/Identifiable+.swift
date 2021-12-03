// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

extension Array where Element: Identifiable {
    /// Creates a dictionary, with identifier collisions prioritizing the latter-most element.
    func dictionary() -> Dictionary<Element.ID,Element> {
        reduce(into: Dictionary<Element.ID,Element>()) { $0[$1.id] = $1 }
    }
}

extension Publisher {

    func mapValues<T:Identifiable>() -> AnyPublisher<[T],Failure> where Output == Dictionary<T.ID,T> {
        map { Array($0.values) }.eraseToAnyPublisher()
    }
}

extension Collection where Element: Identifiable {
    var ids: Set<Element.ID> { self.reduce(into: Set<Element.ID>()) { $0.insert($1.id) }}
}
