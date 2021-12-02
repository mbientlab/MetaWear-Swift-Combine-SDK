// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

public extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
