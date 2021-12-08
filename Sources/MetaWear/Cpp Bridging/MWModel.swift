// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

public extension MetaWear {

    enum Model: Equatable {
        case s
        case c
        case rl
        case notFound(String)

        public init(string: String) {
            if string.contains("MetaMotion S") {
                self = .s
            } else if string.contains("MetaMotion C") {
                self = .c
            } else if string.contains("MetaMotion RL") {
                self = .rl
            } else {
                self = .notFound(string)
            }
        }

        public var isolatedModelName: String {
            switch self {
                case .s: return "MetaMotion S"
                case .c: return "MetaMotion C"
                case .rl: return "MetaMotion RL"
                case .notFound(let string): return "\(string)"
            }
        }
    }
}
