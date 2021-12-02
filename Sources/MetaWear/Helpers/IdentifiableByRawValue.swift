// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

public protocol IdentifiableByRawValue: RawRepresentable, Identifiable {
    var id: RawValue { get }
}

public extension IdentifiableByRawValue {
     var id: RawValue { rawValue }
}
