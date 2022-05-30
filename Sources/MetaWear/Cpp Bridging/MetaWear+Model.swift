// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

public extension MetaWear {

    /// Marketed model name for this MetaWear.
    ///
    /// - Warning: Do not depend on `Codable` conformance for persistence.
    ///            Use for in-memory drag and drop only.
    ///
    enum Model: Int, Equatable, CaseIterable, IdentifiableByRawValue, Codable {
        case unknown = -1
        case wearR, wearRG, wearRPRO, wearC, wearCPRO, environment, detector, health, tracker, motionR, motionRL, motionC, motionS

        public init(modelNumber: MblMwModel) {
            let value = modelNumber.rawValue
            self = Self.allCases.first(where: {
                $0.rawValue == value
            }) ?? .unknown
        }

        public init(modelName: String) {
            self = Self.allCases.first(where: {
                $0.name == modelName
            }) ?? .unknown
        }

        public var name: String {
            switch self {
                case .unknown: return "Unknown"
                case .wearR: return "MetaWear R"
                case .wearRG: return "MetaWear RG"
                case .wearRPRO: return "MetaWear RPro"
                case .wearC: return "MetaWear C"
                case .wearCPRO: return "MetaWear CPro"
                case .environment: return "MetaEnvironment"
                case .detector: return "MetaDetector"
                case .health: return "MetaHealth"
                case .tracker: return "MetaTracker"
                case .motionR: return "MetaMotion R"
                case .motionRL: return "MetaMotion RL"
                case .motionC: return "MetaMotion C"
                case .motionS: return "MetaMotion S"
            }
        }

      /// Internally determined model ID for hardware
      public var modelID: Int {
        switch self {
        case .wearR: return 0
        case .wearRG, .wearRPRO: return 1
        case .wearC, .wearCPRO, .environment, .detector: return 2
        case .health: return 3
        case .tracker: return 4
        case .motionR, .motionRL: return 5
        case .motionC: return 6
        case .motionS: return 8
        default: return 7
        }
      }
    }
}
