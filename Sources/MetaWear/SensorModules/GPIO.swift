// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct _MWGPIO {}


// MARK: - C++ Constants

public extension _MWGPIO {
    
    enum PullMode: Int, CaseIterable, IdentifiableByRawValue {
        case up
        case down
        case pullNone
        
        public var cppEnumValue: MblMwGpioPullMode {
            switch self {
                case .up: return MBL_MW_GPIO_PULL_MODE_UP
                case .down: return MBL_MW_GPIO_PULL_MODE_DOWN
                case .pullNone: return MBL_MW_GPIO_PULL_MODE_NONE
            }
        }
    }
    
    enum ChangeType: String, CaseIterable, IdentifiableByRawValue {
        case rising
        case falling
        case any
        
        public var cppEnumValue: MblMwGpioPinChangeType {
            switch self {
                case .rising:   return MBL_MW_GPIO_PIN_CHANGE_TYPE_RISING
                case .falling:  return MBL_MW_GPIO_PIN_CHANGE_TYPE_FALLING
                case .any:      return MBL_MW_GPIO_PIN_CHANGE_TYPE_ANY
            }
        }
        
        public init(previous: PullMode, next: PullMode) {
            switch previous {
                case .up:
                    switch next {
                        case .pullNone: self = .any
                        case .up: self = .any
                        case .down: self = .falling
                    }
                    
                case .down:
                    switch next {
                        case .pullNone: self = .any
                        case .up: self = .rising
                        case .down: self = .any
                    }
                    
                case .pullNone:
                    switch next {
                        case .pullNone: self = .any
                        case .up: self = .rising
                        case .down: self = .falling
                    }
            }
        }
    }
    
    enum Mode: Int, CaseIterable, IdentifiableByRawValue {
        case digital
        case analog
    }
    
    enum Pin: Int, CaseIterable, IdentifiableByRawValue {
        case zero
        case one
        case two
        case three
        case four
        case five
        
        public var pinValue: UInt8 { UInt8(rawValue) }
    }
    
}
