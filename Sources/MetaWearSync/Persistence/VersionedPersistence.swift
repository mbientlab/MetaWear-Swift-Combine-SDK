// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

/// Object that implements some persistence strategy with legacy support
///
open class MWLoader<Loadable: VersionedContainerLoadable> {
    public let loaded: AnyPublisher<Loadable, Never>
    public func load() throws { }
    public func save(_ loadable: Loadable) throws { }
    public init(loaded: AnyPublisher<Loadable, Never>) { self.loaded = loaded }
}


/// Generates `Data` for a given type, wrapped in a versioning container so future releases can parse legacy saved data
///
public protocol MWVersioningContainer {
    associatedtype Loadable
    init(data: Data, decoder: JSONDecoder) throws
    static func encode(_ loadable: Loadable, _ encoder: JSONEncoder) throws -> Data
    func load(_ decoder: JSONDecoder) throws -> Loadable
}


/// Links a given type to a versioned persistence container
///
public protocol VersionedContainerLoadable {
    associatedtype Container: MWVersioningContainer where Container.Loadable == Self
}
